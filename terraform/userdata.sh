#!/bin/bash

# Update system and install essential packages
yum update -y
yum install -y git wget tar

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
