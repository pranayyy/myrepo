# Production Environment Configuration
# Deploy to: production
# InstanceType: t3.small (better performance)
# Database: PostgreSQL t3.small with Multi-AZ

aws_region            = "us-east-1"
instance_type         = "t3.small"
db_instance_class     = "db.t3.small"
db_allocated_storage  = 50
environment           = "production"
ssh_public_key_path   = "~/.ssh/local-services.pub"
github_repo_url       = "https://github.com/pranayyy/myrepo.git"

tags = {
  Environment = "production"
  ManagedBy   = "Terraform"
  Project     = "LocalServices"
  Backup      = "daily"
}
