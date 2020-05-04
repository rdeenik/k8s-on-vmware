# Configuring K8S-on-VMware using the variables.ft file

## Introduction

This Terraform project allows you to deploy Kubernetes on vSphere. It uses Kubespray for the deployment and allows you to tweak (some, more are coming is time permits) of the deployment options. It will automatically create VM's on VMware vSphere required to deploy Kubernetes using Kubespray. Then it will download Kubespray and prepare the nodes. Finally it can automatically run Kubespray to deploy Kubernetes, but you can also choose to hold-of with the Kubespray deployment (see the run_kubespray parameter below), so that you can tweak the Kubespray parameters. Once have the correct settings in place for Kubespray you can run Kubespray with a single command (~/run_kubespray.sh) to deploy Kubernetes.

The purpose of this project is to provide a quick Kubernetes environment for training and experimenting. If you're going to deploy a production environment, you're beter of with a more mature Kubernetes distribution or deployment.
  

## How to configure the project
All configurable settings are located in the `variables.tf` file at the root of the project.

### Generic vSphere config variables
Parameter | Example | Description
--------- | ------- | -----------
vcenter_server | 10.1.1.1 | The IP address or DNS name of you vCenter server
user | "administrator@vsphere.local"
password | ""
datacenter | "datacenter"
cluster | "cluster"
datastore | "datastore1"
vm_network | "VM Network"
iscsi_network | "iSCSI"

# Global K8S cluster parameters
variable "k8s-global" {
    type                        = map(string)
    description                 = "Global settings for the k8s cluster"

    default = {
        # Enter a username (other than root), which you'll use to login to the adminhost and k8s nodes
        username                = "k8sadmin"
        # Specify the time zone for the servers
        timezone                = "Europe/Amsterdam"
        # If you want to run Kubespray automatically as part of the Terraform project set run_kubespray to "yes", if you want to tweak Kubespray parameters set to no
        run_kubespray           = "yes"
        # If you want a specific version of Kubernetes set kube_version to the requested version, otherwise set to "default" to use the Kubespray default version
        kube_version             = "v1.17.2"
        #kube_version             = "default"
        # Where would you like to store the public and private keys to use to logon to the servers and for the passwordless access required by Kubespray
        private_key             = "keys/id_rsa-k8s-on-vmware"
        public_key              = "keys/id_rsa-k8s-on-vmware.pub"
    }
}

# Admin node config parameters
variable "k8s-adminhost" {
    type                        = map(string)
    description                 = "Details for the k8s administrative node"

    default = {
        # Which hostname and virtual machine name do you want to use for the administrative host
        hostname                = "k8s-adminhost"
        # Specify the VM resources for the administrative host
        num_cpus                = "2"
        memory                  = "1024"
        disk_size               = "20"
        # Specify the details for the management interface.
        mgmt_use_dhcp          = "no"
        mgmt_interface_name    = "ens192"
        mgmt_ip                = "192.168.10.150/24"
        mgmt_gateway           = "192.168.10.254"
        mgmt_dns_servers       = "8.8.8.8,8.8.4.4"
        # Specify the name of the Ubuntu Cloud Image template in vSphere (download template from cloud-images.ubuntu.com)
        template                = "ubuntu-bionic-18.04-cloudimg"
    }
}

# K8S node config parameters
variable "k8s-nodes" {
    type                        = map(string)
    description                 = "Details for the k8s worker nodes"

    default = {
        # Which hostname and virtual machine name do you want to use for the K8S nodes, this name will be followed by the node count (eg. k8s-node1)
        hostname                = "k8s-node"
        # Specify the number of Kubernetes nodes you wish to deploy (normally you should deploy 3 or more)
        number_of_nodes         = "3"
        # Specify the VM resources for the administrative host
        num_cpus                = "2"
        memory                  = "2048"
        disk_size               = "20"
        # Specify the name of the Ubuntu Cloud Image template in vSphere (download template from cloud-images.ubuntu.com)
        template                = "ubuntu-bionic-18.04-cloudimg"
        # Specify the details for the management interface.
        mgmt_use_dhcp          = "no"
        mgmt_interface_name    = "ens192"
        mgmt_subnet            = "192.168.10.0/24"
        mgmt_startip           = "151"
        mgmt_gateway           = "192.168.10.254"
        mgmt_dns_servers       = "8.8.8.8,8.8.4.4"
        # Specify the details for the iSCSI interface. If you do not need a second interface, set use_iscsi_interface to "no" and remove the second NIC section from main.tf
        use_iscsi_interface     = "yes"
        iscsi_use_dhcp          = "no"
        iscsi_interface_name    = "ens224"
        iscsi_subnet            = "172.16.10.0/24"
        iscsi_startip           = "151"
    }
}