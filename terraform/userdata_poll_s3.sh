#!/bin/bash

# Update system and install essential packages
yum update -y
yum install -y git wget tar awscli

# Install Java
yum install -y java-17-amazon-corretto-devel
java -version

# Poll S3 for JAR updates and restart app
APP_JAR="/home/ec2-user/${app_jar_name}"
APP_LOG="/home/ec2-user/app.log"
APP_PORT=${app_port}

mkdir -p /home/ec2-user/scripts

cat > /home/ec2-user/scripts/poll_s3.sh << 'EOF'
#!/bin/bash
S3_BUCKET="${s3_bucket_name}"
APP_JAR="${app_jar_name}"
APP_LOG="/home/ec2-user/app.log"
APP_PORT=${app_port}

while true; do
  aws s3 cp s3://$S3_BUCKET/$APP_JAR /home/ec2-user/$APP_JAR
  if pgrep -f $APP_JAR; then
    pkill -f $APP_JAR
  fi
  nohup java -jar /home/ec2-user/$APP_JAR --server.port=$APP_PORT > $APP_LOG 2>&1 &
  sleep 60
done
EOF

chmod +x /home/ec2-user/scripts/poll_s3.sh
nohup /home/ec2-user/scripts/poll_s3.sh &

