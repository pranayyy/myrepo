# Phase 1: AWS Infrastructure Deployment Guide

## Overview

This guide covers deploying the Local Services API to AWS using Infrastructure as Code (Terraform). The deployment creates:

- **EC2 Instance** (t2.micro) running the FastAPI application
- **RDS PostgreSQL** database (db.t3.micro) with multi-AZ for high availability
- **VPC** with public/private subnets across 2 availability zones
- **Security Groups** with proper ingress/egress rules
- **IAM Roles** for secure service communication
- **Secrets Manager** for password storage
- **CloudWatch** monitoring and alarms

**Estimated Cost**: $20-25/month

---

## Prerequisites

### 1. AWS Account Setup

1. Create AWS account: https://aws.amazon.com/
2. Generate access keys in IAM:
   - Go to AWS Console → IAM → Users → Security credentials
   - Create access key pair
   - Save credentials securely

3. Install AWS CLI:
   ```bash
   # Windows (PowerShell as Administrator)
   msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi
   
   # macOS
   brew install awscli
   
   # Linux
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   ```

4. Configure AWS CLI:
   ```bash
   aws configure
   # Enter:
   # - AWS Access Key ID
   # - AWS Secret Access Key
   # - Default region: us-east-1
   # - Default output format: json
   ```

### 2. Install Terraform

```bash
# Windows (PowerShell)
choco install terraform

# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

Verify installation:
```bash
terraform --version  # Should show version 1.6+
```

### 3. Setup SSH Keys

Generate SSH key for EC2 access:

```bash
# Create SSH key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/local-services -N ""

# Verify (should not ask for password)
ssh -i ~/.ssh/local-services -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" -T echo "OK" || true
```

Save the path to public key for Terraform configuration.

---

## Step 1: Prepare Terraform

### 1.1 Clone/Navigate to Project

```bash
cd c:\Users\pranai_somannagari\gitdoc\local-services-app
```

### 1.2 Configure Variables

Copy and edit terraform variables:

```bash
# Copy example file
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# Edit terraform.tfvars
# On Windows: notepad terraform\terraform.tfvars
# On macOS/Linux: nano terraform/terraform.tfvars
```

Update the following values:

```hcl
aws_region              = "us-east-1"           # Change if needed
instance_type           = "t2.micro"            # Free tier eligible
db_instance_class       = "db.t3.micro"         # Cheapest option
db_allocated_storage    = 20                    # 20GB storage
ssh_public_key_path     = "~/.ssh/local-services.pub"  # Your SSH key path
environment             = "development"
```

### 1.3 Initialize Terraform

```bash
cd terraform
terraform init
```

Expected output:
```
Terraform has been successfully configured!
```

### 1.4 Review Infrastructure Plan

```bash
terraform plan -out=tfplan
```

Review the output to see all resources that will be created:
- 1 VPC
- 2 public subnets
- 2 private subnets
- 1 EC2 instance
- 1 RDS instance
- 3 security groups
- IAM roles and policies
- CloudWatch alarms

---

## Step 2: Deploy Infrastructure

### 2.1 Apply Terraform Configuration

```bash
terraform apply tfplan
```

This will:
1. Create all AWS resources
2. Display outputs with important values
3. Take approximately 5-10 minutes

**Save the outputs!** You'll need them to connect to your infrastructure:

```
Outputs:

api_docs_url = "http://YOUR_IP:8000/docs"
api_url = "http://YOUR_IP:8000"
ec2_instance_id = "i-xxxxxx"
ec2_public_ip = "3.xxx.xxx.xxx"
rds_address = "local-services-postgres.xxxxxx.us-east-1.rds.amazonaws.com"
rds_endpoint = "local-services-postgres.xxxxxx.us-east-1.rds.amazonaws.com:5432"
ssh_command = "ssh -i ~/.ssh/local-services ubuntu@3.xxx.xxx.xxx"
```

### 2.2 Wait for Instance Initialization

The EC2 instance runs a user data script that:
- Installs Python 3.11 and dependencies
- Clones the GitHub repository (requires git setup)
- Creates a virtual environment
- Configures systemd service
- Starts the API application

**Check initialization progress:**

```bash
# SSH into instance
ssh -i ~/.ssh/local-services ubuntu@YOUR_EC2_IP

# Check user data logs
tail -f /var/log/user-data.log

# Check service status
sudo systemctl status local-services-api

# View application logs
sudo tail -f /var/log/local-services/error.log
```

**Wait 2-3 minutes for the API to be ready.**

---

## Step 3: Verify Deployment

### 3.1 Test API Health

```bash
curl http://YOUR_EC2_IP:8000/health
# Expected response: {"status":"healthy"}
```

### 3.2 Access API Documentation

Open browser and navigate to:
```
http://YOUR_EC2_IP:8000/docs
```

### 3.3 Test Authentication Endpoint

```bash
curl -X POST http://YOUR_EC2_IP:8000/api/v1/auth/sign_up \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "username": "testuser",
    "password": "SecurePassword123!",
    "full_name": "Test User"
  }'

# Expected response: {"id": 1, "email": "test@example.com", ...}
```

### 3.4 Check RDS Database

```bash
# From EC2 instance
psql -h local-services-postgres.xxxxxx.us-east-1.rds.amazonaws.com \
     -U postgres \
     -d local_services \
     -c "\dt"

# Should show:
# public | alembic_version  | table
# public | ratings          | table
# public | services         | table
# public | tags             | table
# public | users            | table
```

---

## Step 4: Production Configuration

### 4.1 Update Environment Variables

SSH into EC2 and update production values:

```bash
ssh -i ~/.ssh/local-services ubuntu@YOUR_EC2_IP

# Edit environment file
sudo nano /opt/local-services-app/.env
```

Critical variables to update:

```bash
# Generate new secret key
SECRET_KEY="$(openssl rand -hex 32)"

# Update other production settings
ENVIRONMENT="production"
DEBUG="False"
LOG_LEVEL="INFO"

# Database (should already be configured)
POSTGRES_URL="postgresql://postgres:PASSWORD@RDS_ENDPOINT:5432/local_services"

# Allowed origins (update with your domain)
CORS_ORIGINS="https://yourdomain.com,https://www.yourdomain.com"
```

Restart service:
```bash
sudo systemctl restart local-services-api
sudo systemctl status local-services-api
```

### 4.2 Setup SSL/TLS with Let's Encrypt

```bash
# SSH into instance
ssh -i ~/.ssh/local-services ubuntu@YOUR_EC2_IP

# Install Certbot
sudo apt-get install -y certbot python3-certbot-nginx

# Generate certificate (replace with your domain)
sudo certbot certonly --standalone \
  -d local-services-api.example.com \
  --email admin@example.com \
  --agree-tos \
  --non-interactive

# Copy nginx config
sudo cp /opt/local-services-app/nginx/local-services-api.conf \
  /etc/nginx/sites-available/

# Update domain in nginx config
sudo sed -i 's/local-services-api.example.com/YOUR_DOMAIN/g' \
  /etc/nginx/sites-available/local-services-api.conf

# Enable site
sudo ln -s /etc/nginx/sites-available/local-services-api.conf \
  /etc/nginx/sites-enabled/

# Test nginx config
sudo nginx -t

# Restart nginx
sudo systemctl restart nginx

# Setup auto-renewal
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
```

### 4.3 Setup CloudWatch Monitoring

```bash
# From local machine, configure CloudWatch agent on EC2
# Logs automatically appear in CloudWatch

# View logs in AWS Console:
# CloudWatch → Log Groups → /aws/ec2/local-services-api
```

---

## Step 5: Backup & Recovery

### 5.1 Manual Database Backup

```bash
# SSH into EC2
ssh -i ~/.ssh/local-services ubuntu@YOUR_EC2_IP

# Backup database
pg_dump -h RDS_ENDPOINT -U postgres -d local_services \
  > ~/local-services-backup-$(date +%Y%m%d).sql

# Download backup
scp -i ~/.ssh/local-services \
  ubuntu@YOUR_EC2_IP:~/local-services-backup-*.sql .
```

### 5.2 RDS Automated Backups

- Configured in Terraform: 7-day retention
- Backups run daily at 3:00 UTC
- Accessible from AWS RDS console

---

## Step 6: Monitoring & Alerts

### 6.1 CloudWatch Alarms

Access AWS Console → CloudWatch → Alarms

Current alarms:
- **EC2 CPU > 80%** - Alert if instance overloaded
- **RDS CPU > 80%** - Alert if database overloaded

### 6.2 View Logs

```bash
# Application error logs
ssh -i ~/.ssh/local-services ubuntu@YOUR_EC2_IP
sudo tail -f /var/log/local-services/error.log

# Nginx logs
sudo tail -f /var/log/nginx/local-services-api_error.log

# Systemd journal
sudo journalctl -u local-services-api -f
```

### 6.3 Performance Monitoring

```bash
# SSH to instance
ssh -i ~/.ssh/local-services ubuntu@YOUR_EC2_IP

# Monitor resources
htop

# Check disk usage
df -h

# Check memory
free -h

# Check open connections
netstat -tupn | grep 8000
```

---

## Step 7: Scaling & Optimization

### 7.1 Increase Resources

If application needs more capacity:

```bash
# Update terraform.tfvars
# instance_type = "t2.small"  # Scale up
# db_instance_class = "db.t3.small"

# Apply changes
terraform plan -out=tfplan
terraform apply tfplan

# No downtime with multi-AZ RDS
```

### 7.2 Add More Application Workers

Edit systemd service:

```bash
sudo nano /etc/systemd/system/local-services-api.service

# Change: --workers 4  →  --workers 8
# Save and restart

sudo systemctl daemon-reload
sudo systemctl restart local-services-api
```

---

## Cleanup & Destruction

### To Remove All Infrastructure

```bash
cd terraform

# Review what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy

# Confirm by typing 'yes'
```

---

## Troubleshooting

### Issue: Cannot SSH into EC2

```bash
# Check security group allows port 22
aws ec2 describe-security-groups --group-ids sg-xxxxx

# Check key permissions
chmod 600 ~/.ssh/local-services
ls -la ~/.ssh/local-services
```

### Issue: API Returns 500 Error

```bash
# SSH to instance
ssh -i ~/.ssh/local-services ubuntu@YOUR_EC2_IP

# Check logs
sudo tail -50 /var/log/local-services/error.log

# Check database connection
pg_isready -h RDS_ENDPOINT

# Restart service
sudo systemctl restart local-services-api
```

### Issue: Database Connection Failed

```bash
# SSH to instance
ssh -i ~/.ssh/local-services ubuntu@YOUR_EC2_IP

# Test connection
psql -h RDS_ENDPOINT -U postgres -d local_services -c "SELECT 1"

# Check security group allows port 5432
aws ec2 describe-security-groups --group-ids sg-rds-xxxxx
```

### Issue: Application Won't Start

```bash
# Check service status
sudo systemctl status local-services-api

# Check logs
sudo journalctl -u local-services-api -n 100

# Manual start to see errors
cd /opt/local-services-app
source venv/bin/activate
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

---

## Next Steps

Phase 1 is complete! Now ready for:

- **Phase 2: CI/CD Pipeline** - GitHub Actions + automated deployments
- **Phase 3: Advanced Features** - Celery tasks, Redis caching
- **Phase 4: Kubernetes** - Multi-region scaling

---

## Cost Breakdown

| Service | Instance Type | Estimated Cost/Month |
|---------|---|---|
| EC2 | t2.micro | $0 (free tier) / $10.17 (non-free tier) |
| RDS | db.t3.micro (multi-AZ) | $14.22 |
| RDS Storage | 20GB gp3 | $1.84 |
| Data Transfer | < 1GB | ~$0.10 |
| **Total** | | **~$16-20/month** |

---

## Support

For issues or questions:
1. Check AWS documentation: https://docs.aws.amazon.com/
2. Review logs as shown in Troubleshooting
3. Check Terraform state: `terraform show`
4. Verify security groups and network configuration

---

**Last Updated:** April 3, 2026  
**Status:** Phase 1 Infrastructure Ready
