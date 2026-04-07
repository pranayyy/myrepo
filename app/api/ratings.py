from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List
from app.core.database import get_db
from app.core.security import decode_token
from app.models.database_models import Rating, Service, User
from app.schemas.schemas import RatingCreate, RatingResponse
from fastapi import Header
from typing import Optional

router = APIRouter(prefix="/api/v1/ratings", tags=["ratings"])

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

@router.post("/rate", response_model=RatingResponse, status_code=status.HTTP_201_CREATED)
def rate_service(
    rating: RatingCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Rate a service (1-5 stars).
    Endpoint: POST /rate
    """
    try:
        # Validate service exists
        service = db.query(Service).filter(Service.id == rating.service_id).first()
        if not service:
            raise ValueError("Service not found")
        
        # Validate rating value
        if rating.rating < 1 or rating.rating > 5:
            raise ValueError("Rating must be between 1 and 5")
        
        # Check if user already rated this service
        existing_rating = db.query(Rating).filter(
            (Rating.user_id == current_user.id) & 
            (Rating.service_id == rating.service_id)
        ).first()
        
        if existing_rating:
            # Update existing rating
            existing_rating.rating = rating.rating
            db.commit()
            db.refresh(existing_rating)
            return existing_rating
        
        # Create new rating
        db_rating = Rating(
            user_id=current_user.id,
            service_id=rating.service_id,
            rating=rating.rating
        )
        db.add(db_rating)
        db.commit()
        
        # Update service average rating
        avg_rating = db.query(func.avg(Rating.rating)).filter(
            Rating.service_id == rating.service_id
        ).scalar()
        service.average_rating = avg_rating or 0.0
        db.commit()
        
        db.refresh(db_rating)
        return db_rating
    
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to rate service"
        )

@router.get("/services/{service_id}/ratings", response_model=List[RatingResponse])
def get_service_ratings(service_id: int, db: Session = Depends(get_db)):
    """
    Get all ratings for a service.
    """
    service = db.query(Service).filter(Service.id == service_id).first()
    if not service:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Service not found"
        )
    
    ratings = db.query(Rating).filter(Rating.service_id == service_id).all()
    return ratings
