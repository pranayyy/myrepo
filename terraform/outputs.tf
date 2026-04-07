# Terraform Outputs - Important values to use after deployment

output "ec2_public_ip" {
  description = "Public IP address of EC2 instance"
  value       = aws_eip.api.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS name of EC2 instance"
  value       = aws_instance.api.public_dns
}

output "rds_endpoint" {
  description = "RDS database endpoint"
  value       = aws_db_instance.postgres.endpoint
  sensitive   = true
}

output "rds_address" {
  description = "RDS database address (hostname only)"
  value       = aws_db_instance.postgres.address
  sensitive   = true
}

output "rds_port" {
  description = "RDS database port"
  value       = aws_db_instance.postgres.port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.postgres.db_name
}

output "rds_username" {
  description = "RDS master username"
  value       = aws_db_instance.postgres.username
}

output "db_password_secret_arn" {
  description = "ARN of secret storing database password"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.api.id
}

output "security_group_ec2_id" {
  description = "EC2 security group ID"
  value       = aws_security_group.ec2.id
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "ssh_private_key" {
  description = "SSH private key for EC2 access"
  value       = tls_private_key.deployer.private_key_pem
  sensitive   = true
}

output "ssh_command" {
  description = "Command to SSH into the instance (save private key first)"
  value       = "The private key is available in the ssh_private_key output. Save it to a file and use: ssh -i <key_file> ubuntu@${aws_eip.api.public_ip}"
}

output "api_url" {
  description = "URL for the API"
  value       = "http://${aws_eip.api.public_ip}:8000"
}

output "api_docs_url" {
  description = "URL for API documentation"
  value       = "http://${aws_eip.api.public_ip}:8000/docs"
}
