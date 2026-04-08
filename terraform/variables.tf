# Terraform Variables - Phase 1 Infrastructure

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Initial database storage in GB"
  type        = number
  default     = 20
}

variable "ssh_public_key_path" {
  description = "SSH public key path (kept for compatibility with tfvars)"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}

variable "github_repo_url" {
  description = "GitHub repository URL for application code"
  type        = string
  default     = "https://github.com/pranayyy/myrepo.git"
}
