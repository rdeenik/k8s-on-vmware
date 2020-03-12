# Inspired by https://sdorsett.github.io/post/2018-12-26-using-local-exec-and-remote-exec-provisioners-with-terraform/
# To Do:
# - Check if local SSH keypair exists, otherwise create one
# - Install kubectl
# - Copy config from master node (.kube/config)
# - set fixed IP addresses (at least for iSCSI)
# - Testing...
#
#
#
#

# Generate a public/private key for passwordless authentication
resource "null_resource" "generate-sshkey" {
    provisioner "local-exec" {
        command = "mkdir -p keys"
    }
    provisioner "local-exec" {
        # TODO: only run if keys do not exist
        command = "yes y | ssh-keygen -b 4096 -t rsa -C 'k8s-on-vmware-sshkey' -N '' -f ${var.k8s-global.private_key}"
    }
}

data "local_file" "ssh-privatekey" {
  filename            = "${var.k8s-global.private_key}"

  depends_on = [
    null_resource.generate-sshkey,
  ]
}

data "local_file" "ssh-publickey" {
  filename            = "${var.k8s-global.public_key}"

  depends_on = [
    null_resource.generate-sshkey,
  ]
}

# Connection to vSphere environment
provider "vsphere" {
  user                  = var.vsphere_config.user
  password              = var.vsphere_config.password
  vsphere_server        = var.vsphere_config.vcenter_server
  allow_unverified_ssl  = true
}

data "vsphere_datacenter" "dc" {
  name                  = var.vsphere_config.datacenter
}

data "vsphere_datastore" "datastore" {
  name                  = var.vsphere_config.datastore
  datacenter_id         = data.vsphere_datacenter.dc.id
}

data "vsphere_compute_cluster" "cluster" {
  name                  = var.vsphere_config.cluster
  datacenter_id         = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "vm_network" {
  name                  = var.vsphere_config.vm_network
  datacenter_id         = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "iscsi_network" {
  name                  = var.vsphere_config.iscsi_network
  datacenter_id         = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name                  = var.k8s-adminhost.template
  datacenter_id         = data.vsphere_datacenter.dc.id
}

# Creating the administrative node on vSphere, which is used to manage the K8S cluster
resource "vsphere_virtual_machine" "k8s-adminhost" {
  name                  = var.k8s-adminhost.hostname
  resource_pool_id      = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id          = data.vsphere_datastore.datastore.id

  num_cpus              = var.k8s-adminhost.num_cpus
  memory                = var.k8s-adminhost.memory
  guest_id              = data.vsphere_virtual_machine.template.guest_id
  
  scsi_type             = data.vsphere_virtual_machine.template.scsi_type

  network_interface {
    network_id          = data.vsphere_network.vm_network.id
    adapter_type        = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label               = "disk0"
    size                = data.vsphere_virtual_machine.template.disks.0.size
    eagerly_scrub       = data.vsphere_virtual_machine.template.disks.0.eagerly_scrub
    thin_provisioned    = data.vsphere_virtual_machine.template.disks.0.thin_provisioned
  }

  cdrom {
    client_device       = true
  }
  
  vapp {
    properties = {
      hostname          = var.k8s-adminhost.hostname
      user-data         = base64encode(templatefile("templates/adminhost-cloud-init.yml", { username = var.k8s-global.username, public-key = data.local_file.ssh-publickey.content }))
    }
  }

  clone {
    template_uuid       = data.vsphere_virtual_machine.template.id
  }

  wait_for_guest_net_timeout = 10

  depends_on = [
    data.local_file.ssh-publickey,
    data.local_file.ssh-privatekey,
  ]
}

# Creating the K8S worker nodes on vSphere, for the actual K8S cluster
resource "vsphere_virtual_machine" "k8s-nodes" {
  count                 = var.k8s-nodes.number_of_nodes
  name                  = "${var.k8s-nodes.hostname}${count.index + 1}"
  resource_pool_id      = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id          = data.vsphere_datastore.datastore.id

  num_cpus              = var.k8s-nodes.num_cpus
  memory                = var.k8s-nodes.memory
  guest_id              = data.vsphere_virtual_machine.template.guest_id

  scsi_type             = data.vsphere_virtual_machine.template.scsi_type

  network_interface {
    network_id          = data.vsphere_network.vm_network.id
    adapter_type        = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  network_interface {
    network_id          = data.vsphere_network.iscsi_network.id
  }

  disk {
    label               = "disk0"
    size                = data.vsphere_virtual_machine.template.disks.0.size
    eagerly_scrub       = data.vsphere_virtual_machine.template.disks.0.eagerly_scrub
    thin_provisioned    = data.vsphere_virtual_machine.template.disks.0.thin_provisioned
  }

  cdrom {
    client_device       = true
  }

  vapp {
    properties = {
      hostname          = "${var.k8s-nodes.hostname}${count.index + 1}"
      user-data         = base64encode(templatefile("templates/k8snodes-cloud-init.yml", { username = var.k8s-global.username, public-key = data.local_file.ssh-publickey.content, iscsi-ip-addr = "[${var.k8s-nodes.iscsi_subnet}${var.k8s-nodes.iscsi_startip + count.index}/${var.k8s-nodes.iscsi_maskbits}]", hostname="${var.k8s-nodes.hostname}${count.index + 1}", use_iscsi_nic = var.k8s-nodes.use_iscsi_interface, iscsi_int_name = var.k8s-nodes.iscsi_interface_name }))
    }
  }

  clone {
    template_uuid       = data.vsphere_virtual_machine.template.id
  }

  wait_for_guest_net_timeout = 10

  depends_on = [
    data.local_file.ssh-publickey,
  ]
}

resource "null_resource" "cloud-init-adminhost" {
  triggers = {
     build_number = 2
  }
  
  connection {
    host = vsphere_virtual_machine.k8s-adminhost.default_ip_address
    type = "ssh"
    user = var.k8s-global.username
    private_key = file(var.k8s-global.private_key)
  }

  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /etc/cloud/cloud-init.done ]; do sleep 2; done",
    ]
  }
}

# Copy private/public keys for passwordless authentication to adminhost
resource "null_resource" "set-public-key" {
  triggers = {
     build_number = 2
  }
  
  connection {
    host = vsphere_virtual_machine.k8s-adminhost.default_ip_address
    type = "ssh"
    user = var.k8s-global.username
    private_key = file(var.k8s-global.private_key)
  }

  provisioner "file" {
    source          = var.k8s-global.private_key
    destination     = "~/.ssh/id_rsa"
  }

  provisioner "file" {
    source          = var.k8s-global.public_key
    destination     = "~/.ssh/id_rsa.pub"
  }

  provisioner "remote-exec" {
    inline         = ["chmod 600 ~/.ssh/id_rsa",]
  }
}

resource "null_resource" "prepare-kubespray" {
  connection {
    host = vsphere_virtual_machine.k8s-adminhost.default_ip_address
    type = "ssh"
    user = var.k8s-global.username
    private_key = file(var.k8s-global.private_key)
  }

  provisioner "remote-exec" {
    inline = [
      "curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl",
      "chmod +x kubectl",
      "sudo mv kubectl /usr/local/bin/",
      "sudo apt-get -y install python3-pip",
      "pip3 install --upgrade pip",
      "git clone https://github.com/kubernetes-sigs/kubespray.git",
      "cd ~/kubespray",
      "pip3 install -r requirements.txt",
      "cp -rfp inventory/sample inventory/k8s-on-vmware",
      "echo ${join(" ", vsphere_virtual_machine.k8s-nodes.*.default_ip_address)} >/tmp/ips",
      "echo \"#!/bin/bash\" > ~/run-kubespray.sh",
      "echo \"cd ~/kubespray/\" >> ~/run-kubespray.sh",
      "echo \"declare -a IPS=(`cat /tmp/ips`)\" >> ~/run-kubespray.sh",
      "echo \"CONFIG_FILE=inventory/k8s-on-vmware/hosts.yml python3 contrib/inventory_builder/inventory.py \\$${IPS[@]}\" >> ~/run-kubespray.sh",
      "echo \"~/.local/bin/ansible-playbook -i inventory/k8s-on-vmware/hosts.yml --become --become-user=root cluster.yml\" >> ~/run-kubespray.sh",
      "echo \"cd ~/\" >> ~/run-kubespray.sh",
      "echo \"mkdir .kube\" >> ~/run-kubespray.sh",
      "echo \"ssh -oStrictHostKeyChecking=no ${vsphere_virtual_machine.k8s-nodes[0].default_ip_address} sudo cp /etc/kubernetes/admin.conf ~/config\" >> ~/run-kubespray.sh",
      "echo \"ssh -oStrictHostKeyChecking=no ${vsphere_virtual_machine.k8s-nodes[0].default_ip_address} sudo chown ${var.k8s-global.username}:${var.k8s-global.username} ~/config\" >> ~/run-kubespray.sh",
      "echo \"scp -oStrictHostKeyChecking=no ${vsphere_virtual_machine.k8s-nodes[0].default_ip_address}:~/config .kube/config\" >> ~/run-kubespray.sh",
      "echo \"ssh -oStrictHostKeyChecking=no ${vsphere_virtual_machine.k8s-nodes[0].default_ip_address} rm ~/config\" >> ~/run-kubespray.sh",
      "chmod +x ~/run-kubespray.sh",
    ]
  }
  depends_on = [
    vsphere_virtual_machine.k8s-adminhost,
    vsphere_virtual_machine.k8s-nodes,
    null_resource.set-public-key,
    null_resource.cloud-init-adminhost,
  ]
}

resource "null_resource" "run-kubespray" {
  count = var.k8s-global.run_kubespray == "yes" ? 1 : 0
  
  connection {
    host = vsphere_virtual_machine.k8s-adminhost.default_ip_address
    type = "ssh"
    user = var.k8s-global.username
    private_key = file(var.k8s-global.private_key)
  }
 
  provisioner "remote-exec" {
    inline = [
      "cd ~/",
      "~/run-kubespray.sh",
    ]
  }
  depends_on = [
    null_resource.prepare-kubespray,
  ]
}

output "k8s-adminhost-ip" {
  value = vsphere_virtual_machine.k8s-adminhost.default_ip_address
}

output "k8s-node_ips" {
  value = ["${vsphere_virtual_machine.k8s-nodes[*].default_ip_address}"]
}