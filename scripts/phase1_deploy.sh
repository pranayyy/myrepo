#!/bin/bash
# Phase 1 Quick Start Script
# Automates the AWS infrastructure deployment process

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Phase 1: AWS Infrastructure Deployment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}[1/5] Checking Prerequisites...${NC}"

check_command() {
  if ! command -v $1 &> /dev/null; then
    echo -e "${RED}✗ $2 not found. Please install it first.${NC}"
    echo -e "${RED}  Install: $3${NC}"
    exit 1
  fi
  echo -e "${GREEN}✓ $2 found$(NC}"
}

check_command "terraform" "Terraform" "https://www.terraform.io/downloads"
check_command "aws" "AWS CLI" "https://aws.amazon.com/cli/"
check_command "ssh-keygen" "SSH" "Built-in"

# Verify AWS credentials
if ! aws sts get-caller-identity &>/dev/null; then
  echo -e "${RED}✗ AWS credentials not configured. Run: aws configure${NC}"
  exit 1
fi
echo -e "${GREEN}✓ AWS credentials configured${NC}"
echo ""

# Setup SSH keys
echo -e "${YELLOW}[2/5] Setting Up SSH Keys...${NC}"

SSH_KEY_PATH="$HOME/.ssh/local-services"
if [ ! -f "$SSH_KEY_PATH" ]; then
  echo -e "${YELLOW}  Generating SSH key pair...${NC}"
  ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N ""
  chmod 600 "$SSH_KEY_PATH"
  echo -e "${GREEN}✓ SSH key generated at $SSH_KEY_PATH${NC}"
else
  echo -e "${GREEN}✓ SSH key already exists${NC}"
fi
echo ""

# Configure Terraform
echo -e "${YELLOW}[3/5] Configuring Terraform...${NC}"

cd terraform

if [ ! -f "terraform.tfvars" ]; then
  if [ -f "terraform.tfvars.example" ]; then
    cp terraform.tfvars.example terraform.tfvars
    echo -e "${YELLOW}  Please edit terraform/terraform.tfvars with your configuration:${NC}"
    echo -e "${YELLOW}  - aws_region${NC}"
    echo -e "${YELLOW}  - instance_type${NC}"
    echo -e "${YELLOW}  - db_instance_class${NC}"
    echo -e "${YELLOW}  - ssh_public_key_path (set to: $SSH_KEY_PATH.pub)${NC}"
    echo -e "${YELLOW}  - environment${NC}"
    read -p "Press Enter once you've updated terraform.tfvars..."
  fi
fi

echo -e "${GREEN}✓ Terraform configuration ready${NC}"
echo ""

# Initialize Terraform
echo -e "${YELLOW}[4/5] Initializing Terraform...${NC}"

terraform init
echo -e "${GREEN}✓ Terraform initialized${NC}"
echo ""

# Plan deployment
echo -e "${YELLOW}[5/5] Planning Infrastructure Deployment...${NC}"

terraform plan -out=tfplan

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Deployment Plan Generated${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Review the plan above and proceed with:${NC}"
echo -e "${GREEN}  cd terraform${NC}"
echo -e "${GREEN}  terraform apply tfplan${NC}"
echo ""
echo -e "${YELLOW}This will create:${NC}"
echo -e "  • 1 VPC with public/private subnets"
echo -e "  • 1 EC2 instance (t2.micro)"
echo -e "  • 1 RDS PostgreSQL database"
echo -e "  • Security groups and IAM roles"
echo -e "  • CloudWatch monitoring"
echo ""
echo -e "${YELLOW}Estimated cost: \$16-20/month${NC}"
echo ""
echo -e "${YELLOW}After deployment, save these outputs:${NC}"
echo -e "  • EC2 Public IP"
echo -e "  • RDS Endpoint"
echo -e "  • SSH Command"
echo -e "  • API URL"
echo ""
echo -e "${BLUE}For detailed instructions, see: PHASE1_DEPLOYMENT.md${NC}"
