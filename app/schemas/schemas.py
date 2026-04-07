from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List
from datetime import datetime

# User Schemas
class UserBase(BaseModel):
    email: EmailStr
    username: str
    full_name: Optional[str] = None

class UserCreate(UserBase):
    password: str = Field(..., min_length=8, max_length=72)

class UserLogin(BaseModel):
    username: str
    password: str

class UserResponse(UserBase):
    id: int
    is_active: bool
    created_at: datetime
    
    class Config:
        from_attributes = True

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse

# Tag Schemas
class TagBase(BaseModel):
    name: str
    description: Optional[str] = None

class TagCreate(TagBase):
    pass

class TagResponse(TagBase):
    id: int
    created_at: datetime
    
    class Config:
        from_attributes = True

# Service Schemas
class ServiceBase(BaseModel):
    name: str
    description: Optional[str] = None
    phone: str
    latitude: float
    longitude: float

class ServiceCreate(ServiceBase):
    tag_ids: List[int] = []

class ServiceUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    phone: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    tag_ids: Optional[List[int]] = None

class ServiceResponse(ServiceBase):
    id: int
    created_by_id: int
    average_rating: float
    tags: List[TagResponse] = []
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class ServiceDetailResponse(ServiceResponse):
    pass

# Rating Schemas
class RatingCreate(BaseModel):
    service_id: int
    rating: int = Field(..., ge=1, le=5)

class RatingResponse(BaseModel):
    id: int
    user_id: int
    service_id: int
    rating: int
    created_at: datetime
    
    class Config:
        from_attributes = True

# Report Schemas
class ReportCreate(BaseModel):
    pass

class ReportResponse(BaseModel):
    id: int
    job_id: str
    status: str
    s3_url: Optional[str] = None
    created_at: datetime
    completed_at: Optional[datetime] = None
    file_type: str
    
    class Config:
        from_attributes = True

# Search Schemas
class SearchRequest(BaseModel):
    latitude: float
    longitude: float
    service_type: Optional[str] = None
    tags: Optional[List[str]] = None
    radius_km: Optional[float] = 5.0

class ErrorResponse(BaseModel):
    error: str
    detail: Optional[str] = None
    status_code: int

class ValidationErrorResponse(BaseModel):
    error: str = "Validation Error"
    details: List[dict]
    status_code: int = 400
