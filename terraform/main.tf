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

# IAM Role for S3 Read Only Access
resource "aws_iam_role" "s3_readonly_role" {
  name = "s3-readonly-role-${var.stage}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::774305617674:user/ec2-internship"
        }
      }
    ]
  })

  tags = {
    Name = "s3-readonly-role-${var.stage}"
  }
}

# IAM Policy for S3 Read Only Access
resource "aws_iam_policy" "s3_readonly_policy" {
  name        = "s3-readonly-policy-${var.stage}"
  description = "Policy for S3 read only access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      }
    ]
  })
}

# Attach read only policy to read only role
resource "aws_iam_role_policy_attachment" "s3_readonly_attachment" {
  role       = aws_iam_role.s3_readonly_role.name
  policy_arn = aws_iam_policy.s3_readonly_policy.arn
}

# IAM Role for S3 Write Access (for EC2 instance profile)
resource "aws_iam_role" "s3_write_role" {
  name = "s3-write-role-${var.stage}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "s3-write-role-${var.stage}"
  }
}

# IAM Policy for S3 Write Access (no read/download)
resource "aws_iam_policy" "s3_write_policy" {
  name        = "s3-write-policy-${var.stage}"
  description = "Policy for S3 write access only"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:CreateBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}"
        ]
      }
    ]
  })
}

# Attach write policy to write role
resource "aws_iam_role_policy_attachment" "s3_write_attachment" {
  role       = aws_iam_role.s3_write_role.name
  policy_arn = aws_iam_policy.s3_write_policy.arn
}

# IAM Instance Profile for EC2
resource "aws_iam_instance_profile" "ec2_s3_write_profile" {
  name = "ec2-s3-write-profile-${var.stage}"
  role = aws_iam_role.s3_write_role.name
}

# Private S3 Bucket
resource "aws_s3_bucket" "logs_bucket" {
  bucket = var.s3_bucket_name

  tags = {
    Name        = "logs-bucket-${var.stage}"
    Environment = var.stage
  }
}

# Block public access for the S3 bucket
resource "aws_s3_bucket_public_access_block" "private_bucket" {
  bucket = aws_s3_bucket.logs_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Lifecycle Rule - Delete logs after 7 days
resource "aws_s3_bucket_lifecycle_configuration" "logs_lifecycle" {
  bucket = aws_s3_bucket.logs_bucket.id

  rule {
    id = "delete-after-7-days"

    expiration {
      days = 7
    }

    status = "Enabled"

    filter {
      prefix = ""
    }
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
  iam_instance_profile   = aws_iam_instance_profile.ec2_s3_write_profile.name

  # User data script to install and run app
  user_data = base64encode(templatefile("userdata.sh", {
    s3_bucket_name = var.s3_bucket_name
    aws_region     = var.aws_region
  }))

  tags = {
    Name  = "devops-app-${var.stage}"
    Stage = var.stage
  }

  # Auto-stop instance after specified time and upload logs
  provisioner "local-exec" {
  command = <<EOF
    nohup sh -c "
      sleep ${local.config.shutdown_delay} && \
      aws ec2 stop-instances --instance-ids ${self.id} --region ${var.aws_region} && \
      sleep 60 && \
      aws s3 cp /home/ec2-user/app.log s3://${var.s3_bucket_name}/app/logs/app-${self.id}.log --region ${var.aws_region} && \
      echo 'Logs uploaded to S3 bucket: ${var.s3_bucket_name}'
    " > /tmp/app_server_provision.log 2>&1 &
  EOF
 }

}

# Null resource to upload cloud-init logs after instance shutdown
resource "null_resource" "upload_cloud_init_logs" {
  triggers = {
    instance_id = aws_instance.app_server.id
  }
  provisioner "local-exec" {
  command = <<EOF
    nohup sh -c "
      aws ec2 stop-instances --instance-ids ${aws_instance.app_server.id} --region ${var.aws_region} && \
      aws ec2 wait instance-stopped --instance-ids ${aws_instance.app_server.id} --region ${var.aws_region} && \
      aws ec2 get-console-output --instance-id ${aws_instance.app_server.id} --region ${var.aws_region} --output text > /tmp/cloud-init-${aws_instance.app_server.id}.log && \
      aws s3 cp /tmp/cloud-init-${aws_instance.app_server.id}.log s3://${var.s3_bucket_name}/ec2/logs/cloud-init-${aws_instance.app_server.id}.log --region ${var.aws_region} && \
      rm /tmp/cloud-init-${aws_instance.app_server.id}.log && \
      echo 'Cloud-init logs uploaded to S3'
    " > /tmp/cloud_init_upload.log 2>&1 &
  EOF
}
  depends_on = [aws_instance.app_server]
}
