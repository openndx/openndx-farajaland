import json
import strawberry
from typing import Optional
import uvicorn
from strawberry.fastapi import GraphQLRouter
from fastapi import FastAPI, Depends, HTTPException
from dotenv import load_dotenv

# SQLAlchemy imports for table creation
from mock_data import Father, Informant, Mother, load_mock_data
from pydantic import BaseModel
from datetime import date
from contextlib import asynccontextmanager

from mock_data import PersonData

# OAuth2 imports
from oauth2 import (
    OAuth2Handler,
    TokenResponse,
    get_current_client,
    require_valid_client
)
from fastapi import Form
from fastapi.security import HTTPBasic, HTTPBasicCredentials

load_dotenv()


from strawberry.types import Info

@strawberry.federation.type
class Query:
    @strawberry.field(description="Get person information by NIC")
    def health_check(self, info: Info) -> str:
        # You can access the authenticated client from context
        client_id = info.context.get("client_id")
        return f"Healthy - Authenticated as: {client_id}"

    @strawberry.field(description="Get person information by NIC")
    def get_person_info(self, nic: strawberry.ID, info: Info) -> Optional[PersonData]:
        # You can access the authenticated client from context
        client_id = info.context.get("client_id")

        # Optional: Add audit logging with client_id
        print(f"Client {client_id} requested NIC: {nic}")

        # Get Data From Mock Data — read fresh from disk on every request so
        # edits to mock_data.json are picked up without restarting the service.
        for data in load_mock_data()['birth']:
            if data.nic == str(nic):
                return data
        return None

schema = strawberry.federation.Schema(query=Query, types=[PersonData, Informant, Father, Mother])

@asynccontextmanager
async def lifespan(app: FastAPI):
    openapi_schema = app.openapi()
    with open("openapi.json", "w") as f:
        json.dump(openapi_schema, f, sort_keys=False)
    print("✅ OpenAPI schema written to openapi.json")
    # Setup code
    yield
    # Teardown code

# Create FastAPI app
app = FastAPI(
    title="Mock RGD GraphQL API",
    description="Mock Registrar General's Department GraphQL subgraph providing person address and profession data",
    version="1.0.0",
    openapi_url="/openapi.json",
    docs_url="/docs",
    lifespan=lifespan
)

# Pydantic schema for request validation
from typing import Optional
class PersonCreate(BaseModel):
    full_name: str
    other_names: Optional[str] = None
    birth_date: Optional[date] = None
    birth_place: Optional[str] = None
    email: str
    nic: str
    address: Optional[str] = None
    profession: Optional[str] = None

# Add GraphQL router with OAuth2 protection
# Custom context getter to include authenticated client information
async def get_graphql_context(client_id: str = Depends(get_current_client)):
    """
    Custom context getter for GraphQL
    Makes the authenticated client_id available in GraphQL resolvers
    """
    return {
        "client_id": client_id,
        "authenticated": True
    }

graphql_app = GraphQLRouter(
    schema,
    context_getter=get_graphql_context,
    graphiql=False
)
app.include_router(graphql_app, prefix="/graphql")

# Health check endpoint
@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "mock-rgd"}

# Root endpoint with service info
@app.get("/")
async def root():
    return {
        "service": "Mock RGD GraphQL API",
        "description": "Provides person address and profession data by NIC",
        "endpoints": {
            "graphql": "/graphql",
            "health": "/health",
            "oauth_token": "/oauth/token"
        }
    }


# OAuth2 Token Endpoint
@app.post("/oauth/token", response_model=TokenResponse)
async def get_token(
    grant_type: str = Form(...),
    credentials: HTTPBasicCredentials = Depends(HTTPBasic())
):
    """
    OAuth2 Token Endpoint - Client Credentials Grant

    Authenticate with client_secret_basic: send the client ID and secret in the
    Authorization: Basic header and grant_type=client_credentials in the form body.

    Returns:
    {
        "access_token": "jwt_token_here",
        "token_type": "bearer",
        "expires_in": 3600
    }
    """
    # Validate grant type
    if grant_type != "client_credentials":
        raise HTTPException(
            status_code=400,
            detail="Unsupported grant_type. Only 'client_credentials' is supported."
        )

    # Verify client credentials
    client_id = credentials.username
    if not OAuth2Handler.verify_client(client_id, credentials.password):
        raise HTTPException(
            status_code=401,
            detail="Invalid client credentials"
        )

    # Generate access token
    from datetime import timedelta
    access_token = OAuth2Handler.create_access_token(
        client_id=client_id,
        expires_delta=timedelta(minutes=60)
    )

    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        expires_in=3600  # 60 minutes in seconds
    )


# read port from environment variable
import os
port = int(os.getenv("PORT", 8080))

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8080,
        reload=True,
        log_level="info"
    )
