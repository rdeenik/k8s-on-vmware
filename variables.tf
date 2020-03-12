# Generic vSphere config variables
variable "vsphere_config" {
    type                        = map(string)
    description                 = "vSphere environment and connection details"

    default = {
        # Enter your vCenter server IP address or DNS name below and the 
        vcenter_server          = ""
        user                    = "administrator@vsphere.local"
        password                = ""
        # Enter the datacenter, cluster and datastore to deploy the VM's to
        datacenter              = "datacenter"
        cluster                 = "cluster"
        datastore               = "datastore1"
        # Enter the network portgroup names to use, iscsi_network is optional, see k8s-nodes
        vm_network              = "VM Network"
        iscsi_network           = "iSCSI"
    }
}

# Global K8S cluster parameters
variable "k8s-global" {
    type                        = map(string)
    description                 = "Global settings for the k8s cluster"

    default = {
        username                = "k8sadmin"
        timezone                = "Europe/Amsterdam"
        run_kubespray           = "no"
        kube_version             = "v1.17.2"
        #kube_version             = "default"
        private_key             = "keys/id_rsa-k8s-on-vmware"
        public_key              = "keys/id_rsa-k8s-on-vmware.pub"
    }
}

# Admin node config parameters
variable "k8s-adminhost" {
    type                        = map(string)
    description                 = "Details for the k8s administrative node"

    default = {
        hostname                = "k8s-adminhost"
        num_cpus                = "2"
        memory                  = "1024"
        disk_size               = "20"
        template                = "ubuntu-bionic-18.04-cloudimg"
    }
}

# K8S node config parameters
variable "k8s-nodes" {
    type                        = map(string)
    description                 = "Details for the k8s worker nodes"

    default = {
        number_of_nodes         = "3"
        hostname                = "k8s-node"
        num_cpus                = "2"
        memory                  = "2048"
        disk_size               = "20"
        template                = "ubuntu-bionic-18.04-cloudimg"
        use_iscsi_interface     = "yes"
        iscsi_interface_name    = "ens224"
        iscsi_subnet            = "172.16.10."
        iscsi_startip           = "101"
        iscsi_maskbits          = "24"
    }
}