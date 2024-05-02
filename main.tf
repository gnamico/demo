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


resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "gh-actions-build-monai-models-subnet"
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "terraform-deployer-key"
  public_key = file("/tmp/ssh_id_gh.pub")
}

resource "aws_instance" "vm" {
  ami           = "ami-04b70fa74e45c3917"
  instance_type = "t2.medium"
  associate_public_ip_address = true
  key_name      = aws_key_pair.deployer.key_name

  tags = {
    Name = "gh-actions-build-monai-models-vm"
  }
}

output "instance_ip" {
  description = "The public ip for ssh access"
  value       = aws_instance.instance.public_ip
}

