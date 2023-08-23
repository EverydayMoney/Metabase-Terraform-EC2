terraform {
  cloud {
    organization = "EverydayMoney"
    workspaces {
      name = "EM-Dashboard-Metabase"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4.3"
    }
    acme = {
      source = "vancluever/acme"
      version = "2.10.0"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

provider "aws" {
  region = var.region
}

resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "metabase_ec2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = "MyPettyServer"

  root_block_device {
    volume_size = 8  # Specify the desired storage size in GB
  }

  vpc_security_group_ids = ["${aws_security_group.metabase_ec2.id}"]

  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    apt update -y
    apt install docker.io -y
    systemctl start docker
    usermod -a -G docker ubuntu
    docker pull metabase/metabase:latest
    docker run -d -p 3000:3000 \
      -e "MB_DB_TYPE=$DATABASE_DIALECT" \
      -e "MB_DB_DBNAME=$DATABASE_NAME" \
      -e "MB_DB_PORT=$DATABASE_PORT" \
      -e "MB_DB_USER=$DATABASE_USER" \
      -e "MB_DB_PASS=$DATABASE_PASSWORD" \
      -e "MB_DB_HOST=$DATABASE_HOST" \
      --name metabase metabase/metabase
  EOF
}

resource "aws_security_group" "metabase_ec2" {
  name        = "metabase_ec2-sg"
  description = "Security group for metabase_ec2 dashboard"
  
  vpc_id      = aws_default_vpc.default.id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

output "public_ip" {
  value = aws_instance.metabase_ec2.public_ip
}