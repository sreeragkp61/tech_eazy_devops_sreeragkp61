output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.app_server.id
}

output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.app_server.public_ip
}

output "app_url" {
  description = "URL to access the application on port 80"
  value       = "http://${aws_instance.app_server.public_ip}"
}

output "ssh_command" {
  description = "Command to SSH into the instance"
  value       = "ssh -i your-key.pem ec2-user@${aws_instance.app_server.public_ip}"
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for logs"
  value       = aws_s3_bucket.logs_bucket.bucket
}

output "s3_readonly_role_arn" {
  description = "ARN of the S3 read-only role"
  value       = aws_iam_role.s3_readonly_role.arn
}

output "s3_write_role_arn" {
  description = "ARN of the S3 write role attached to EC2"
  value       = aws_iam_role.s3_write_role.arn
}

output "s3_bucket_url" {
  description = "S3 bucket URL"
  value       = "s3://${aws_s3_bucket.logs_bucket.bucket}"
}
