# Project Directory Structure

```
local-services-app/
│
├── 📁 app/                                  # Main application package
│   │
│   ├── 📁 api/                              # API route handlers
│   │   ├── auth.py                          # Authentication endpoints (sign_up, sign_in)
│   │   ├── services.py                      # Service management (register, list, update)
│   │   ├── ratings.py                       # Rating system (rate, get_ratings)
│   │   ├── search.py                        # Location-based search
│   │   └── __init__.py
│   │
│   ├── 📁 models/                           # Database models (SQLAlchemy ORM)
│   │   ├── database_models.py               # User, Service, Tag, Rating, Report models
│   │   └── __init__.py
│   │
│   ├── 📁 schemas/                          # Request/Response validation (Pydantic)
│   │   ├── schemas.py                       # All Pydantic models
│   │   └── __init__.py
│   │
│   ├── 📁 core/                             # Core utilities and configuration
│   │   ├── config.py                        # Settings management (from .env)
│   │   ├── database.py                      # Database initialization & session
│   │   ├── security.py                      # JWT tokens & password hashing
│   │   └── __init__.py
│   │
│   ├── main.py                              # FastAPI app initialization
│   └── __init__.py
│
├── 📁 scripts/                              # Utility scripts
│   ├── populate_db.py                       # Database population with sample data
│   └── setup.py                             # Project setup script
│
├── 📁 tests/                                # Unit tests
│   ├── test_api.py                          # API endpoint tests
│   └── __init__.py
│
├── 📄 Dockerfile                            # Docker image definition
├── 📄 docker-compose.yml                    # Multi-container setup (API+Redis+MongoDB)
├── 📄 requirements.txt                      # Python dependencies
├── 📄 .env.example                          # Environment variables template
├── 📄 .gitignore                            # Git exclusions
│
├── 📖 README.md                             # Main documentation
├── 📖 QUICK_START.md                        # 5-minute setup guide
├── 📖 WEEK1_IMPLEMENTATION.md               # Week 1 implementation details
├── 📖 IMPLEMENTATION_DASHBOARD.md           # Progress tracking & checklist
├── 📖 API_TESTING.md                        # API endpoint testing guide
├── 📖 PROJECT_STRUCTURE.md                  # This file
│
└── 📄 test.db                               # SQLite database (created after first run)

```

## File Descriptions

### 🚀 Core Application (`app/`)

#### `app/main.py`
- FastAPI application initialization
- Router registration
- CORS middleware setup
- Health check endpoint
- Database table creation

#### `app/api/auth.py` (26 lines)
- `POST /api/v1/auth/sign_up` - User registration
- `POST /api/v1/auth/sign_in` - User login with JWT

#### `app/api/services.py` (145 lines)
- `POST /api/v1/services/register_service` - Register service
- `GET /api/v1/services/services` - List services
- `GET /api/v1/services/services/{id}` - Get service details
- `PUT /api/v1/services/services/{id}` - Update service
- JWT authentication via `get_current_user()` dependency

#### `app/api/ratings.py` (115 lines)
- `POST /api/v1/ratings/rate` - Rate a service (1-5)
- `GET /api/v1/ratings/services/{id}/ratings` - Get all ratings
- Automatic average rating calculation
- Many-to-many relationship handling

#### `app/api/search.py` (100 lines)
- `POST /api/v1/search/search` - Search by location
- `GET /api/v1/search/nearby` - Nearby services
- Haversine formula for distance calculation
- Tag-based filtering

#### `app/models/database_models.py` (105 lines)
- **User** - User accounts (id, email, username, hashed_password, full_name)
- **Service** - Local services (id, name, phone, latitude, longitude, average_rating)
- **Tag** - Service categories (id, name, description)
- **Rating** - Service ratings (id, user_id, service_id, rating)
- **Report** - Generated reports (id, job_id, s3_url, status)
- Association tables for M2M relationships

#### `app/schemas/schemas.py` (135 lines)
- **UserBase**, **UserCreate**, **UserLogin**, **UserResponse** - User schemas
- **TagBase**, **TagCreate**, **TagResponse** - Tag schemas
- **ServiceBase**, **ServiceCreate**, **ServiceUpdate**, **ServiceResponse** - Service schemas
- **RatingCreate**, **RatingResponse** - Rating schemas
- **ReportCreate**, **ReportResponse** - Report schemas
- **SearchRequest**, **ErrorResponse**, **ValidationErrorResponse** - Utility schemas

#### `app/core/config.py` (30 lines)
- **Settings** class using Pydantic
- Database URLs (SQLite, PostgreSQL)
- JWT configuration
- AWS configuration
- Redis URLs
- Celery configuration
- MongoDB configuration
- Environment variable loading from `.env`

#### `app/core/database.py` (15 lines)
- **engine** - SQLAlchemy database engine
- **SessionLocal** - Database session factory
- **Base** - Declarative base for models
- **get_db()** - Dependency function for session injection

#### `app/core/security.py` (35 lines)
- **pwd_context** - Bcrypt password hashing
- **hash_password()** - Hash plain text password
- **verify_password()** - Compare passwords
- **create_access_token()** - Generate JWT token
- **decode_token()** - Parse and validate JWT token

### 🔧 Scripts (`scripts/`)

#### `scripts/populate_db.py` (95 lines)
- **populate_users()** - Creates 4 demo users with encrypted passwords
- **populate_tags()** - Creates 10 service category tags
- Safe idempotent operations
- Proper error handling

#### `scripts/setup.py` (40 lines)
- Creates `.env` file with defaults
- Initializes project directories
- Setup instructions

### ✅ Tests (`tests/`)

#### `tests/test_api.py` (75 lines)
- Test database setup using SQLite
- **TestAuth** - Sign up and sign in tests
- **TestServices** - Service registration test
- Uses TestClient for endpoint testing

### 📦 Configuration Files

#### `requirements.txt` (16 packages)
```
fastapi==0.104.1
uvicorn[standard]==0.24.0
sqlalchemy==2.0.23
pydantic==2.5.0
pydantic-settings==2.1.0
python-dotenv==1.0.0
passlib[bcrypt]==1.7.4
python-jose[cryptography]==3.3.0
pyjwt==2.8.1
boto3==1.29.7
pytest==7.4.3
pytest-asyncio==0.21.1
httpx==0.25.2
alembic==1.13.0
celery==5.3.4
redis==5.0.1
pymongo==4.6.0
motor==3.3.2
```

#### `Dockerfile`
- Based on `python:3.11-slim`
- Installs build dependencies
- Copies requirements and installs packages
- Exposes port 8000
- Runs with Uvicorn

#### `docker-compose.yml`
- **app** service - FastAPI application
- **redis** service - Redis cache and Celery broker
- **mongodb** service - MongoDB database
- Volumes for data persistence
- Environment variables passed

#### `.env.example`
- Template for all configuration
- Default SQLite database
- JWT settings
- AWS configuration placeholders
- Redis and MongoDB URLs
- Celery configuration

#### `.gitignore`
- Python cache files (`__pycache__/`, `*.pyc`)
- Virtual environments (`venv/`, `env/`)
- Eggs and distributions (`*.egg-info/`, `dist/`)
- IDE files (`.vscode/`, `.idea/`)
- Database files (`*.db`, `*.sqlite`)
- Environment files (`.env`, `.env.local`)

### 📚 Documentation

#### `README.md` (650+ lines)
- Project overview
- Tech stack details
- Complete project structure
- All API endpoints
- Week 1-4 tasks status
- Quick start instructions
- Docker setup guide
- Usage examples with curl
- Database models explanation
- Testing instructions
- Security features
- Deployment guides
- Troubleshooting section

#### `QUICK_START.md` (200+ lines)
- 5-minute setup guide
- Step-by-step instructions
- API endpoint examples
- Demo user credentials
- Docker alternative
- Troubleshooting tips
- Next steps

#### `WEEK1_IMPLEMENTATION.md` (350+ lines)
- Completed tasks summary
- File-by-file implementation details
- Database schema summary
- Testing instructions
- Key features list
- Dependency list

#### `IMPLEMENTATION_DASHBOARD.md` (250+ lines)
- Status dashboard
- Checklist of all implementations
- Endpoint summary
- Data relationship diagrams
- How to run instructions
- Complete todo list
- Version history

#### `API_TESTING.md` (400+ lines)
- Complete API endpoint reference
- curl examples for every endpoint
- Expected responses
- Error response examples
- Demo data credentials
- Complete workflow example
- Interactive testing via Swagger

#### `PROJECT_STRUCTURE.md` (This file)
- Directory tree
- File descriptions
- Line counts
- File purposes

---

## Statistics

| Metric | Count |
|--------|-------|
| **Total Files** | 30 |
| **Python Files** | 15 |
| **Documentation Files** | 7 |
| **Configuration Files** | 6 |
| **Test Files** | 2 |
| **Total Lines of Code** | ~1200 |
| **Total API Endpoints** | 13 |
| **Database Models** | 5 |
| **Pydantic Schemas** | 12+ |
| **Dependencies** | 18 packages |

---

## File Dependencies

```
main.py
├── api/auth.py
├── api/services.py
├── api/ratings.py
├── api/search.py
├── core/database.py
│   └── core/config.py
├── core/security.py
├── models/database_models.py
│   └── core/database.py
└── schemas/schemas.py
    └── core/config.py

test_api.py
├── main.py (indirectly)
├── core/database.py
└── models/database_models.py

populate_db.py
├── core/config.py
├── core/database.py
├── core/security.py
└── models/database_models.py
```

---

## Import Hierarchy

```
FastAPI Core
└── app/main.py
    ├── api/auth.py
    │   ├── models/database_models.py (User)
    │   ├── schemas/schemas.py (UserCreate, TokenResponse)
    │   ├── core/security.py (hash_password, verify_password, create_access_token)
    │   └── core/database.py (get_db)
    ├── api/services.py
    │   ├── models/database_models.py (Service, Tag, User)
    │   ├── schemas/schemas.py (ServiceCreate, ServiceResponse)
    │   └── core/security.py (decode_token)
    ├── api/ratings.py
    │   ├── models/database_models.py (Rating, Service)
    │   └── schemas/schemas.py (RatingCreate, RatingResponse)
    └── api/search.py
        ├── models/database_models.py (Service, Tag)
        └── schemas/schemas.py (ServiceResponse, SearchRequest)
```

---

## Database Schema

```sql
-- User table
CREATE TABLE user (
  id INTEGER PRIMARY KEY,
  email VARCHAR UNIQUE NOT NULL,
  username VARCHAR UNIQUE NOT NULL,
  hashed_password VARCHAR NOT NULL,
  full_name VARCHAR,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- Tag table
CREATE TABLE tag (
  id INTEGER PRIMARY KEY,
  name VARCHAR UNIQUE NOT NULL,
  description VARCHAR,
  created_at TIMESTAMP
);

-- Service table
CREATE TABLE service (
  id INTEGER PRIMARY KEY,
  name VARCHAR NOT NULL,
  description VARCHAR,
  phone VARCHAR NOT NULL,
  latitude FLOAT NOT NULL,
  longitude FLOAT NOT NULL,
  created_by_id INTEGER FOREIGN KEY,
  average_rating FLOAT DEFAULT 0,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- Service-Tag mapping (M2M)
CREATE TABLE service_tags (
  service_id INTEGER PRIMARY KEY,
  tag_id INTEGER PRIMARY KEY
);

-- Rating table
CREATE TABLE rating (
  id INTEGER PRIMARY KEY,
  user_id INTEGER FOREIGN KEY,
  service_id INTEGER FOREIGN KEY,
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  created_at TIMESTAMP
);

-- Report table
CREATE TABLE report (
  id INTEGER PRIMARY KEY,
  job_id VARCHAR UNIQUE NOT NULL,
  user_id INTEGER FOREIGN KEY,
  s3_url VARCHAR,
  status VARCHAR DEFAULT 'pending',
  file_type VARCHAR DEFAULT 'pdf',
  created_at TIMESTAMP,
  completed_at TIMESTAMP
);
```

---

## How Files Work Together

1. **Request arrives** → `main.py` (FastAPI router)
2. **Route matches** → `api/{endpoint}.py` (handler function)
3. **Auth needed** → `core/security.py` validates JWT token
4. **Get DB** → `core/database.py` provides session
5. **Access DB** → `models/database_models.py` ORM queries
6. **Validate data** → `schemas/schemas.py` Pydantic models
7. **Return response** → JSON response with proper schema
8. **Error** → HTTP error with status code

---

**Total Implementation Size**: ~1200 lines of production code + 2000+ lines of documentation

**Status**: ✅ Week 1 Complete and Ready for Testing
