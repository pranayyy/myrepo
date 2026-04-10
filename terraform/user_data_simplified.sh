#!/bin/bash
# EC2 User Data Script - Docker-based deployment
# Pulls and runs the application Docker image from GHCR

set -e

# Log all output
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "=========================================="
echo "Starting EC2 Instance Configuration (Docker)"
echo "=========================================="

# Update system packages
echo "[1] Updating system packages..."
apt-get update
apt-get upgrade -y

# Install required software
echo "[2] Installing Docker and utilities..."
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    postgresql-client

# Add Docker's official GPG key and repository
echo "[3] Setting up Docker repository..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker
echo "[4] Starting Docker..."
systemctl start docker
systemctl enable docker

# Create app directory for config
mkdir -p /opt/local-services-app
cd /opt/local-services-app

# Create .env file for the container
echo "[5] Creating environment configuration..."
cat > .env << ENVFILE
DATABASE_URL=postgresql://${db_user}:${db_password}@${db_endpoint_host}:5432/${db_name}
SECRET_KEY=$$(openssl rand -hex 32)
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
ENVIRONMENT=production
DEBUG=false
ENVFILE

chmod 600 .env

# Create the deploy script (used by CI/CD to redeploy)
echo "[6] Creating deploy script..."
cat > /opt/local-services-app/deploy.sh << 'DEPLOYSCRIPT'
#!/bin/bash
set -e
IMAGE="$${1:-ghcr.io/pranayyy/myrepo:main}"
REGION="$${2:-us-east-1}"
echo "Deploying image: $IMAGE"
docker pull "$IMAGE"
docker stop local-services-api 2>/dev/null || true
docker rm local-services-api 2>/dev/null || true
docker run -d \
  --name local-services-api \
  --restart always \
  --network host \
  --log-driver=awslogs \
  --log-opt awslogs-region="$REGION" \
  --log-opt awslogs-group=/local-services/api \
  --log-opt awslogs-stream=api-container \
  --log-opt awslogs-create-group=true \
  --env-file /opt/local-services-app/.env \
  "$IMAGE"
echo "Container started. Waiting for health check..."
for i in {1..30}; do
  if curl -sf http://localhost:8000/health > /dev/null 2>&1; then
    echo "API is healthy!"
    exit 0
  fi
  echo "Waiting... ($i/30)"
  sleep 2
done
echo "Health check failed!"
docker logs local-services-api --tail 50
exit 1
DEPLOYSCRIPT
chmod +x /opt/local-services-app/deploy.sh

# Pull and run the Docker image
echo "[7] Pulling and starting Docker container..."
docker pull ${docker_image}

docker run -d \
  --name local-services-api \
  --restart always \
  --network host \
  --log-driver=awslogs \
  --log-opt awslogs-region=${aws_region} \
  --log-opt awslogs-group=/local-services/api \
  --log-opt awslogs-stream=api-container \
  --log-opt awslogs-create-group=true \
  --env-file /opt/local-services-app/.env \
  ${docker_image}

# Wait and test health endpoint
echo "[8] Testing API health endpoint..."
for i in {1..30}; do
    if curl -s http://localhost:8000/health > /dev/null 2>&1; then
        echo "API is healthy!"
        curl -s http://localhost:8000/health
        break
    else
        echo "Waiting for API to start... ($i/30)"
        sleep 2
    fi
done

# Print container logs if health check didn't pass
if ! curl -s http://localhost:8000/health > /dev/null 2>&1; then
    echo "Container may have failed to start. Dumping logs:"
    docker logs local-services-api --tail 100 2>&1 || true
fi

# Also send user_data log to CloudWatch
aws logs create-log-group --log-group-name /local-services/user-data --region ${aws_region} 2>/dev/null || true
aws logs create-log-stream --log-group-name /local-services/user-data --log-stream-name "instance-init" --region ${aws_region} 2>/dev/null || true

# Install SSM agent for CI/CD remote commands
echo "[9] Installing AWS SSM Agent..."
snap install amazon-ssm-agent --classic || apt-get install -y amazon-ssm-agent || true
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service || systemctl enable amazon-ssm-agent || true
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service || systemctl start amazon-ssm-agent || true

echo "=========================================="
echo "EC2 Instance Configuration Complete!"
echo "=========================================="
IP=$$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo "unknown")
echo "API available at: http://$IP:8000"
echo "API docs at: http://$IP:8000/docs"
echo "=========================================="
