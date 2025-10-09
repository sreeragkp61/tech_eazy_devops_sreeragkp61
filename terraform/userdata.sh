#!/bin/bash

# Update system and install essential packages
yum update -y
yum install -y git wget tar awscli

# Install Java 17 (Amazon Corretto)
yum install -y java-17-amazon-corretto-devel

# Verify Java installation
java -version

# Install Maven manually
cd /home/ec2-user
wget https://archive.apache.org/dist/maven/maven-3/3.8.4/binaries/apache-maven-3.8.4-bin.tar.gz
tar -xzf apache-maven-3.8.4-bin.tar.gz
export PATH=$PATH:/home/ec2-user/apache-maven-3.8.4/bin

# Clone the app repository
git clone https://github.com/Trainings-TechEazy/test-repo-for-devops app
cd app

# Build the application, skipping tests
mvn clean package -DskipTests

# Fix permissions for logs
touch /home/ec2-user/app.log
chown ec2-user:ec2-user /home/ec2-user/app.log

# Create directory for S3 upload script
mkdir -p /home/ec2-user/scripts

# Create script to upload logs to S3 on shutdown
cat > /home/ec2-user/scripts/upload_logs.sh << 'SCRIPT_EOF'
#!/bin/bash
# Script to upload logs to S3 before shutdown

BUCKET_NAME="${s3_bucket_name}"
REGION="${aws_region}"
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Upload application logs
aws s3 cp /home/ec2-user/app.log s3://$BUCKET_NAME/app/logs/app-$INSTANCE_ID-$TIMESTAMP.log --region $REGION

# Upload cloud-init logs
aws s3 cp /var/log/cloud-init.log s3://$BUCKET_NAME/ec2/logs/cloud-init-$INSTANCE_ID-$TIMESTAMP.log --region $REGION
aws s3 cp /var/log/cloud-init-output.log s3://$BUCKET_NAME/ec2/logs/cloud-init-output-$INSTANCE_ID-$TIMESTAMP.log --region $REGION

echo "Logs uploaded to S3 bucket: $BUCKET_NAME"
SCRIPT_EOF

# Make the upload script executable
chmod +x /home/ec2-user/scripts/upload_logs.sh

# Add shutdown hook to upload logs
echo "/home/ec2-user/scripts/upload_logs.sh" >> /etc/rc.local
chmod +x /etc/rc.local

# Run the Spring Boot app on port 80
sudo /usr/bin/java -jar /home/ec2-user/app/target/hellomvc-0.0.1-SNAPSHOT.jar --server.port=80 \
    | sudo tee /home/ec2-user/app.log >/dev/null 2>&1 &

# Wait for app to start
sleep 20

# Test whether app is running
if curl -f http://localhost/hello; then
    echo "SUCCESS: Application is running on port 80" >> /home/ec2-user/app.log
else
    echo "WARNING: Application may not be running properly" >> /home/ec2-user/app.log
fi

# Mark userdata completion
echo "Userdata completed at $(date)" > /home/ec2-user/userdata-complete.txt

# Schedule instance auto-shutdown after 30 minutes (1800 seconds)
(sleep 1800 && sudo shutdown -h now) &
