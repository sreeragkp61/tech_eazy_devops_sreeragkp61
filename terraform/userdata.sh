#!/bin/bash

# Update system and install dependencies
yum update -y
amazon-linux-extras enable java-openjdk21
yum install -y java-21-openjdk-devel git maven

# Verify installations
java -version
mvn -version

# Clone and deploy application
cd /home/ec2-user
git clone https://github.com/Trainings-TechEazy/test-repo-for-devops app
cd app

# Build application
mvn clean package -DskipTests

# Run application in background
nohup java -jar target/techeazy-devops-0.0.1-SNAPSHOT.jar > app.log 2>&1 &

# Wait for app to start and test
sleep 30
curl -f http://localhost:8080 && echo "Application deployed successfully!"

# Create a simple health check endpoint
echo "#!/bin/bash
while true; do
    if curl -f http://localhost:8080 >/dev/null 2>&1; then
        echo \"App is running\"
    else
        echo \"App is down\"
    fi
    sleep 60
done" > health_check.sh

chmod +x health_check.sh
nohup ./health_check.sh > health.log 2>&1 &
