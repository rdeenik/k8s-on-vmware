# Deploy Kubernetes on VMware vSphere using Terraform and Kubespray
This terraform project allows you to deploy Kubernetes on vSphere. It uses Kubespray for the deployment and allows you to tweak (some) of the deployment options.

## Installation requirements

### MacOS:
Install xcode, run:
```
xcode-select --install
```

**Install Terraform**
(see https://learn.hashicorp.com/terraform/getting-started/install.html)
https://releases.hashicorp.com/terraform/0.12.23/terraform_0.12.23_darwin_amd64.zip

Example steps:
`curl -O https://releases.hashicorp.com/terraform/0.12.23/terraform_0.12.23_darwin_amd64.zip
unzip terraform_0.12.23_darwin_amd64.zip
sudo mkdir -p /usr/local/bin
sudo mv terraform /usr/local/bin/`

Test installation:
`terraform -v`