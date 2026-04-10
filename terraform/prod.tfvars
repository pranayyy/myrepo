# Production Environment Configuration
# Deploy to: production
# InstanceType: t3.micro (free tier eligible)
# Database: PostgreSQL t3.micro (free tier eligible, no Multi-AZ)

aws_region            = "us-east-1"
instance_type         = "t3.micro"
db_instance_class     = "db.t3.micro"
db_allocated_storage  = 20
environment           = "production"
docker_image          = "ghcr.io/pranayyy/myrepo:main"

tags = {
  Environment = "production"
  ManagedBy   = "Terraform"
  Project     = "LocalServices"
}
