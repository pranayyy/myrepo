"""
Setup script to initialize the project and create necessary files.
"""

import os
import sys

def setup_project():
    """Setup project structure and environment."""
    print("Setting up Local Services Application...\n")
    
    # Create .env file
    env_content = """# Database
SQLITE_URL=sqlite:///./test.db
POSTGRES_URL=

# JWT
SECRET_KEY=your-super-secret-key-change-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# AWS
AWS_REGION=us-east-1
S3_BUCKET=local-services-reports

# Redis
REDIS_URL=redis://localhost:6379/0

# Celery
CELERY_BROKER_URL=redis://localhost:6379/0
CELERY_RESULT_BACKEND=redis://localhost:6379/0

# MongoDB
MONGODB_URL=mongodb://localhost:27017
MONGODB_DB=local_services
"""
    
    with open(".env", "w") as f:
        f.write(env_content)
    print("✓ Created .env file")
    
    # Create directories if they don't exist
    directories = [
        "app/api",
        "app/models",
        "app/schemas",
        "app/core",
        "tests",
        "scripts"
    ]
    
    for directory in directories:
        os.makedirs(directory, exist_ok=True)
    print(f"✓ Created project directories")
    
    print("\n✓ Project setup completed!")
    print("\nNext steps:")
    print("1. Run: pip install -r requirements.txt")
    print("2. Run: python scripts/populate_db.py")
    print("3. Run: python -m uvicorn app.main:app --reload")

if __name__ == "__main__":
    setup_project()
