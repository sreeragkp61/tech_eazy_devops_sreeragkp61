terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Read stage-specific configuration
locals {
  config_file = file("config/${var.stage}_config.json")
  config      = jsondecode(local.config_file)
}

# Get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Security Group allowing SSH and HTTP
resource "aws_security_group" "app_sg" {
  name        = "devops-app-${var.stage}-sg"
  description = "Allow SSH and HTTP traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access for application"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devops-app-${var.stage}"
  }
}

# EC2 Instance
resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = local.config.instance_type
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  key_name               = var.key_name

  # User data script to install and run app
  user_data = filebase64("userdata.sh")

  tags = {
    Name  = "devops-app-${var.stage}"
    Stage = var.stage
  }

  # Auto-stop instance after specified time (cost saving)
  provisioner "local-exec" {
    command = "sleep ${local.config.shutdown_delay} && aws ec2 stop-instances --instance-ids ${self.id} --region ${var.aws_region}"
  }
}

