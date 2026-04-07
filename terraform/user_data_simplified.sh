#!/bin/bash
# EC2 User Data Script - Simplified self-contained version
# This script sets up the FastAPI application without depending on external Git clone

set -e

# Log all output
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "=========================================="
echo "Starting EC2 Instance Configuration (Simplified)"
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
    postgresql-client

# Create application user and directory
echo "[3] Creating application user and directory..."
useradd -m -s /bin/bash appuser || echo "appuser already exists"
mkdir -p /opt/local-services-app
chown -R appuser:appuser /opt/local-services-app
cd /opt/local-services-app

# Create Python virtual environment
echo "[4] Setting up Python virtual environment..."
python3.11 -m venv venv
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip setuptools wheel

# Create requirements.txt with all dependencies
echo "[5] Creating requirements.txt..."
cat > requirements.txt << 'REQFILE'
fastapi==0.104.1
uvicorn==0.24.0
sqlalchemy==2.0.23
pydantic==2.5.0
psycopg2-binary==2.9.9
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
bcrypt==4.1.1
gunicorn==21.2.0
REQFILE

# Install Python dependencies
echo "[6] Installing Python dependencies..."
pip install -r requirements.txt
pip install gunicorn uvicorn

# Create minimal app directory structure
echo "[7] Creating application structure..."
mkdir -p app/api app/core app/models app/schemas
touch app/__init__.py app/api/__init__.py app/core/__init__.py app/models/__init__.py app/schemas/__init__.py

# Create core configuration files
echo "[8] Creating application files..."

# Create database.py
cat > app/core/database.py << 'DBFILE'
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
import os

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:postgres@localhost:5432/local_services"
)

engine = create_engine(DATABASE_URL, echo=False)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
DBFILE

# Create security.py
cat > app/core/security.py << 'SECFILE'
from datetime import datetime, timedelta
from jose import JWTError, jwt
from passlib.context import CryptContext
import os

SECRET_KEY = os.getenv("SECRET_KEY", "development-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def create_access_token(data: dict, expires_delta: timedelta = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def decode_token(token: str):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        return None
SECFILE

# Create minimal models.py
cat > app/models/database_models.py << 'MODELSFILE'
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Table, Boolean
from sqlalchemy.orm import relationship
from datetime import datetime as dt
from app.core.database import Base

association_table = Table(
    'service_tag',
    Base.metadata,
    Column('service_id', Integer, ForeignKey('service.id')),
    Column('tag_id', Integer, ForeignKey('tag.id'))
)

class User(Base):
    __tablename__ = "user"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    username = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    full_name = Column(String)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=dt.utcnow)

class Service(Base):
    __tablename__ = "service"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    description = Column(String)
    phone = Column(String)
    latitude = Column(Float)
    longitude = Column(Float)
    created_by_id = Column(Integer, ForeignKey('user.id'))
    average_rating = Column(Float, default=0.0)
    created_at = Column(DateTime, default=dt.utcnow)

class Tag(Base):
    __tablename__ = "tag"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True)
    description = Column(String)

class Rating(Base):
    __tablename__ = "rating"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey('user.id'))
    service_id = Column(Integer, ForeignKey('service.id'))
    rating = Column(Integer)
    created_at = Column(DateTime, default=dt.utcnow)
MODELSFILE

# Create main.py with minimal but functional API
cat > app/main.py << 'MAINFILE'
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from app.core.database import Base, engine, get_db
from datetime import timedelta

# Create tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Local Services API",
    description="A crowdsourced solution for discovering local services",
    version="1.0.0"
)

# Setup CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
def health_check():
    return {"status": "healthy", "message": "API is running on EC2"}

@app.get("/")
def root():
    return {
        "message": "Local Services API",
        "docs": "/docs",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "docs": "/docs",
            "redoc": "/redoc",
            "openapi": "/openapi.json"
        }
    }

@app.get("/api/v1/test")
def test_endpoint():
    return {"message": "API test endpoint works!"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
MAINFILE

# Set permissions
chown -R appuser:appuser /opt/local-services-app
chmod +x venv/bin/activate

# Create .env file
echo "[9] Creating environment configuration..."
cat > .env << ENVFILE
DATABASE_URL="postgresql://${db_user}:${db_password}@${db_endpoint_host}:5432/${db_name}"
SECRET_KEY="$(openssl rand -hex 32)"
ALGORITHM="HS256"
ACCESS_TOKEN_EXPIRE_MINUTES="30"
ENVIRONMENT="production"
DEBUG="false"
API_HOST="0.0.0.0"
API_PORT="8000"
ENVFILE

chmod 600 .env

# Create systemd service
echo "[10] Creating systemd service..."
cat > /etc/systemd/system/local-services-api.service << 'SERVICEEOF'
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
    --workers 2 \
    --worker-class uvicorn.workers.UvicornWorker \
    --bind 0.0.0.0:8000 \
    --timeout 120 \
    --access-logfile /var/log/local-services/access.log \
    --error-logfile /var/log/local-services/error.log \
    app.main:app

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Create log directory
mkdir -p /var/log/local-services
chown appuser:appuser /var/log/local-services

# Reload systemd and start service
echo "[11] Starting application service..."
systemctl daemon-reload
systemctl enable local-services-api.service
systemctl start local-services-api.service

# Wait for service to start
sleep 10

# Check service status
systemctl status local-services-api.service || echo "Service status check failed"

# Test health endpoint
echo "[12] Testing API health endpoint..."
for i in {1..30}; do
    if curl -s http://localhost:8000/health > /dev/null 2>&1; then
        echo "✓ API is healthy!"
        curl -s http://localhost:8000/health
        break
    else
        echo "Waiting for API to start... ($i/30)"
        sleep 2
    fi
done

echo "=========================================="
echo "EC2 Instance Configuration Complete!"
echo "=========================================="
IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "API available at: http://$IP:8000"
echo "API docs at: http://$IP:8000/docs"
echo "=========================================="
