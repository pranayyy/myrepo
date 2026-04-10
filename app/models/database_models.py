from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, ForeignKey, Table
from sqlalchemy.orm import relationship
from datetime import datetime
from app.core.database import Base

# Association table for many-to-many relationship between Service and Tag
service_tags = Table(
    'service_tags',
    Base.metadata,
    Column('service_id', Integer, ForeignKey('service.id'), primary_key=True),
    Column('tag_id', Integer, ForeignKey('tag.id'), primary_key=True)
)

# Association table for many-to-many relationship between User and Service (ratings)
user_service_ratings = Table(
    'user_service_ratings',
    Base.metadata,
    Column('user_id', Integer, ForeignKey('user.id'), primary_key=True),
    Column('service_id', Integer, ForeignKey('service.id'), primary_key=True),
    Column('rating', Integer, nullable=False),
    Column('created_at', DateTime, default=datetime.utcnow)
)

class User(Base):
    __tablename__ = "user"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    username = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    full_name = Column(String)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    services = relationship("Service", back_populates="created_by_user")
    ratings = relationship("Service", secondary=user_service_ratings)

class Tag(Base):
    __tablename__ = "tag"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True)
    description = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    services = relationship("Service", secondary=service_tags, back_populates="tags")

class Service(Base):
    __tablename__ = "service"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    description = Column(String)
    phone = Column(String)
    latitude = Column(Float)
    longitude = Column(Float)
    created_by_id = Column(Integer, ForeignKey('user.id'))
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    average_rating = Column(Float, default=0.0)
    
    # Relationships
    tags = relationship("Tag", secondary=service_tags, back_populates="services")
    created_by_user = relationship("User", back_populates="services")

class Report(Base):
    __tablename__ = "report"
    
    id = Column(Integer, primary_key=True, index=True)
    job_id = Column(String, unique=True, index=True)
    user_id = Column(Integer, ForeignKey('user.id'))
    s3_url = Column(String)
    status = Column(String, default="pending")  # pending, completed, failed
    created_at = Column(DateTime, default=datetime.utcnow)
    completed_at = Column(DateTime, nullable=True)
    file_type = Column(String, default="pdf")  # pdf, html

class Rating(Base):
    __tablename__ = "rating"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey('user.id'))
    service_id = Column(Integer, ForeignKey('service.id'))
    rating = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

class Rating(Base):
    __tablename__ = "rating"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey('user.id'))
    service_id = Column(Integer, ForeignKey('service.id'))
    rating = Column(Integer)  # 1-5
    created_at = Column(DateTime, default=datetime.utcnow)
