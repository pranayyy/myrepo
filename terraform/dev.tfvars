# Development Environment Configuration
# Deploy to: development
# InstanceType: t3.micro
# Database: PostgreSQL t3.micro

aws_region            = "us-east-1"
instance_type         = "t3.micro"
db_instance_class     = "db.t3.micro"
db_allocated_storage  = 10
environment           = "development"
github_repo_url       = "https://github.com/pranayyy/myrepo.git"

tags = {
  Environment = "development"
  ManagedBy   = "Terraform"
  Project     = "LocalServices"
}
