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

variable "instance_name" {
  description = "Name of the EC2 instance"
  type        = string
  default     = "monai-build"
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
  default     = "monai-build-key"
}

variable "ssh_key_path" {
  description = "Path to the SSH public key file"
  type        = string
  default     = "/tmp/ssh_id_gh.pub"
}

resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = file(var.ssh_key_path)
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
  ami           = "ami-042c4996f2266c092"
  instance_type = "g4dn.xlarge"
  key_name      = aws_key_pair.deployer.key_name
  vpc_security_group_ids= [length(data.aws_security_group.existing_ssh_only_sg.id) > 0 ? data.aws_security_group.existing_ssh_only_sg.id : aws_security_group.ssh_only_sg[0].id]

  tags = {
    Name = var.instance_name
  }
}

data "aws_vpc" "default" {
  default = true
}

output "instance_public_ip" {
  description = "The public IP for SSH access"
  value       = aws_instance.vm.public_ip 
}

output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.vm.id
}
