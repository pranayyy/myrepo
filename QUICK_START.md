# Quick Start Guide - Local Services API

## 🚀 Fast Setup (5 minutes)

### Prerequisites
- Python 3.11+
- pip (Python package manager)
- Git (optional)

### Step 1: Install Dependencies
```bash
cd local-services-app
pip install -r requirements.txt
```

### Step 2: Populate Database
```bash
python scripts/populate_db.py
```

Expected output:
```
Starting database population...

==================================================
Populating Users
==================================================
✓ Created user: john_doe
✓ Created user: jane_smith
✓ Created user: bob_johnson
✓ Created user: alice_williams

✓ All users created successfully!

==================================================
Populating Tags
==================================================
✓ Created tag: mechanic
✓ Created tag: plumber
...
✓ All tags created successfully!

==================================================
Database population completed!
==================================================
```

### Step 3: Run the Application
```bash
python -m uvicorn app.main:app --reload
```

Output:
```
INFO:     Uvicorn running on http://127.0.0.1:8000
INFO:     Application startup complete
```

### Step 4: Access the API
- **API Documentation**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **Health Check**: http://localhost:8000/health

---

## 📝 Testing the APIs

### 1. Sign Up (Create Account)
```bash
curl -X POST "http://localhost:8000/api/v1/auth/sign_up" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "myuser@example.com",
    "username": "myuser",
    "full_name": "My Name",
    "password": "mypassword123"
  }'
```

Response:
```json
{
  "id": 1,
  "email": "myuser@example.com",
  "username": "myuser",
  "full_name": "My Name",
  "is_active": true,
  "created_at": "2024-03-31T10:15:00"
}
```

### 2. Sign In (Get Token)
```bash
curl -X POST "http://localhost:8000/api/v1/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "myuser",
    "password": "mypassword123"
  }'
```

Response:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "user": {...}
}
```

**Save the `access_token`** - you'll need it for other requests!

### 3. Register a Service
```bash
curl -X POST "http://localhost:8000/api/v1/services/register_service" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Johns Garage",
    "description": "Professional auto repair and maintenance",
    "phone": "+1-555-0123",
    "latitude": 40.7128,
    "longitude": -74.0060,
    "tag_ids": [1, 2]
  }'
```

### 4. List Services
```bash
curl "http://localhost:8000/api/v1/services/services?skip=0&limit=10"
```

### 5. Search Nearby Services
```bash
curl -X POST "http://localhost:8000/api/v1/search/search" \
  -H "Content-Type: application/json" \
  -d '{
    "latitude": 40.7128,
    "longitude": -74.0060,
    "service_type": "mechanic",
    "radius_km": 5
  }'
```

### 6. Rate a Service
```bash
curl -X POST "http://localhost:8000/api/v1/ratings/rate" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "service_id": 1,
    "rating": 5
  }'
```

---

## 🐳 Docker Setup (Alternative)

If you have Docker installed:

```bash
# Build and start all services
docker-compose up --build

# Access API at http://localhost:8000
# Services started:
# - API on port 8000
# - Redis on port 6379
# - MongoDB on port 27017
```

---

## 📚 Pre-populated Demo Data

After running `populate_db.py`, you can login with:

| Username      | Password     | Email             |
|---------------|--------------|-------------------|
| john_doe      | password123  | john@example.com  |
| jane_smith    | password456  | jane@example.com  |
| bob_johnson   | password789  | bob@example.com   |
| alice_williams| password321  | alice@example.com |

Available service tags:
- mechanic
- plumber
- electrician
- restaurant
- grocery
- pharmacy
- salon
- laundry
- hotel
- gas_station

---

## 🔑 Key Concepts

### JWT Token
- Used for authentication
- Required in `Authorization: Bearer <token>` header
- Expires in 30 minutes
- Created during sign-in

### Location-based Search
- Uses Haversine formula for distance calculation
- Requires latitude and longitude
- Default search radius: 5 km
- Supports filtering by service type (tag)

### Service Rating
- Range: 1-5 stars only
- Updates service average rating
- Users can update their own rating
- Required authentication

---

## 🛠️ Troubleshooting

### "ModuleNotFoundError: No module named 'fastapi'"
```bash
pip install -r requirements.txt
```

### "Port 8000 already in use"
```bash
# On Windows
netstat -ano | findstr :8000
taskkill /PID <PID> /F

# On Mac/Linux
lsof -i :8000
kill -9 <PID>
```

### "Database is locked"
- Delete `test.db` file
- Rerun: `python scripts/populate_db.py`

### Import errors after editing
- Uvicorn auto-reload should fix this
- If not, restart the server

---

## 📖 API Documentation

Full interactive documentation available at:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

---

## ✅ Next Steps

1. ✅ Setup complete - API running
2. Test all endpoints using examples above
3. Explore Swagger UI for more details
4. Check [README.md](README.md) for advanced topics
5. See [WEEK1_IMPLEMENTATION.md](WEEK1_IMPLEMENTATION.md) for implementation details

---

## 💡 Tips

- Use Swagger UI (http://localhost:8000/docs) to test APIs directly in browser
- Every endpoint returns proper HTTP status codes (200, 201, 400, 401, 404, 500)
- Error responses include details for debugging
- All passwords are encrypted with bcrypt
- Database is SQLite (development) - fine for testing

---

**Successfully Started!** 🎉

Your local services API is now running. Open http://localhost:8000/docs to explore all endpoints.
