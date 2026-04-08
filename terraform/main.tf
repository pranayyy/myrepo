# Phase 1: AWS Infrastructure as Code
# Provisions: EC2 + RDS PostgreSQL + Security Groups + IAM

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment to store state in S3 (recommended for production)
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "local-services/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region
}

# ==========================================
# VPC & Networking
# ==========================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "local-services-vpc"
  }
}

resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "local-services-public-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "local-services-private-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "local-services-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "local-services-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ==========================================
# Security Groups
# ==========================================

resource "aws_security_group" "ec2" {
  name        = "local-services-ec2-sg"
  description = "Security group for EC2 instance"
  vpc_id      = aws_vpc.main.id

  # SSH from anywhere (restrict to your IP in production)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # CHANGE: Restrict to your IP
  }

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # FastAPI on 8000
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound: All traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "local-services-ec2-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "local-services-rds-sg"
  description = "Security group for RDS database"
  vpc_id      = aws_vpc.main.id

  # PostgreSQL from EC2
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  # Outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "local-services-rds-sg"
  }
}

# ==========================================
# EC2 Instance
# ==========================================

# Generate SSH key pair for EC2 access
resource "tls_private_key" "deployer" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name_prefix = "local-services-deployer-${var.environment}-"
  public_key      = tls_private_key.deployer.public_key_openssh
}

resource "aws_instance" "api" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.deployer.key_name
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name

  # User data script to initialize instance
  user_data = base64encode(templatefile("${path.module}/user_data_simplified.sh", {
    db_endpoint_host = split(":", aws_db_instance.postgres.endpoint)[0]
    db_name          = aws_db_instance.postgres.db_name
    db_user          = aws_db_instance.postgres.username
    db_password      = random_password.db_password.result
    github_repo_url  = var.github_repo_url
  }))

  tags = {
    Name = "local-services-api-server"
  }

  monitoring = true
}

resource "aws_eip" "api" {
  instance = aws_instance.api.id
  domain   = "vpc"

  tags = {
    Name = "local-services-api-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

# ==========================================
# RDS PostgreSQL Database
# ==========================================

resource "aws_db_subnet_group" "main" {
  name_prefix = "local-services-db-subnet-${var.environment}-"
  subnet_ids  = aws_subnet.private[*].id

  tags = {
    Name = "local-services-db-subnet-group"
  }
}

resource "random_password" "db_password" {
  length  = 20
  special = false
}

resource "aws_secretsmanager_secret" "db_password" {
  name_prefix                    = "local-services-db-password-${var.environment}-"
  recovery_window_in_days        = 0
  force_overwrite_replica_secret = true

  tags = {
    Name = "local-services-db-password"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}

resource "aws_db_instance" "postgres" {
  identifier             = "local-services-postgres-${var.environment}"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  storage_type           = "gp2"
  db_name                = "local_services"
  username               = "postgres"
  password               = random_password.db_password.result
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # High availability (free tier: no multi-AZ)
  multi_az            = false
  publicly_accessible = false

  # Backups and maintenance (free tier: retention=1, no multi-AZ)
  backup_retention_period = 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"
  copy_tags_to_snapshot   = true

  # No enhanced monitoring for free tier
  monitoring_interval             = 0
  enabled_cloudwatch_logs_exports = []

  # Skip final snapshot for development
  skip_final_snapshot       = true
  final_snapshot_identifier = "local-services-postgres-final-snapshot-${var.environment}-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  tags = {
    Name = "local-services-postgres"
  }
}

# ==========================================
# IAM Roles & Policies
# ==========================================

resource "aws_iam_role" "ec2_role" {
  name_prefix = "local-services-ec2-role-${var.environment}-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name_prefix = "local-services-ec2-profile-${var.environment}-"
  role        = aws_iam_role.ec2_role.name
}

resource "aws_iam_role_policy" "ec2_policy" {
  name_prefix = "local-services-ec2-policy-${var.environment}-"
  role        = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.db_password.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "rds_monitoring" {
  name_prefix = "ls-rds-monitor-${var.environment}-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ==========================================
# CloudWatch Alarms
# ==========================================

resource "aws_cloudwatch_metric_alarm" "ec2_cpu" {
  alarm_name          = "local-services-ec2-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alert when EC2 CPU exceeds 80%"
  alarm_actions       = [] # Add SNS topic ARN here

  dimensions = {
    InstanceId = aws_instance.api.id
  }
}

resource "aws_cloudwatch_metric_alarm" "db_cpu" {
  alarm_name          = "local-services-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alert when RDS CPU exceeds 80%"
  alarm_actions       = [] # Add SNS topic ARN here

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.identifier
  }
}

# ==========================================
# Data Sources
# ==========================================

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
