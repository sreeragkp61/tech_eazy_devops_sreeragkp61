# EC2 Automation for DevOps Assignment

Simple Terraform setup to automate EC2 deployment with stage-specific configurations.

## Free Tier Compatibility
- **Instance Type**: t2.micro/t3.micro (Free Tier eligible)
- **Storage**: 8GB GP2 EBS (Free Tier: 30GB)
- **Usage**: 750 hours/month free

## Prerequisites
1. AWS Account with Free Tier
2. AWS CLI configured (`aws configure`)
3. Terraform installed
4. EC2 Key Pair created in AWS Console

## Setup

### 1. AWS Configuration
```bash
aws configure
# Enter: AWS Access Key, Secret Key, Region (us-east-1), Output format (json)
2. Create Key Pair
bash
# In AWS Console: EC2 > Key Pairs > Create
# Name: my-key-pair
# Download .pem file and set permissions:
chmod 400 my-key-pair.pem
3. Deploy Application
Development Environment:

bash
terraform init
terraform apply -var="stage=dev"
Production Environment:

bash
terraform apply -var="stage=prod"
What This Script Does
Creates EC2 Instance - Free tier eligible (t2.micro/t3.micro)

Installs Dependencies - Java 21, Git, Maven

Clones & Deploys App - From specified GitHub repo

Builds Application - Using mvn clean package

Runs Application - Java Spring Boot app on port 8080

Auto-stops Instance - After specified time (cost saving)

Stage-specific Config - Different settings for dev/prod

Testing
After deployment, check outputs:

bash
# Access application
curl http://<public-ip>:8080

# SSH to instance
ssh -i my-key-pair.pem ec2-user@<public-ip>
Cost Optimization
Instances auto-stop after configured delay

Uses Free Tier eligible resources

t2.micro/t3.micro instances

Minimal EBS storage

Files Explained
main.tf - EC2 instance, security group, AMI configuration

variables.tf - Input variables (stage, region, key pair)

outputs.tf - Display instance info and access details

userdata.sh - Installation and deployment script

config/ - Stage-specific configurations

Security Notes
No secrets in code - uses AWS credentials from environment

Security group allows only necessary ports (22, 80, 8080)

Uses existing key pair for SSH access

text

## Usage Instructions

1. **Setup AWS CLI:**
```bash
aws configure
# Enter your AWS credentials when prompted
Initialize and deploy:

bash
terraform init
terraform apply -var="stage=dev" -var="key_name=your-key-pair-name"
Destroy resources:

bash
terraform destroy
