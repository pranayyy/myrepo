# Phase 1 Infrastructure Deployment Checklist

Complete this checklist to ensure Phase 1 AWS deployment is successful.

## Pre-Deployment Setup

### AWS Account & Tools
- [ ] AWS account created and verified
- [ ] AWS CLI installed (`aws --version` shows 2.0+)
- [ ] AWS credentials configured (`aws configure`)
- [ ] Default region set to us-east-1
- [ ] Terraform installed (`terraform --version` shows 1.0+)
- [ ] SSH keys generated (`~/.ssh/local-services` exists)

### Repository & Code
- [ ] Local project cloned/updated to latest
- [ ] All Week 1 tests passing locally (`pytest tests/test_api.py -v`)
- [ ] Application runs locally (`uvicorn app.main:app --reload`)
- [ ] GitHub repository created (for EC2 to clone from)
- [ ] `.gitignore` includes `.env` and `terraform.tfvars`

### Terraform Configuration
- [ ] Created `terraform/terraform.tfvars` from example
- [ ] Set correct SSH public key path in tfvars
- [ ] AWS region confirmed (recommend us-east-1)
- [ ] Instance type set (t2.micro for free tier)
- [ ] Database storage size reviewed (20GB default)

---

## Deployment Phase

### Infrastructure Creation
- [ ] Ran `terraform init` in terraform directory
- [ ] Ran `terraform plan` and reviewed all resources
- [ ] Ran `terraform apply` successfully
- [ ] All outputs visible in terminal
- [ ] Saved outputs to file or clipboard:
  ```
  - EC2 Public IP
  - RDS Endpoint
  - SSH Command
  - API URL
  ```

### EC2 Instance Initialization
- [ ] Waited 3-5 minutes for user data script to complete
- [ ] SSH connection successful: `ssh -i ~/.ssh/local-services ubuntu@YOUR_IP`
- [ ] Checked user data logs: `tail /var/log/user-data.log`
- [ ] Service is running: `sudo systemctl status local-services-api`
- [ ] No errors in application logs:
  ```bash
  sudo tail /var/log/local-services/error.log
  ```

### Database Verification
- [ ] PostgreSQL database is accessible
- [ ] Can connect with psql:
  ```bash
  psql -h RDS_ENDPOINT -U postgres -d local_services -c "\dt"
  ```
- [ ] Database tables created (users, services, rating, etc.)
- [ ] No connection errors in logs

---

## Validation Phase

### API Health Checks
- [ ] Health endpoint responds:
  ```bash
  curl http://YOUR_EC2_IP:8000/health
  # Response: {"status":"healthy"}
  ```
- [ ] API documentation accessible:
  ```
  http://YOUR_EC2_IP:8000/docs
  ```
- [ ] Root endpoint returns version:
  ```bash
  curl http://YOUR_EC2_IP:8000/
  # Response includes version "1.0.0"
  ```

### API Functionality
- [ ] User registration works:
  ```bash
  curl -X POST http://YOUR_EC2_IP:8000/api/v1/auth/sign_up \
    -H "Content-Type: application/json" \
    -d '{"email":"test@example.com","username":"test","password":"Test1234!","full_name":"Test"}'
  # Response: 201 Created
  ```
- [ ] User sign-in returns JWT token
- [ ] Authentication required endpoints reject missing token (401)
- [ ] Service endpoints accessible with valid token

### Performance & Resources
- [ ] EC2 CPU usage reasonable (`htop` shows < 30%)
- [ ] Memory usage acceptable (`free -h` shows > 500MB available)
- [ ] Disk usage normal (`df -h` shows > 80% free)
- [ ] Response times < 200ms (check browser DevTools)

---

## Security Configuration

### Secrets & Environment
- [ ] Production `.env` file created on EC2
- [ ] SECRET_KEY is unique (generated with openssl)
- [ ] DEBUG mode is False
- [ ] Database password is strong (32+ characters)
- [ ] Firebase keys stored in Secrets Manager (if using)

### Network Security
- [ ] SSH security group restricted to your IP (recommended)
- [ ] RDS only accessible from EC2 security group
- [ ] HTTP redirects to HTTPS (if domain configured)
- [ ] SSL certificate installed (if using Let's Encrypt)

### Backups
- [ ] RDS backups configured (7-day retention)
- [ ] First backup available in RDS console
- [ ] Manual backup tested (pg_dump works)
- [ ] Backup file stored securely (not in Git)

---

## Production Configuration

### Domain & SSL
- [ ] Domain registrar configured (if applicable)
- [ ] DNS records pointing to Elastic IP
- [ ] SSL certificate obtained from Let's Encrypt
- [ ] Nginx configured with SSL
- [ ] Nginx configuration tested (`sudo nginx -t`)

### Monitoring & Logging
- [ ] CloudWatch Logs group exists
- [ ] Alarms configured for CPU and memory
- [ ] Application logs flowing to CloudWatch
- [ ] Alarm email notifications tested
- [ ] Health check script accessible at /health

### Documentation
- [ ] SSH command saved: `ssh -i ~/.ssh/local-services ubuntu@YOUR_IP`
- [ ] RDS endpoint saved: `local-services-postgres.xxxxx.rds.amazonaws.com`
- [ ] API URL documented: `http://YOUR_EC2_IP:8000`
- [ ] Emergency recovery procedure documented

---

## Final Verification

### Load Testing (Optional but Recommended)
- [ ] API handles 100 concurrent requests
- [ ] Response times consistent under load
- [ ] Memory doesn't leak over time
- [ ] Database connection pool functioning

### Integration Testing
- [ ] All 20 unit tests pass when run against deployed API
- [ ] Cross-origin requests work (CORS enabled)
- [ ] Error responses have proper HTTP status codes
- [ ] Pagination works on list endpoints

### Rollback Testing (Safety Check)
- [ ] Can manually stop service: `sudo systemctl stop local-services-api`
- [ ] Can manually start service: `sudo systemctl start local-services-api`
- [ ] Service auto-restarts on failure
- [ ] Application recovers after reboot

---

## Post-Deployment Tasks

### Immediate (Day 1)
- [ ] Notify team of production API URL
- [ ] Update documentation with new endpoints
- [ ] Setup CI/CD pipeline (Phase 2 planning)
- [ ] Create runbook for common issues
- [ ] Schedule Phase 2 infrastructure work

### Short-term (Week 1)
- [ ] Monitor logs for errors
- [ ] Verify backups are working
- [ ] Plan scaling strategy if needed
- [ ] Gather initial performance metrics
- [ ] Setup log aggregation

### Medium-term (Week 2-3)
- [ ] Implement CI/CD pipeline (Phase 2)
- [ ] Add monitoring dashboards
- [ ] Performance optimization
- [ ] Security hardening
- [ ] Capacity planning

---

## Troubleshooting Reference

### Cannot SSH
```bash
# Check key permissions
chmod 600 ~/.ssh/local-services

# Verify security group
aws ec2 describe-security-groups --group-ids sg-xxxxx

# Check network connectivity
ping YOUR_EC2_IP
```

### API Not Responding
```bash
# SSH to instance
ssh -i ~/.ssh/local-services ubuntu@YOUR_EC2_IP

# Check service status
sudo systemctl status local-services-api

# View recent logs
sudo tail -100 /var/log/local-services/error.log

# Manually restart
sudo systemctl restart local-services-api
```

### Database Connection Failed
```bash
# Test RDS connectivity
psql -h RDS_ENDPOINT -U postgres -d local_services -c "SELECT 1"

# Check EC2 can reach RDS
telnet RDS_ENDPOINT 5432

# Verify security groups
aws ec2 describe-security-groups --group-ids sg-xxxxx
```

### Out of Memory
```bash
# SSH to instance
ssh -i ~/.ssh/local-services ubuntu@YOUR_EC2_IP

# Check memory usage
free -h

# Check application processes
ps aux | grep gunicorn

# Increase instance type in terraform
# instance_type = "t2.small"
```

---

## Sign-off

- [ ] All checklist items completed
- [ ] Deployment manager verified functionality
- [ ] Team notified of production ready status
- [ ] Documentation updated
- [ ] Handoff to Phase 2 scheduled

**Deployment Date:** _______________  
**Deployed By:** _______________  
**Verified By:** _______________  
**Notes:** _______________________________________________

---

**Next Phase:** Phase 2 - CI/CD Pipeline Implementation
