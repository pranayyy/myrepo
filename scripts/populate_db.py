"""
Week 1 Task: User Population Script
This script populates the database with sample users having encrypted passwords.
SQLAlchemy models are used with SQLite database.
"""

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.core.database import Base
from app.core.security import hash_password
from app.models.database_models import User, Tag
from app.core.config import settings

# Create engine
engine = create_engine(settings.sqlite_url, connect_args={"check_same_thread": False})

# Create all tables
Base.metadata.create_all(bind=engine)

# Create session
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
db = SessionLocal()

def populate_users():
    """Populate database with sample users."""
    try:
        # Check if users already exist
        if db.query(User).first():
            print("Users already exist in database. Skipping population.")
            return
        
        # Sample users
        sample_users = [
            {
                "email": "john@example.com",
                "username": "john_doe",
                "full_name": "John Doe",
                "password": "password123"
            },
            {
                "email": "jane@example.com",
                "username": "jane_smith",
                "full_name": "Jane Smith",
                "password": "password456"
            },
            {
                "email": "bob@example.com",
                "username": "bob_johnson",
                "full_name": "Bob Johnson",
                "password": "password789"
            },
            {
                "email": "alice@example.com",
                "username": "alice_williams",
                "full_name": "Alice Williams",
                "password": "password321"
            }
        ]
        
        # Create users
        for user_data in sample_users:
            user = User(
                email=user_data["email"],
                username=user_data["username"],
                full_name=user_data["full_name"],
                hashed_password=hash_password(user_data["password"])
            )
            db.add(user)
            print(f"✓ Created user: {user_data['username']}")
        
        db.commit()
        print("\n✓ All users created successfully!")
        
    except Exception as e:
        db.rollback()
        print(f"✗ Error creating users: {str(e)}")
    finally:
        db.close()

def populate_tags():
    """Populate database with sample tags."""
    try:
        # Check if tags already exist
        if db.query(Tag).first():
            print("Tags already exist in database. Skipping population.")
            return
        
        # Sample tags
        sample_tags = [
            {"name": "mechanic", "description": "Vehicle repair and maintenance"},
            {"name": "plumber", "description": "Plumbing services"},
            {"name": "electrician", "description": "Electrical services"},
            {"name": "restaurant", "description": "Food and dining"},
            {"name": "grocery", "description": "Grocery store"},
            {"name": "pharmacy", "description": "Pharmacy services"},
            {"name": "salon", "description": "Hair and beauty salon"},
            {"name": "laundry", "description": "Laundry services"},
            {"name": "hotel", "description": "Accommodation"},
            {"name": "gas_station", "description": "Gas station"}
        ]
        
        # Create tags
        for tag_data in sample_tags:
            tag = Tag(
                name=tag_data["name"],
                description=tag_data["description"]
            )
            db.add(tag)
            print(f"✓ Created tag: {tag_data['name']}")
        
        db.commit()
        print("\n✓ All tags created successfully!")
        
    except Exception as e:
        db.rollback()
        print(f"✗ Error creating tags: {str(e)}")
    finally:
        db.close()

def main():
    """Main function to populate database."""
    print("Starting database population...\n")
    print("=" * 50)
    print("Populating Users")
    print("=" * 50)
    populate_users()
    
    print("\n" + "=" * 50)
    print("Populating Tags")
    print("=" * 50)
    
    # Reopen connection for tags
    db = SessionLocal()
    populate_tags()
    
    print("\n" + "=" * 50)
    print("Database population completed!")
    print("=" * 50)

if __name__ == "__main__":
    main()
