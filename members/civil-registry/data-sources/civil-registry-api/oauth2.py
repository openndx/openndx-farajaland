"""
Minimal OAuth2.0 implementation for FastAPI
Uses Client Credentials grant type with in-memory storage
"""
from datetime import datetime, timedelta
from typing import Optional, Dict
import jwt
from fastapi import HTTPException, Security, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
import secrets


# Configuration
SECRET_KEY = secrets.token_urlsafe(32)  # Generate a random secret key
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60

# In-memory storage for registered clients
# In production, this would be in a database
REGISTERED_CLIENTS: Dict[str, str] = {
    "client_app_2": "secret_key_456",
    "test_client": "test_secret",
}

# In-memory storage for issued tokens (for revocation if needed)
# This is optional but useful for token management
ACTIVE_TOKENS: set = set()


class TokenRequest(BaseModel):
    """OAuth2 Token Request Model"""
    grant_type: str
    client_id: str
    client_secret: str


class TokenResponse(BaseModel):
    """OAuth2 Token Response Model"""
    access_token: str
    token_type: str
    expires_in: int


class OAuth2Handler:
    """Handles OAuth2 token generation and validation"""

    @staticmethod
    def verify_client(client_id: str, client_secret: str) -> bool:
        """Verify client credentials against registered clients"""
        return REGISTERED_CLIENTS.get(client_id) == client_secret

    @staticmethod
    def create_access_token(client_id: str, expires_delta: Optional[timedelta] = None) -> str:
        """Create a JWT access token"""
        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)

        to_encode = {
            "sub": client_id,
            "exp": expire,
            "iat": datetime.utcnow(),
            "type": "access_token"
        }

        encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
        ACTIVE_TOKENS.add(encoded_jwt)
        return encoded_jwt

    @staticmethod
    def verify_token(token: str) -> Dict:
        """Verify and decode JWT token"""
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])

            # Check if token is in active tokens (not revoked)
            if token not in ACTIVE_TOKENS:
                raise HTTPException(
                    status_code=401,
                    detail="Token has been revoked"
                )

            # Check if token has expired
            exp = payload.get("exp")
            if exp and datetime.fromtimestamp(exp) < datetime.utcnow():
                raise HTTPException(
                    status_code=401,
                    detail="Token has expired"
                )

            return payload
        except jwt.ExpiredSignatureError:
            raise HTTPException(
                status_code=401,
                detail="Token has expired",
                headers={"WWW-Authenticate": "Bearer"},
            )
        except jwt.JWTError:
            raise HTTPException(
                status_code=401,
                detail="Could not validate credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )

    @staticmethod
    def revoke_token(token: str):
        """Revoke a token (remove from active tokens)"""
        ACTIVE_TOKENS.discard(token)


# Security scheme for Bearer token
security = HTTPBearer()


async def get_current_client(
    credentials: HTTPAuthorizationCredentials = Security(security)
) -> str:
    """
    Dependency to validate OAuth2 token and extract client_id
    Use this as a dependency in your protected endpoints
    """
    token = credentials.credentials
    payload = OAuth2Handler.verify_token(token)
    client_id = payload.get("sub")

    if client_id is None:
        raise HTTPException(
            status_code=401,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return client_id


# Optional: Dependency for endpoints that need to verify client exists
async def require_valid_client(client_id: str = Depends(get_current_client)) -> str:
    """
    Dependency that ensures the client exists in registered clients
    """
    if client_id not in REGISTERED_CLIENTS:
        raise HTTPException(
            status_code=403,
            detail="Client not found or has been removed"
        )
    return client_id