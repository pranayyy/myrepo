#!/bin/bash
# This script sets up the S3 backend for Terraform state management
# Run this once manually before CI/CD deployments

echo "Creating S3 bucket for Terraform state..."
aws s3api create-bucket \
  --bucket local-services-terraform-state \
  --region us-east-1 \
  --error-on-existent

echo "Enabling versioning on S3 bucket..."
aws s3api put-bucket-versioning \
  --bucket local-services-terraform-state \
  --versioning-configuration Status=Enabled

echo "Enabling encryption on S3 bucket..."
aws s3api put-bucket-encryption \
  --bucket local-services-terraform-state \
  --sse-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

echo "Creating DynamoDB table for state locking..."
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1 \
  --error-on-existing 2>/dev/null || echo "DynamoDB table already exists"

echo "Backend setup complete!"
echo "Next steps:"
echo "1. Run 'terraform init' to migrate state to S3"
echo "2. Confirm migration when prompted"
