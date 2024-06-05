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
  region = var.aws_region
}

variable "instance_name" {
  description = "Name of the EC2 instance"
  type        = string
  default     = "monai"
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
  default     = "monai-key"
}

variable "ssh_key_path" {
  description = "Path to the SSH public key file"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "disk_size" {
  description = "Size of the disk in gigabytes"
  type        = number
  default     = 150
}

resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = file(var.ssh_key_path)
}


data "aws_ami" "dlami" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Deep Learning Base OSS Nvidia Driver GPU AMI (Ubuntu 22.04) *"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "ssh_only_sg" {
  name_prefix = "ssh-only-sg-"
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
 #ami           = "ami-042c4996f2266c092"
  ami           = data.aws_ami.dlami.id
  instance_type = "g4dn.xlarge"
  key_name      = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.ssh_only_sg.id]

  root_block_device {
    volume_size = var.disk_size
  }

  tags = {
    Name = var.instance_name
  }
}

output "instance_public_ip" {
  description = "The public IP for SSH access"
  value       = aws_instance.vm.public_ip 
}

output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.vm.id
}
