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

data "aws_security_group" "existing_ssh_only_sg" {
  filter {
    name   = "group-name"
    values = ["ssh-only-sg"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "ssh_only_sg" {
  count       = length(data.aws_security_group.existing_ssh_only_sg.id) == 0 ? 1 : 0
  name        = "ssh-only-sg"
  description = "Security group for SSH access"

  ingress {
    description = "SSH from specific IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SSH Only SG"
  }
}

resource "aws_instance" "vm" {
  ami           = "ami-0ad306b0d02ab2e3b"
  instance_type = "g4dn.xlarge"
  key_name      = aws_key_pair.deployer.key_name
  vpc_security_group_id = [length(data.aws_security_group.existing_ssh_only_sg.id) > 0 ? data.aws_security_group.existing_ssh_only_sg.id : aws_security_group.ssh_only_sg[0].id]

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "gh-actions-build-monai-models-vm"
  }
}

data "aws_iam_role" "ec2_role" {
  name = "ec2-role"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  count = length(data.aws_iam_instance_profile.existing_profile.name) == 0 ? 1 : 0
  name = "ec2_instance_profile"
  role = data.aws_iam_role.ec2_role.name
}

data "aws_iam_instance_profile" "existing_profile" {
  name = "ec2_instance_profile"
}

data "aws_vpc" "default" {
  default = true
}

output "instance_public_ip" {
  description = "The public IP for SSH access"
  value       = aws_instance.vm.public_ip 
}
