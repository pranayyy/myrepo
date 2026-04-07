# Development Environment Configuration
# Deploy to: development
# InstanceType: t2.micro
# Database: PostgreSQL t2.micro

aws_region            = "us-east-1"
instance_type         = "t2.micro"
db_instance_class     = "db.t2.micro"
db_allocated_storage  = 10
environment           = "development"
ssh_public_key_path   = "~/.ssh/local-services.pub"
github_repo_url       = "https://github.com/pranayyy/myrepo.git"

tags = {
  Environment = "development"
  ManagedBy   = "Terraform"
  Project     = "LocalServices"
}
