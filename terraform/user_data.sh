#!/bin/bash
# EC2 User Data Script - Phase 1 Infrastructure Setup
# This script runs on EC2 instance startup to configure the application

set -e

# Log all output
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "=========================================="
echo "Starting EC2 Instance Configuration"
echo "=========================================="

# Update system packages
echo "[1] Updating system packages..."
apt-get update
apt-get upgrade -y

# Install required software
echo "[2] Installing required software..."
apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    python3-pip \
    git \
    curl \
    wget \
    htop \
    vim \
    build-essential \
    libssl-dev \
    libffi-dev \
    postgresql-client

# Create application user
echo "[3] Creating application user..."
useradd -m -s /bin/bash appuser || echo "appuser already exists"

# Create application directory
echo "[4] Setting up application directory..."
mkdir -p /opt/local-services-app
chown -R appuser:appuser /opt/local-services-app

# Clone complete application from GitHub
echo "[5] Cloning complete application from GitHub..."
cd /opt/local-services-app
sudo -u appuser git clone ${github_repo_url} . || echo "Repository clone issue, continuing..."

# Ensure directory ownership
chown -R appuser:appuser /opt/local-services-app

# Create Python virtual environment
echo "[6] Setting up Python virtual environment..."
python3.11 -m venv /opt/local-services-app/venv
source /opt/local-services-app/venv/bin/activate

# Upgrade pip
pip install --upgrade pip setuptools wheel

# Install Python dependencies
echo "[7] Installing Python dependencies..."
pip install -r /opt/local-services-app/requirements.txt
pip install gunicorn uvicorn

# Configure environment variables
echo "[8] Configuring environment variables..."
cat > /opt/local-services-app/.env << EOF
# Database
POSTGRES_HOST="${db_endpoint_host}"
POSTGRES_PORT="5432"
POSTGRES_DB="${db_name}"
POSTGRES_USER="${db_user}"
POSTGRES_PASSWORD="${db_password}"
DATABASE_URL="postgresql://${db_user}:${db_password}@${db_endpoint_host}:5432/${db_name}"

# JWT
SECRET_KEY="$(openssl rand -hex 32)"
ALGORITHM="HS256"
ACCESS_TOKEN_EXPIRE_MINUTES="30"

# Environment
ENVIRONMENT="production"
DEBUG="false"

# API
API_HOST="0.0.0.0"
API_PORT="8000"

# Redis (for future use)
REDIS_URL="redis://localhost:6379/0"

# MongoDB (for future use)
MONGODB_URL="mongodb://localhost:27017"
MONGODB_DB="local_services"

# AWS
AWS_REGION="us-east-1"
S3_BUCKET="local-services-reports"
EOF

chown appuser:appuser /opt/local-services-app/.env
chmod 600 /opt/local-services-app/.env

# Run database migrations (or skip for minimal deployment)
echo "[9] Skipping database migrations for minimal deployment..."
# In production, add Alembic migrations here
# alembic upgrade head

# Create systemd service
echo "[10] Creating systemd service..."
cat > /etc/systemd/system/local-services-api.service << 'SYSTEMD_EOF'
[Unit]
Description=Local Services API
After=network.target

[Service]
Type=notify
User=appuser
WorkingDirectory=/opt/local-services-app
Environment="PATH=/opt/local-services-app/venv/bin"
EnvironmentFile=/opt/local-services-app/.env
ExecStart=/opt/local-services-app/venv/bin/gunicorn \
    --workers 4 \
    --worker-class uvicorn.workers.UvicornWorker \
    --bind 0.0.0.0:8000 \
    --access-logfile /var/log/local-services/access.log \
    --error-logfile /var/log/local-services/error.log \
    app.main:app

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF

# Create log directory
mkdir -p /var/log/local-services
chown appuser:appuser /var/log/local-services

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable local-services-api.service
systemctl start local-services-api.service

# Wait for service to start
sleep 5

# Check service status
echo "[11] Checking service status..."
systemctl status local-services-api.service

# Test API health
echo "[12] Testing API health..."
for i in {1..30}; do
    if curl -s http://localhost:8000/health > /dev/null; then
        echo "✓ API is healthy!"
        break
    fi
    echo "Waiting for API to start... ($i/30)"
    sleep 2
done

# Configure CloudWatch agent (optional for enhanced monitoring)
echo "[13] Installing CloudWatch agent..."
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb || echo "CloudWatch agent installation skipped"

# Setup log rotation
echo "[14] Setting up log rotation..."
cat > /etc/logrotate.d/local-services << 'LOGROTATE_EOF'
/var/log/local-services/*.log {
    daily
    rotate 7
    compress
    delaycompress
    notifempty
    create 0640 appuser appuser
    dateext
    dateformat -%Y%m%d
}
LOGROTATE_EOF

echo "=========================================="
echo "EC2 Instance Configuration Complete!"
echo "=========================================="
echo "API available at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8000"
echo "API docs at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8000/docs"
echo "=========================================="
