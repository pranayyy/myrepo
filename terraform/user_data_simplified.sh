#!/bin/bash
# EC2 User Data Script - Minimal setup
# Only installs Docker and SSM agent. Deployment is handled by CI/CD.

exec > >(tee /var/log/user-data.log 2>&1)

echo "=========================================="
echo "Starting EC2 Instance Setup"
echo "=========================================="

# Update and install Docker + utilities
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io curl postgresql-client

# Start Docker
systemctl enable docker
systemctl start docker

# Create app directory
mkdir -p /opt/local-services-app

# Create .env file with database credentials
cat > /opt/local-services-app/.env << ENVFILE
DATABASE_URL=postgresql://${db_user}:${db_password}@${db_endpoint_host}:5432/${db_name}
SECRET_KEY=$(head -c 32 /dev/urandom | xxd -p | tr -d '\n')
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
ENVIRONMENT=production
ENVFILE
chmod 600 /opt/local-services-app/.env

# SSM agent is pre-installed on Ubuntu 22.04 AMIs, just ensure it's running
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service 2>/dev/null || true
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service 2>/dev/null || true

echo "Setup complete. Docker version:"
docker --version
echo "=========================================="

echo "=========================================="
echo "EC2 Instance Configuration Complete!"
echo "=========================================="
IP=$$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo "unknown")
echo "API available at: http://$IP:8000"
echo "API docs at: http://$IP:8000/docs"
echo "=========================================="
