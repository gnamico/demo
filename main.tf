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
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default_VPC"
  }
}

resource "aws_security_group" "security" {
  name = "allow-SSH"
  vpc_id = aws_default_vpc.default.id

  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}                                                                                    


resource "aws_instance" "vm" {
  ami           = "ami-04b70fa74e45c3917"
  instance_type = "t2.medium"
  key_name      = aws_key_pair.deployer.key_name
  security_groups             = ["${aws_security_group.security.id}"]

  tags = {
    Name = "gh-actions-build-monai-models-vm"
  }
}

output "instance_public_ip" {
  description = "The public ip for ssh access"
  value       = aws_instance.vm.public_ip 
}

