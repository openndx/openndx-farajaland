# Mock RGD (Registrar General's Department) GraphQL Service

This service provides a GraphQL subgraph for birth registration information including person details, parent information, and registration data, queryable by NIC number or email.

## Features

- GraphQL API with birth certificate information queries
- OAuth2.0 Client Credentials Grant with `client_secret_basic` authentication
- JWT-based access tokens
- Protected GraphQL endpoint
- Mock data for testing and development
- Health check endpoint
- FastAPI-based with Strawberry GraphQL
- Apollo Federation support

## Setup and Installation

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Run the service:
```bash
python main.py
```

The service will start on `http://localhost:8080`

## API Endpoints

- **GraphQL Playground**: `http://localhost:8080/graphql` (OAuth2 protected)
- **Health Check**: `http://localhost:8080/health`
- **OAuth2 Token**: `http://localhost:8080/oauth/token`
- **Service Info**: `http://localhost:8080/`
- **API Documentation**: `http://localhost:8080/docs`

## Authentication

This API uses **OAuth2.0 Client Credentials Grant** with **`client_secret_basic`** authentication. You must obtain an access token before accessing protected endpoints (including the GraphQL API).

### Pre-configured Clients

The following test clients are available:

| Client ID | Client Secret |
|-----------|---------------|
| `client_app_2` | `secret_key_456` |
| `test_client` | `test_secret` |

### Getting an Access Token

**Endpoint**: `POST /oauth/token`

**Request** (application/x-www-form-urlencoded):
```bash
curl -X POST "http://localhost:8080/oauth/token" \
  -u "test_client:test_secret" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials"
```

Send the client ID and secret in the Basic authorization header. The form body
contains only `grant_type`; credentials in the body (`client_secret_post`) are not accepted.

**Response**:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 3600
}
```

**Token Details**:
- Token Type: JWT
- Expiration: 60 minutes
- Usage: Include in Authorization header as `Bearer <token>`

## GraphQL Schema

### Types

```graphql
type PersonData {
  id: Int!
  br_no: String!
  nic: ID!
  district: String!
  division: String!
  birth_date: Date!
  birth_place: String!
  name: String!
  sex: String!
  are_parents_married: Boolean!
  is_grandfather_born_in_sri_lanka: Boolean!
  father: Father!
  mother: Mother!
  date_of_registration: Date!
  registrar_signature: String!
  informant: Informant!
}

type Father {
  name: String!
  nic: String!
  birth_date: Date!
  birth_place: String!
  race: String!
}

type Mother {
  name: String!
  nic: String!
  birth_date: Date!
  birth_place: String!
  race: String!
  age_at_birth: Int!
}

type Informant {
  signature: String!
  full_name: String!
  residence: String!
  relationship_to_baby: String!
  nic: String!
}

type Query {
  healthCheck: String!
  getPersonInfo(nic: ID!): PersonData
}
```

### Sample GraphQL Queries

#### Health Check:
```graphql
query {
  healthCheck
}
```

**Response**:
```json
{
  "data": {
    "healthCheck": "Healthy - Authenticated as: test_client"
  }
}
```

#### Get Person by NIC:
```graphql
query GetPerson($nic: ID!) {
  getPersonInfo(nic: $nic) {
    id
    br_no
    name
    nic
    birth_date
    birth_place
    sex
    district
    division
    are_parents_married
    is_grandfather_born_in_sri_lanka
    father {
      name
      nic
      birth_date
      birth_place
      race
    }
    mother {
      name
      nic
      birth_date
      birth_place
      race
      age_at_birth
    }
    informant {
      full_name
      residence
      relationship_to_baby
      nic
    }
    date_of_registration
    registrar_signature
  }
}
```

**Variables**:
```json
{
  "nic": "nayana@opensource.lk"
}
```

## Usage Examples

### Complete Example with cURL

```bash
# Step 1: Get access token
TOKEN_RESPONSE=$(curl -s -X POST "http://localhost:8080/oauth/token" \
  -u "test_client:test_secret" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials")

ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.access_token')

# Step 2: Make GraphQL query
curl -X POST "http://localhost:8080/graphql" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ getPersonInfo(nic: \"nayana@opensource.lk\") { name nic birth_date } }"
  }'
```

### Python Client Example

```python
import requests

BASE_URL = "http://localhost:8080"
CLIENT_ID = "test_client"
CLIENT_SECRET = "test_secret"

# Step 1: Get access token
token_response = requests.post(
    f"{BASE_URL}/oauth/token",
    auth=(CLIENT_ID, CLIENT_SECRET),
    data={"grant_type": "client_credentials"}
)
access_token = token_response.json()["access_token"]

# Step 2: Make GraphQL query
headers = {
    "Authorization": f"Bearer {access_token}",
    "Content-Type": "application/json"
}

graphql_query = {
    "query": """
    {
      getPersonInfo(nic: "nayana@opensource.lk") {
        name
        nic
        birth_date
        birth_place
        father {
          name
          nic
        }
        mother {
          name
          nic
        }
      }
    }
    """
}

response = requests.post(
    f"{BASE_URL}/graphql",
    headers=headers,
    json=graphql_query
)

print(response.json())
```

### JavaScript/Node.js Client Example

```javascript
const axios = require('axios');

const BASE_URL = 'http://localhost:8080';
const CLIENT_ID = 'test_client';
const CLIENT_SECRET = 'test_secret';

async function queryGraphQL() {
  // Step 1: Get access token
  const tokenResponse = await axios.post(
    `${BASE_URL}/oauth/token`,
    new URLSearchParams({
      grant_type: 'client_credentials'
    }),
    {
      auth: { username: CLIENT_ID, password: CLIENT_SECRET },
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    }
  );

  const accessToken = tokenResponse.data.access_token;

  // Step 2: Make GraphQL query
  const response = await axios.post(
    `${BASE_URL}/graphql`,
    {
      query: `
        {
          getPersonInfo(nic: "nayana@opensource.lk") {
            name
            nic
            birth_date
            birth_place
            father {
              name
              nic
            }
            mother {
              name
              nic
            }
          }
        }
      `
    },
    {
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      }
    }
  );

  console.log(response.data);
}

queryGraphQL();
```

## Mock Data

The service includes sample birth certificate data for the following NICs:
- `nayana@opensource.lk` - Nuwan Fernando (Colombo)
- `regina@opensource.lk` - Nisha Fernando (Galle)
- `thanikan@opensource.lk` - Rohan Jayasuriya (Kandy)
- `mohamed@opensource.lk` - Mohamed Ali (Galle)
- `sanjiva@opensource.lk` - Sanjiva Edirisinghe (Jaffna)

## Federation Support

This service is designed to work as a subgraph in an Apollo federated GraphQL setup, providing birth registration data that can be composed with other services.

## Security Notes

**IMPORTANT**: This is a mock service for development and testing.

For production use, ensure you:
1. Replace the randomly generated `SECRET_KEY` with a strong, persistent secret stored securely
2. Store client credentials in a secure database, not in-memory
3. Use HTTPS for all API communication
4. Implement rate limiting on the token endpoint
5. Never expose client secrets in client-side code or version control
6. Store access tokens securely on the client side
7. Implement proper token refresh mechanisms
8. Add comprehensive logging and monitoring

## Adding New Clients

To add new OAuth2 clients, edit the `REGISTERED_CLIENTS` dictionary in `oauth2.py`:

```python
REGISTERED_CLIENTS: Dict[str, str] = {
    "client_app_1": "secret_key_123",
    "client_app_2": "secret_key_456",
    "test_client": "test_secret",
    "your_new_client": "your_secure_secret",  # Add here
}
```

## Troubleshooting

### "Invalid client credentials" error
- Verify your `client_id` and `client_secret` are correct
- Check that the client is registered in `REGISTERED_CLIENTS` in `oauth2.py`

### "Token has expired" error
- Request a new token using the `/oauth/token` endpoint
- Tokens expire after 60 minutes

### "Could not validate credentials" error
- Ensure the token is included in the Authorization header
- Verify the token format: `Authorization: Bearer <token>`
- Check that the token hasn't expired

### GraphQL endpoint returns 401
- The GraphQL endpoint requires OAuth2 authentication
- Obtain a token first, then include it in the Authorization header

## Releasing a New Image

Images are built for `linux/amd64` and `linux/arm64` and published to GHCR by
`.github/workflows/release-images.yml`. To release, push a tag named after the image:

```bash
git tag rgd-api/v0.2.0
git push origin rgd-api/v0.2.0
```

This publishes `ghcr.io/openndx/rgd-api:v0.2.0`. The workflow can also be run
manually from the Actions tab. After releasing, update the `RGD_IMAGE` default in
`members/run-member-services.sh`, or override it for a single run:

```bash
RGD_IMAGE=ghcr.io/openndx/rgd-api:v0.2.0 ./members/run-member-services.sh rgd
```
