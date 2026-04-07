# Terraform Variables File - Phase 1 Infrastructure Deployment
# Local Services API on AWS

# AWS Region
aws_region = "us-east-1"

# EC2 Instance Type (t3.micro = $10/month, works in this region)
instance_type = "t3.micro"

# RDS Database Instance Type (db.t3.micro = $14/month with multi-AZ)
db_instance_class = "db.t3.micro"

# Initial Database Storage (GB)
db_allocated_storage = 20

# SSH Public Key Path (where we generated keys)
ssh_public_key_path = "~/.ssh/local-services.pub"

# Environment Name
environment = "development"

# GitHub Repository URL
github_repo_url = "https://github.com/pranayyy/myrepo.git"
