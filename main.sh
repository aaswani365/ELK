#!/usr/bin/env bash

set -e

# Create a Jenkins AMI using Packer.
create_ami () {
  set -x
  packer build \
  packer/jenkins-ami.json
  set +x
}

# Grab the AMI-ID from manifest file to attach to the EC2 Instance.
find_ami_id () {
  set -x
  ami_version=`cat packer/manifest.json | jq -r '.builds[-1].artifact_id' | cut -d ':' -f 2`
  echo $ami_version
  #The following will write jenkins_ami_id=ami-id to the tfvars file
  echo "jenkins_ami_id="\"$ami_version\""" >> terraform/terraform.tfvars
  #sed -i -e """s/jenkins_ami_id=""/jenkins_ami_id=`$ami_version`"""

  set +x
}

# Create a PEM key to attach to the EC2 Instance.
# Current implementation seems to struggle when it sees / in the random strings generated. Just try a couple of times.
# Changed to hex to eliminate the "=" and "/" issues with base64
create_aws_key () {
  set -x
  # Randomize keyname to avoid some conflict
  AWS_KEYNAME=$(openssl rand -hex 12)
  echo $AWS_KEYNAME
  # This uses AWS CLI to generate unique key-pairs everytime this project is run.
  aws ec2 create-key-pair --key-name $AWS_KEYNAME --query 'KeyMaterial' --output text > $AWS_KEYNAME.pem
  chmod 400 $AWS_KEYNAME.pem
  # The following will write jenkins_key_name="$AWS_KEYNAME" to the terraform/terraform.tfvars file.
  echo "jenkins_key_name="\"$AWS_KEYNAME\""" >> terraform/terraform.tfvars
  set +x
}

# Use Terraform to Provision Infrastructure in AWS.
terraform_apply () {
  set -x
  cd terraform
  terraform init
  terraform plan \
  -out jenkins.terraform
  terraform apply jenkins.terraform
  cd ..
  set +x
}
# These below already work ( Do Not Modify). Just Uncomment to Use it.
create_aws_key
create_ami
find_ami_id
terraform_apply

