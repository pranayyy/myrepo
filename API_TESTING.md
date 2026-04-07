# API Testing Reference

Use these commands to test the API endpoints. Save the Bearer token from auth/sign_in for authenticated requests.

## Base URL
```
http://localhost:8000
```

---

## 1. AUTHENTICATION ENDPOINTS

### Sign Up - Create New User
```bash
curl -X POST "http://localhost:8000/api/v1/auth/sign_up" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "testuser@example.com",
    "username": "testuser",
    "full_name": "Test User",
    "password": "testpass123"
  }'
```

**Success Response (201)**:
```json
{
  "id": 5,
  "email": "testuser@example.com",
  "username": "testuser",
  "full_name": "Test User",
  "is_active": true,
  "created_at": "2024-03-31T10:30:00"
}
```

---

### Sign In - Get JWT Token
```bash
curl -X POST "http://localhost:8000/api/v1/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_doe",
    "password": "password123"
  }'
```

**Success Response (200)**:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidXNlcm5hbWUiOiJqb2huX2RvZSIsImV4cCI6MTcxMjAxMTAwMH0.abc123...",
  "token_type": "bearer",
  "user": {
    "id": 1,
    "email": "john@example.com",
    "username": "john_doe",
    "full_name": "John Doe",
    "is_active": true,
    "created_at": "2024-03-31T10:00:00"
  }
}
```

**Save the access_token** - you'll need it for other endpoints!

---

## 2. SERVICE ENDPOINTS

### Register New Service (Requires Auth)
```bash
curl -X POST "http://localhost:8000/api/v1/services/register_service" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Max Garage",
    "description": "Professional car repair and maintenance service",
    "phone": "+1-555-0123",
    "latitude": 40.7128,
    "longitude": -74.0060,
    "tag_ids": [1, 2]
  }'
```

**Success Response (201)**:
```json
{
  "id": 1,
  "name": "Max Garage",
  "description": "Professional car repair and maintenance service",
  "phone": "+1-555-0123",
  "latitude": 40.7128,
  "longitude": -74.0060,
  "created_by_id": 1,
  "average_rating": 0.0,
  "tags": [
    {"id": 1, "name": "mechanic", "description": "Vehicle repair and maintenance", "created_at": "..."},
    {"id": 2, "name": "repair", "description": "...", "created_at": "..."}
  ],
  "created_at": "2024-03-31T10:15:00",
  "updated_at": "2024-03-31T10:15:00"
}
```

---

### List All Services (Paginated)
```bash
curl "http://localhost:8000/api/v1/services/services?skip=0&limit=10"
```

**Query Parameters**:
- `skip` (int, default=0): Number of records to skip
- `limit` (int, default=10, max=100): Number of records to return

**Response (200)**:
```json
[
  {
    "id": 1,
    "name": "Max Garage",
    "description": "Professional car repair...",
    "phone": "+1-555-0123",
    "latitude": 40.7128,
    "longitude": -74.0060,
    "created_by_id": 1,
    "average_rating": 4.5,
    "tags": [...],
    "created_at": "...",
    "updated_at": "..."
  }
]
```

---

### Get Specific Service by ID
```bash
curl "http://localhost:8000/api/v1/services/services/1"
```

**Response (200)**: Single service object

---

### Update Service (Requires Auth - Owner Only)
```bash
curl -X PUT "http://localhost:8000/api/v1/services/services/1" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Max Garage Updated",
    "description": "Updated description",
    "phone": "+1-555-0124"
  }'
```

**Fields** (all optional):
- `name`: Service name
- `description`: Service description
- `phone`: Contact phone
- `latitude`: Latitude coordinate
- `longitude`: Longitude coordinate
- `tag_ids`: List of tag IDs

---

## 3. RATING ENDPOINTS

### Rate a Service (Requires Auth)
```bash
curl -X POST "http://localhost:8000/api/v1/ratings/rate" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "service_id": 1,
    "rating": 5
  }'
```

**Response (201)**:
```json
{
  "id": 1,
  "user_id": 1,
  "service_id": 1,
  "rating": 5,
  "created_at": "2024-03-31T10:20:00"
}
```

**Rating Values**: 1, 2, 3, 4, or 5 only

---

### Get All Ratings for a Service
```bash
curl "http://localhost:8000/api/v1/ratings/services/1/ratings"
```

**Response (200)**:
```json
[
  {
    "id": 1,
    "user_id": 1,
    "service_id": 1,
    "rating": 5,
    "created_at": "..."
  },
  {
    "id": 2,
    "user_id": 2,
    "service_id": 1,
    "rating": 4,
    "created_at": "..."
  }
]
```

---

## 4. SEARCH ENDPOINTS

### POST Search - Find Services by Location
```bash
curl -X POST "http://localhost:8000/api/v1/search/search" \
  -H "Content-Type: application/json" \
  -d '{
    "latitude": 40.7128,
    "longitude": -74.0060,
    "service_type": "mechanic",
    "tags": ["repair", "maintenance"],
    "radius_km": 10
  }'
```

**Request Body**:
- `latitude` (required, float): -90 to 90
- `longitude` (required, float): -180 to 180
- `service_type` (optional, string): Tag name to search
- `tags` (optional, array): List of tag names
- `radius_km` (optional, float, default=5): Search radius in kilometers

**Response (200)**: Array of matching services

---

### GET Search - Find Nearby Services
```bash
curl "http://localhost:8000/api/v1/search/nearby?latitude=40.7128&longitude=-74.0060&radius_km=5&service_type=mechanic"
```

**Query Parameters**:
- `latitude` (required, float): -90 to 90
- `longitude` (required, float): -180 to 180
- `radius_km` (optional, float, default=5): Search radius
- `service_type` (optional, string): Tag name to filter

---

## 5. SYSTEM ENDPOINTS

### Health Check
```bash
curl "http://localhost:8000/health"
```

**Response (200)**:
```json
{
  "status": "healthy"
}
```

---

### Root Endpoint
```bash
curl "http://localhost:8000/"
```

**Response (200)**:
```json
{
  "message": "Welcome to Local Services API",
  "docs": "/docs",
  "version": "1.0.0"
}
```

---

## ERROR RESPONSES

### 400 - Bad Request (Validation Error)
```json
{
  "detail": "Service name cannot be empty"
}
```

### 401 - Unauthorized (Missing Token)
```json
{
  "detail": "Authorization header missing"
}
```

### 401 - Unauthorized (Invalid Token)
```json
{
  "detail": "Invalid or expired token"
}
```

### 403 - Forbidden (Not Authorized)
```json
{
  "detail": "Not authorized to update this service"
}
```

### 404 - Not Found
```json
{
  "detail": "Service not found"
}
```

### 500 - Server Error
```json
{
  "detail": "Failed to register service"
}
```

---

## DEMO DATA

After running `populate_db.py`, login with any of these users:

| Username | Password | Email |
|----------|----------|-------|
| john_doe | password123 | john@example.com |
| jane_smith | password456 | jane@example.com |
| bob_johnson | password789 | bob@example.com |
| alice_williams | password321 | alice@example.com |

### Available Tags
- mechanic (ID: 1)
- plumber (ID: 2)
- electrician (ID: 3)
- restaurant (ID: 4)
- grocery (ID: 5)
- pharmacy (ID: 6)
- salon (ID: 7)
- laundry (ID: 8)
- hotel (ID: 9)
- gas_station (ID: 10)

---

## COMPLETE WORKFLOW EXAMPLE

### 1. Sign in to get token
```bash
curl -X POST "http://localhost:8000/api/v1/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d '{"username":"john_doe","password":"password123"}'
```
Save the `access_token` value as `TOKEN`

### 2. Register a service
```bash
TOKEN="your_token_here"
curl -X POST "http://localhost:8000/api/v1/services/register_service" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name":"My Service Shop",
    "description":"Best service in town",
    "phone":"+1-555-1234",
    "latitude":40.7128,
    "longitude":-74.0060,
    "tag_ids":[1,2]
  }'
```
Save the `id` value as `SERVICE_ID`

### 3. Rate the service
```bash
curl -X POST "http://localhost:8000/api/v1/ratings/rate" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"service_id":1,"rating":5}'
```

### 4. Search for services
```bash
curl -X POST "http://localhost:8000/api/v1/search/search" \
  -H "Content-Type: application/json" \
  -d '{
    "latitude":40.7128,
    "longitude":-74.0060,
    "service_type":"mechanic",
    "radius_km":10
  }'
```

---

## INTERACTIVE TESTING

Use Swagger UI for interactive testing:
- Open: http://localhost:8000/docs
- Click on each endpoint
- Click "Try it out"
- Enter parameters
- Click "Execute"
- See response

---

## NOTES

- All timestamps are in UTC
- Bearer token expires after 30 minutes
- Latitude range: -90 to 90
- Longitude range: -180 to 180
- Ratings: 1-5 stars only
- Search radius: 0.1 to 100 km
- Pagination limit: max 100 per page
