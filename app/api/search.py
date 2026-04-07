from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import Optional, List
from math import radians, cos, sin, asin, sqrt
from app.core.database import get_db
from app.models.database_models import Service, Tag
from app.schemas.schemas import ServiceResponse, SearchRequest

router = APIRouter(prefix="/api/v1/search", tags=["search"])

def haversine(lon1, lat1, lon2, lat2):
    """
    Calculate the great circle distance between two points 
    on the earth (specified in decimal degrees)
    Returns distance in kilometers
    """
    # convert decimal degrees to radians
    lon1, lat1, lon2, lat2 = map(radians, [lon1, lat1, lon2, lat2])
    
    # haversine formula
    dlon = lon2 - lon1
    dlat = lat2 - lat1
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    c = 2 * asin(sqrt(a))
    r = 6371  # Radius of earth in kilometers
    return c * r

@router.post("/search", response_model=List[ServiceResponse])
def search_services(
    search: SearchRequest,
    db: Session = Depends(get_db)
):
    """
    Search for local services based on:
    - latitude and longitude
    - service type (using tags)
    - radius in km
    
    Endpoint: POST /search
    """
    try:
        # Start with all services
        query = db.query(Service)
        
        # Filter by tags if provided
        if search.service_type:
            # Search by tag name
            tag = db.query(Tag).filter(Tag.name.ilike(f"%{search.service_type}%")).first()
            if tag:
                query = query.filter(Service.tags.any(Tag.id == tag.id))
        
        if search.tags:
            # Filter by multiple tags
            tags = db.query(Tag).filter(Tag.name.in_(search.tags)).all()
            if tags:
                tag_ids = [tag.id for tag in tags]
                query = query.filter(Service.tags.any(Tag.id.in_(tag_ids)))
        
        # Get all services that match tag criteria
        services = query.all()
        
        # Filter by location (haversine distance)
        result_services = []
        for service in services:
            distance = haversine(
                search.longitude, search.latitude,
                service.longitude, service.latitude
            )
            
            # Include services within radius
            if distance <= (search.radius_km or 5.0):
                result_services.append(service)
        
        return result_services
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Search failed: {str(e)}"
        )

@router.get("/search/nearby", response_model=List[ServiceResponse])
def search_nearby(
    latitude: float = Query(..., ge=-90, le=90),
    longitude: float = Query(..., ge=-180, le=180),
    radius_km: float = Query(5.0, ge=0.1, le=100),
    service_type: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """
    Search for nearby services using GET request.
    Endpoint: GET /search/nearby?latitude=40.7128&longitude=-74.0060&radius_km=5
    """
    try:
        # Start with all services
        query = db.query(Service)
        
        # Filter by tag if provided
        if service_type:
            tag = db.query(Tag).filter(Tag.name.ilike(f"%{service_type}%")).first()
            if tag:
                query = query.filter(Service.tags.any(Tag.id == tag.id))
        
        services = query.all()
        
        # Filter by distance
        result_services = []
        for service in services:
            distance = haversine(
                longitude, latitude,
                service.longitude, service.latitude
            )
            
            if distance <= radius_km:
                result_services.append(service)
        
        return result_services
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Search failed: {str(e)}"
        )
