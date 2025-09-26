variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "stage" {
  description = "Deployment stage (dev/prod)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.stage)
    error_message = "Stage must be either 'dev' or 'prod'."
  }
}

variable "key_name" {
  description = "Name of the existing EC2 key pair for SSH access"
  type        = string
  default     = "my-key-pair"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for logs (must be provided)"
  type        = string

  validation {
    condition     = length(var.s3_bucket_name) > 0
    error_message = "S3 bucket name must be provided and cannot be empty."
  }
}
