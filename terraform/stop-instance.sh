#!/bin/bash
# Auto-stop EC2 after 2 hours (to save cost)

STAGE=${1:-dev}

INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=DevOps-Assignment-${STAGE}" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text)

echo "Waiting 2 hours before stopping instance $INSTANCE_ID..."
sleep 7200

aws ec2 stop-instances --instance-ids $INSTANCE_ID
