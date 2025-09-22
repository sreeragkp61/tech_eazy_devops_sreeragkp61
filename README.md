# tech_eazy_devops_sreeragkp61
devops assignment
# DevOps Assignment – Automate EC2 Deployment (Free Tier Safe)

## 📌 Features
- Terraform provisions an EC2 instance (t2.micro)
- Supports Dev/Prod configs (both t2.micro)
- Auto-stops instance after 2 hours
- AWS credentials read from ENV, not repo

---

## 🚀 Usage

### 1. Export AWS credentials
```bash
export AWS_ACCESS_KEY_ID=xxxx
export AWS_SECRET_ACCESS_KEY=xxxx
export AWS_DEFAULT_REGION=ap-south-1
2. Initialize Terraform
bash
Copy code
terraform init
3. Deploy EC2 (Dev Stage)
bash
Copy code
terraform apply -var stage=dev -auto-approve
4. Get Public IP
bash
Copy code
terraform output public_ip
Open in browser: http://<PUBLIC_IP>

5. Auto-stop instance after 2 hours
bash
Copy code
bash stop-instance.sh dev
Configs
config/dev_config.json → for Dev environment

config/prod_config.json → for Prod environment

yaml
Copy code
