from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from app.core.database import get_db
from app.core.security import decode_token
from app.models.database_models import Service, Tag, User
from app.schemas.schemas import ServiceCreate, ServiceResponse, ServiceUpdate
from fastapi import Header

router = APIRouter(prefix="/api/v1/services", tags=["services"])

def get_current_user(authorization: Optional[str] = Header(None), db: Session = Depends(get_db)):
    """
    Extract and validate JWT token from Authorization header.
    """
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header missing"
        )
    
    try:
        scheme, token = authorization.split()
        if scheme.lower() != "bearer":
            raise ValueError("Invalid scheme")
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header"
        )
    
    payload = decode_token(token)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token"
        )
    
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token"
        )
    
    user = db.query(User).filter(User.id == int(user_id)).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found"
        )
    
    return user

@router.post("/register_service", response_model=ServiceResponse, status_code=status.HTTP_201_CREATED)
def register_service(
    service: ServiceCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Register a new local service.
    Endpoint: POST /register_service
    """
    try:
        # Validate input data
        if not service.name or len(service.name.strip()) == 0:
            raise ValueError("Service name cannot be empty")
        
        if not service.phone or len(service.phone.strip()) == 0:
            raise ValueError("Service phone cannot be empty")
        
        if service.latitude < -90 or service.latitude > 90:
            raise ValueError("Latitude must be between -90 and 90")
        
        if service.longitude < -180 or service.longitude > 180:
            raise ValueError("Longitude must be between -180 and 180")
        
        # Create service
        db_service = Service(
            name=service.name,
            description=service.description,
            phone=service.phone,
            latitude=service.latitude,
            longitude=service.longitude,
            created_by_id=current_user.id
        )
        
        # Add tags if provided
        if service.tag_ids:
            tags = db.query(Tag).filter(Tag.id.in_(service.tag_ids)).all()
            if len(tags) != len(service.tag_ids):
                raise ValueError("One or more tags not found")
            db_service.tags = tags
        
        db.add(db_service)
        db.commit()
        db.refresh(db_service)
        
        return db_service
    
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to register service"
        )

@router.get("/services", response_model=List[ServiceResponse])
def list_services(
    skip: int = Query(0, ge=0),
    limit: int = Query(10, ge=1, le=100),
    db: Session = Depends(get_db)
):
    """
    List all services with pagination.
    """
    services = db.query(Service).offset(skip).limit(limit).all()
    return services

@router.get("/services/{service_id}", response_model=ServiceResponse)
def get_service(service_id: int, db: Session = Depends(get_db)):
    """
    Get a specific service by ID.
    """
    service = db.query(Service).filter(Service.id == service_id).first()
    if not service:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Service not found"
        )
    return service

@router.put("/services/{service_id}", response_model=ServiceResponse)
def update_service(
    service_id: int,
    service_update: ServiceUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Update a service (only by creator).
    """
    db_service = db.query(Service).filter(Service.id == service_id).first()
    if not db_service:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Service not found"
        )
    
    if db_service.created_by_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to update this service"
        )
    
    # Update fields
    if service_update.name:
        db_service.name = service_update.name
    if service_update.description:
        db_service.description = service_update.description
    if service_update.phone:
        db_service.phone = service_update.phone
    if service_update.latitude:
        db_service.latitude = service_update.latitude
    if service_update.longitude:
        db_service.longitude = service_update.longitude
    
    db.commit()
    db.refresh(db_service)
    return db_service
