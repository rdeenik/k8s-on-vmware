# Deploy Kubernetes on VMware vSphere using Terraform and Kubespray
This Terraform project allows you to deploy Kubernetes on vSphere. It uses Kubespray for the deployment and allows you to tweak (some, more are coming is time permits) of the deployment options.

## System requirements

To be able to apply this Terraform configuration to your vSphere environment, make sure you have to following requirements in place. Basically all you need are git, for cloning the github repo and the Terraform binary to run the playbook.

### MacOS:
- Install xcode, since xcode contains tools like `git` that we use to download this repo.
  ```
  xcode-select --install
  ```

- Install Terraform, see https://learn.hashicorp.com/terraform/getting-started/install.html for instructions.

  Example steps for installing Terraform 0.12.23 (latest version at the time of writing):
  ```
  curl -O https://releases.hashicorp.com/terraform/0.12.23/terraform_0.12.23_darwin_amd64.zip
  unzip terraform_0.12.23_darwin_amd64.zip
  sudo mkdir -p /usr/local/bin
  sudo mv terraform /usr/local/bin/
  ```

  Test the Terraform installation (this command should return the Terraform version installed):
  
  `terraform -v`
  
## Deployment procedure
The following steps need to be executed in order ot deploy Kubernetes using this Terraform configuration to your VMware vSphere environment.

1. Download an Ubuntu Cloud image OVA (http://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.ova) and add that to your vSphere environment as template virtual machine.
2. The first step is to download this repo to you workstation.

   ```
   git clone https://github.com/dnix101/k8s-on-vsphere.git
   ```

3. Change the `variables.tf` file to match your environment.
   - Specify your vCenter server details, cluster, datastore and networking details in the `vsphere_config` section;
   - If you which make changes to the `k8s-global` settings or the `k8s-adminhost` settings if you want;
   - Make sure you set the correct iscsi_subnet (if you require it) in the `k8snodes` section.
4. Deploy Kubernetes using Terraform by executing the following commands:

   - First we need to initialize terraform (downloading the required Terraform providers for this project)
   
     `terraform init`
   
   - econdly we need to plan the terraform project, to make sure we are ready to deploy. You might get some errors on your vSphere environment details if you made a mistake in the variables.tf file.
   
     `terraform plan`
   
   - Finally apply the project, at which point the VM's and Kubespray are being deployed.
   
     `terraform apply`
   
   
