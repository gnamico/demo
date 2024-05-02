# Configura el proveedor de Terraform para AWS
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Establece el proveedor AWS y especifica la región
provider "aws" {
  region = "us-east-1" # Ajusta a la región deseada
}

# Crea un VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "gh-actions-build-monai-models-vpc"
  }
}

# Crea una subred en el VPC
resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "gh-actions-build-monai-models-subnet"
  }
}

# Crea una dirección IP elástica
resource "aws_eip" "public_ip" {
  vpc = true
}

# Crea una interfaz de red con la dirección IP elástica
resource "aws_network_interface" "main_nic" {
  subnet_id       = aws_subnet.main.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.main.id]
}

# Crea un grupo de seguridad que permite SSH
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

# Define un par de claves SSH
resource "aws_key_pair" "deployer" {
  key_name   = "terraform-deployer-key"
  public_key = file("/tmp/ssh_id_gh.pub")
}

# Crea una instancia EC2 que usa la interfaz de red y las claves SSH
resource "aws_instance" "vm" {
  ami           = "ami-04b70fa74e45c3917" # Reemplaza con la AMI adecuada
  instance_type = "t2.medium"
  key_name      = aws_key_pair.deployer.key_name

  network_interface {
    network_interface_id = aws_network_interface.main_nic.id
    device_index         = 0
  }

  associate_public_ip_address = true

  root_block_device {
    volume_size = 64
  }

  user_data = <<-EOF
              #!/bin/bash
              echo 'connected!'
              EOF

  tags = {
    Name = "gh-actions-build-monai-models-vm"
  }
}

# Salida para obtener la dirección IP pública de la instancia
output "instance_public_ip" {
  description = "Public IP address of the instance"
  value       = aws_instance.vm.public_ip
}
