# Resource to verify S3 read access using the read-only role
resource "null_resource" "verify_s3_access" {
  triggers = {
    bucket_name = var.s3_bucket_name
    role_arn    = aws_iam_role.s3_readonly_role.arn
  }

  provisioner "local-exec" {
    command = <<EOF
      # Assume the read-only role and verify access
      CREDENTIALS=$(aws sts assume-role \
        --role-arn ${aws_iam_role.s3_readonly_role.arn} \
        --role-session-name "s3-read-verify" \
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
        --output text)
      
      if [ $? -eq 0 ]; then
        AKI=$(echo $CREDENTIALS | awk '{print $1}')
        SAK=$(echo $CREDENTIALS | awk '{print $2}')
        ST=$(echo $CREDENTIALS | awk '{print $3}')
        
        # Try to list objects in the bucket using the assumed role
        AWS_ACCESS_KEY_ID=$AKI AWS_SECRET_ACCESS_KEY=$SAK AWS_SESSION_TOKEN=$ST \
          aws s3 ls s3://${var.s3_bucket_name}/ && \
        echo "SUCCESS: Read-only role can list objects in S3 bucket"
        
        # Try to download a file (should fail)
        AWS_ACCESS_KEY_ID=$AKI AWS_SECRET_ACCESS_KEY=$SAK AWS_SESSION_TOKEN=$ST \
          aws s3 cp s3://${var.s3_bucket_name}/app/logs/test.txt /tmp/ 2>/dev/null && \
        echo "ERROR: Read-only role should not be able to download" || \
        echo "SUCCESS: Read-only role cannot download (as expected)"
      else
        echo "ERROR: Failed to assume read-only role"
        exit 1
      fi
    EOF
  }

  depends_on = [aws_s3_bucket.logs_bucket, aws_iam_role_policy_attachment.s3_readonly_attachment]
}
