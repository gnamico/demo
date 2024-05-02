terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "gh-actions-build-monai-models-vpc"
  }
}

resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "gh-actions-build-monai-models-subnet"
  }
}

resource "aws_security_group" "main" {
  name        = "gh-actions-build-monai-models-sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
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
}

resource "aws_key_pair" "deployer" {
  key_name   = "terraform-deployer-key"
  public_key = file("/tmp/ssh_id_gh.pub")
}

resource "aws_network_interface" "main_nic" {
  subnet_id       = aws_subnet.main.id
  security_groups = [aws_security_group.main.id]
  description     = "Main network interface for EC2 instance"
  associate_public_ip_address = true # Correctly place the IP assignment here
}

resource "aws_instance" "vm" {
  ami           = "ami-04b70fa74e45c3917"
  instance_type = "t2.medium"
  key_name      = aws_key_pair.deployer.key_name

  network_interface {
    network_interface_id = aws_network_interface.main_nic.id
    device_index         = 0
  }

  user_data = <<-EOF
                #!/bin/bash
                echo 'connected!'
                EOF

  tags = {
    Name = "gh-actions-build-monai-models-vm"
  }
}

output "instance_public_ip" {
  value = aws_network_interface.main_nic.association.public_ip
}

