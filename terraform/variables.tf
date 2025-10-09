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
variable "instance_count" {
  description = "Number of EC2 instances to spin up"
  type        = number
  default     = 2
}

variable "app_jar_s3_bucket" {
  description = "S3 bucket to upload app JAR"
  type        = string
   validation {
    condition     = length(var.app_jar_s3_bucket) > 0
    error_message = "S3 bucket name must be provided and cannot be empty."
  }
}

variable "app_jar_name" {
  description = "Name of the application JAR file"
  type        = string
  default     = "hellomvc-0.0.1-SNAPSHOT.jar"
}

