# Production Environment Configuration
# Deploy to: production
# InstanceType: t2.micro (free tier eligible)
# Database: PostgreSQL t3.micro (free tier eligible, no Multi-AZ)

aws_region            = "us-east-1"
instance_type         = "t2.micro"
db_instance_class     = "db.t3.micro"
db_allocated_storage  = 20
environment           = "production"
github_repo_url       = "https://github.com/pranayyy/myrepo.git"

tags = {
  Environment = "production"
  ManagedBy   = "Terraform"
  Project     = "LocalServices"
}
