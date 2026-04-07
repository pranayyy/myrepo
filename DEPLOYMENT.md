# Deployment Guide

## Overview

This document describes how to deploy Local Services API to development and production environments.

## CI/CD Pipeline

### GitHub Actions Workflow

The pipeline is configured in `.github/workflows/ci-cd.yml` and runs on every push to `main` or `develop` branches.

**Workflow Steps:**
1. **Test** - Run pytest suite against PostgreSQL (all branches)
2. **Build** - Build and push Docker image to GitHub Container Registry
3. **Deploy Dev** - Deploy to development when merging to `develop`
4. **Deploy Prod** - Deploy to production when merging to `main`

### Branch Strategy

```
main (production) → production environment  
develop (staging) → development environment
feature/* → pull requests triggering tests only
```

---

## Prerequisites

### Local Development
```bash
# Python 3.11+
python --version

# PostgreSQL
psql --version

# Docker (for containerized development)
docker --version
docker-compose --version

# AWS CLI
aws --version

# Terraform
terraform --version
```

### AWS Credentials
```bash
# Configure AWS credentials
aws configure

# Verify access
aws sts get-caller-identity
```

### GitHub Secrets (for CI/CD)
Required secrets in GitHub repository settings:
- `AWS_ACCESS_KEY_ID` - AWS access key
- `AWS_SECRET_ACCESS_KEY` - AWS secret key
- `SLACK_WEBHOOK` - (Optional) Slack notification webhook

---

## Development Environment

### Local Setup
```bash
# Clone repository
git clone https://github.com/pranayyy/myrepo.git
cd local-services-app

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Create development database
createdb local_services_dev

# Load environment variables
export $(cat .env.dev | xargs)

# Run migrations (if using Alembic)
alembic upgrade head

# Start application
uvicorn app.main:app --reload --port 8000
```

### Testing
```bash
# Run all tests
pytest tests/ -v

# Run with coverage
pytest tests/ --cov=app --cov-report=html

# Run specific test
pytest tests/test_api.py::TestAuthentication::test_sign_up_success -v
```

### Using Docker Compose
```bash
# Start all services
docker-compose -f docker-compose.yml up

# Run specific service
docker-compose up api

# View logs
docker-compose logs -f api

# Stop services
docker-compose down
```

---

## Staging/Development Deployment

### Deploy via GitHub (Recommended)

1. **Push to develop branch:**
   ```bash
   git checkout develop
   git push origin develop
   ```

2. **GitHub Actions automatically:**
   - Runs tests
   - Builds Docker image
   - Deploys to development AWS environment

3. **Access deployed API:**
   ```bash
   # Get URL from GitHub Actions output or Terraform state
   curl https://dev-api.region.compute.amazonaws.com:8000/health
   ```

### Manual Deployment

```bash
# Initialize Terraform
cd terraform
terraform init

# Plan deployment
terraform plan -var-file="dev.tfvars" -out=tfplan_dev

# Review plan output carefully
cat tfplan_dev

# Apply changes
terraform apply tfplan_dev

# Get outputs
terraform output
```

---

## Production Deployment

### Deployment Checklist

- [ ] All tests passing on main branch
- [ ] Code reviewed and approved
- [ ] Secrets configured in GitHub and AWS
- [ ] Database backup created
- [ ] Monitoring and alerts configured
- [ ] Incident response plan documented

### Deploy via GitHub (Recommended)

1. **Create release:**
   ```bash
   # Tag version
   git tag -a v1.0.0 -m "Release version 1.0.0"
   git push origin v1.0.0
   ```

2. **Merge to main:**
   ```bash
   git checkout main
   git pull origin develop
   git push origin main
   ```

3. **GitHub Actions automatically:**
   - Runs full test suite
   - Builds production Docker image
   - Deploys to production AWS
   - Sends Slack notification

### Manual Production Deployment

```bash
# Ensure you're on main branch
git checkout main
git pull origin main

# Review changes
git log --oneline -10

# Plan production deployment
cd terraform
terraform plan -var-file="prod.tfvars" -out=tfplan_prod

# CAREFULLY review the plan before applying
cat tfplan_prod | grep -E "(create|destroy|modify)"

# Apply (requires confirmation)
terraform apply tfplan_prod
```

### Post-Deployment Verification

```bash
# Check API health
curl https://prod-api.region.compute.amazonaws.com:8000/health

# Check logs
aws logs tail /aws/ec2/local-services-api --follow

# Run smoke tests
curl https://prod-api.region.compute.amazonaws.com:8000/docs

# Verify database
psql -h <rds-endpoint> -U postgres -d local_services -c "SELECT COUNT(*) FROM \"user\";"
```

---

## Environment Configuration

### Development (.env.dev)
```
ENVIRONMENT=development
DEBUG=true
LOG_LEVEL=DEBUG
DATABASE_URL=postgresql://localhost:5432/local_services_dev
SECRET_KEY=dev-secret-key
```

### Production (.env.prod.example)
- Never commit actual `.env.prod`
- Use AWS Secrets Manager instead
- Use GitHub Secrets for CI/CD
- Rotate keys regularly

### Loading Environment Variables
```bash
# Development
export $(cat .env.dev | xargs)

# Production (use AWS Secrets Manager)
aws secretsmanager get-secret-value --secret-id local-services/env --query SecretString --output text > /tmp/.env.prod
export $(cat /tmp/.env.prod | xargs)
```

---

## Rollback Procedures

### If deployment fails:

```bash
cd terraform

# View previous state
terraform state show

# Rollback to previous version
terraform destroy -target=aws_instance.api -auto-approve
terraform apply -var-file="prod.tfvars"

# Or manually:
# 1. Revert code to previous commit
git revert HEAD
git push origin main
# 2. GitHub Actions will redeploy previous version
```

---

## Monitoring & Alerts

### CloudWatch Dashboards
- CPU usage (EC2 & RDS)
- Memory (EC2)
- Database connections (RDS)
- Application errors
- API response time

### Logs
```bash
# View EC2 application logs
aws logs tail /aws/ec2/local-services-api --follow

# View RDS logs
aws logs tail /aws/rds/local-services-postgres --follow

# Get specific date logs
aws logs filter-log-events --log-group-name /aws/ec2/local-services-api --start-time $(date -d '1 hour ago' +%s)000
```

### Alerts
- CPU > 80%
- Memory > 85%
- Database connections > 80
- API error rate > 5%
- Failed deployments

---

## Useful Commands

```bash
# Show all Terraform outputs
terraform output

# Get specific output
terraform output ec2_public_ip

# Destroy entire stack (CAREFUL!)
terraform destroy -var-file="dev.tfvars"

# Refresh state
terraform refresh

# Show current state
terraform state list
terraform state show aws_instance.api
```

---

## Troubleshooting

### API not responding
```bash
# SSH into instance
ssh -i ~/.ssh/local-services ubuntu@<instance-ip>

# Check service status
sudo systemctl status local-services-api

# View logs
sudo tail -100 /var/log/local-services/app.log

# Restart service
sudo systemctl restart local-services-api
```

### Database connection issues
```bash
# Test RDS connectivity
psql -h <rds-endpoint> -U postgres -d local_services -c "SELECT 1;"

# Check security groups
aws ec2 describe-security-groups --group-ids sg-xxxx
```

### Terraform state conflicts
```bash
# Lock state file
terraform force-unlock <lock-id>

# Backup state
cp terraform/terraform.tfstate terraform/terraform.tfstate.backup

# Refresh state
terraform refresh
```

---

## Security Best Practices

1. **Never commit secrets** - Use environment variables or AWS Secrets Manager
2. **Use HTTPS** - Always use SSL/TLS in production
3. **Rotate keys** - Regularly rotate database passwords and API keys
4. **Restrict access** - Use security groups and IAM policies
5. **Enable MFA** - For AWS console and GitHub
6. **Monitor logs** - Regular review of application and infrastructure logs
7. **Backup data** - RDS automatic backups enabled in production

---

## Support

For issues or questions:
- GitHub Issues: https://github.com/pranayyy/myrepo/issues
- Documentation: See README.md and API_TESTING.md
- Logs: Check CloudWatch logs via AWS console or CLI
