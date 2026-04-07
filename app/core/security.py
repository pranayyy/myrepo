from datetime import datetime, timedelta
from jose import JWTError, jwt
from app.core.config import settings
import bcrypt

def hash_password(password: str) -> str:
    """Hash password with bcrypt. Max length: 72 bytes."""
    # Encode password to bytes
    if isinstance(password, str):
        password = password.encode('utf-8')
    
    # Truncate to 72 bytes if needed (bcrypt limit)
    if len(password) > 72:
        password = password[:72]
    
    # Generate salt and hash password
    salt = bcrypt.gensalt(rounds=12)
    hashed = bcrypt.hashpw(password, salt)
    return hashed.decode('utf-8')

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify password against hash."""
    if isinstance(plain_password, str):
        plain_password = plain_password.encode('utf-8')
    if isinstance(hashed_password, str):
        hashed_password = hashed_password.encode('utf-8')
    
    # Truncate plain password to 72 bytes if needed
    if len(plain_password) > 72:
        plain_password = plain_password[:72]
    
    return bcrypt.checkpw(plain_password, hashed_password)

def create_access_token(data: dict, expires_delta: timedelta | None = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.secret_key, algorithm=settings.algorithm)
    return encoded_jwt

def decode_token(token: str):
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])
        return payload
    except JWTError:
        return None
