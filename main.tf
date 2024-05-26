terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_key_pair" "deployer" {
  key_name   = "terraform-deployer-key"
  public_key = file("/tmp/ssh_id_gh.pub")
}

data "aws_security_group" "ssh_only_sg" {
  name = "ssh-only-sg"
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = "ec2_role"
}

#data "aws_vpc" "default" {
 # default = true
#}

#resource "aws_security_group" "ssh_sg" {
 # name        = "ssh-only-sg"
  #description = "Security Group for SSH access only"
  #vpc_id      = data.aws_vpc.default.id

  #ingress {
   # description      = "SSH from specific IP"
    #from_port        = 22
    #to_port          = 22
    #protocol         = "tcp"
    #cidr_blocks      = ["0.0.0.0/0"]
  #}

 # egress {
  #  from_port        = 0
   # to_port          = 0
    #protocol         = "-1"
    #cidr_blocks      = ["0.0.0.0/0"]
  #}

  #tags = {
   # Name = "SSH Only SG"
  #}
#}

resource "aws_instance" "vm" {
  ami           = "ami-0ad306b0d02ab2e3b"
  instance_type = "g4dn.xlarge"
  key_name      = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [data.aws_security_group.ssh_only_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name

  tags = {
    Name = "gh-actions-build-monai-models-vm"
  }
}

output "instance_public_ip" {
  description = "The public ip for ssh access"
  value       = aws_instance.vm.public_ip 
}

