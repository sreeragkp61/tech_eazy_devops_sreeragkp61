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

locals {
  config_file = file("config/${var.stage}_config.json")
  config      = jsondecode(local.config_file)
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# ----------------- IAM Roles & Policies -----------------
resource "aws_iam_role" "s3_readonly_role" {
  name = "s3-readonly-role-${var.stage}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::774305617674:user/ec2-internship" }
    }]
  })

  tags = { Name = "s3-readonly-role-${var.stage}" }
}

resource "aws_iam_policy" "s3_readonly_policy" {
  name        = "s3-readonly-policy-${var.stage}"
  description = "Policy for S3 read only access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject","s3:ListBucket"]
      Resource = [
        "arn:aws:s3:::${var.s3_bucket_name}",
        "arn:aws:s3:::${var.s3_bucket_name}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "s3_readonly_attachment" {
  role       = aws_iam_role.s3_readonly_role.name
  policy_arn = aws_iam_policy.s3_readonly_policy.arn
}

resource "aws_iam_role" "s3_write_role" {
  name = "s3-write-role-${var.stage}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = { Name = "s3-write-role-${var.stage}" }
}

resource "aws_iam_policy" "s3_write_policy" {
  name        = "s3-write-policy-${var.stage}"
  description = "Policy for S3 write access only"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject","s3:PutObjectAcl"]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:CreateBucket"]
        Resource = ["arn:aws:s3:::${var.s3_bucket_name}"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_write_attachment" {
  role       = aws_iam_role.s3_write_role.name
  policy_arn = aws_iam_policy.s3_write_policy.arn
}

resource "aws_iam_instance_profile" "ec2_s3_write_profile" {
  name = "ec2-s3-write-profile-${var.stage}"
  role = aws_iam_role.s3_write_role.name
}

# ----------------- S3 Bucket -----------------
resource "aws_s3_bucket" "logs_bucket" {
  bucket = var.s3_bucket_name
  tags   = { Name = "logs-bucket-${var.stage}", Environment = var.stage }
}

resource "aws_s3_bucket_public_access_block" "private_bucket" {
  bucket                  = aws_s3_bucket.logs_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs_lifecycle" {
  bucket = aws_s3_bucket.logs_bucket.id

  rule {
    id     = "delete-after-7-days"
    status = "Enabled"

    expiration { days = 7 }

    filter { prefix = "" }
  }
}

# ----------------- Security Group -----------------
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

  tags = { Name = "devops-app-${var.stage}" }
}

# ----------------- EC2 Instance -----------------
resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = local.config.instance_type
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_s3_write_profile.name

  user_data = base64encode(templatefile("userdata.sh", {
    s3_bucket_name = var.s3_bucket_name
    aws_region     = var.aws_region
  }))

  tags = { Name = "devops-app-${var.stage}", Stage = var.stage }
}

# ----------------- Upload Cloud-init logs -----------------
# Optional: only if you want to keep it without stopping the instance
resource "null_resource" "upload_cloud_init_logs" {
  triggers = { instance_id = aws_instance.app_server.id }

  provisioner "local-exec" {
    command = <<EOF
      aws ec2 get-console-output --instance-id ${aws_instance.app_server.id} --region ${var.aws_region} --output text > /tmp/cloud-init-${aws_instance.app_server.id}.log
      aws s3 cp /tmp/cloud-init-${aws_instance.app_server.id}.log s3://${var.s3_bucket_name}/ec2/logs/cloud-init-${aws_instance.app_server.id}.log --region ${var.aws_region}
      rm /tmp/cloud-init-${aws_instance.app_server.id}.log
      echo 'Cloud-init logs uploaded to S3'
    EOF
  }
  depends_on = [aws_instance.app_server]
}

# ----------------- Verify S3 Access (Safe) -----------------
resource "null_resource" "verify_s3_access" {
  triggers = { bucket_name = var.s3_bucket_name }

  provisioner "local-exec" {
    command = <<EOF
      if aws s3 ls s3://${var.s3_bucket_name}/ > /dev/null 2>&1; then
        echo "SUCCESS: Can list objects in S3 bucket ${var.s3_bucket_name}"
      else
        echo "WARNING: Cannot list objects in S3 bucket ${var.s3_bucket_name}. Check IAM policies."
      fi
    EOF
  }
  depends_on = [aws_s3_bucket.logs_bucket, aws_iam_role_policy_attachment.s3_readonly_attachment]
}

