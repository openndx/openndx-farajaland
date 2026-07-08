# OpenDIF Farajaland - Setup Guide

This guide will help you set up and run the OpenDIF Farajaland reference implementation on your local machine.

## Prerequisites

Before you begin, ensure you have the following installed:

### Required Software

- **Docker** 20.10+ and **Docker Compose** 2.0+
  - [Install Docker Desktop](https://www.docker.com/products/docker-desktop/)
  - Ensure Docker daemon is running before proceeding

- **Git** for version control
  - [Install Git](https://git-scm.com/downloads)

- **jq** (JSON processor, required by init script)
  - macOS: `brew install jq`
  - Ubuntu/Debian: `sudo apt-get install jq`
  - Windows: Download from [stedolan/jq](https://stedolan.github.io/jq/download/)

### Optional Software (For Development)

The following are only required if you want to run and modify the data source services from source code:

- **Python** 3.9+ (for RGD data source development)
  - [Install Python](https://www.python.org/downloads/)
  - Recommended: Use `pyenv` or `conda` for version management

- **Ballerina** 2201.8.0+ (for DRP data source development)
  - [Install Ballerina](https://ballerina.io/downloads/)

- **Node.js** 18+ (for client application development)
  - [Install Node.js](https://nodejs.org/)

### System Requirements

- **RAM**: Minimum 4GB available (8GB recommended)
- **Disk Space**: At least 10GB free
- **Ports**: Ensure the following ports are available:
  - **Core Services**
    - `4000` - Orchestration Engine
    - `9081, 9180` - API Gateway (APISIX)
    - `8090` - FUDI (ThunderID)
    - `5173` - Consent Portal (Frontend)
    - `3001` - Audit Service
  - **Member Services**
    - `8080` - RGD API
    - `9090` - DRP API
    - `9091` - DRP API Adapter
    - `3000` - DIE Passport Application (Frontend)

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/opendif/opendif-farajaland.git
cd opendif-farajaland
```

### 2. Configure Hostname Resolution

Since ThunderID runs inside the Docker network with the hostname `thunderid`, you need to add this hostname to your `/etc/hosts` file for proper DNS resolution:

**macOS/Linux:**
```bash
# Add thunderid hostname to /etc/hosts
echo "127.0.0.1       thunderid" | sudo tee -a /etc/hosts
```

**Windows:**
1. Open Notepad as Administrator
2. Open `C:\Windows\System32\drivers\etc\hosts`
3. Add the following line at the end:
   ```
   127.0.0.1       thunderid
   ```
4. Save the file

**Verify the configuration:**
```bash
ping thunderid
```

Once ThunderID is running, open `https://thunderid:8090` in your browser once and
accept the self-signed certificate warning — otherwise the Consent Portal's
redirect to ThunderID's login page will silently fail with a TLS error.

You should see responses from `127.0.0.1`.

### 3. Make the Initialization Script Executable

```bash
chmod +x init.sh
```

### 4. Run the Initialization Script

The `init.sh` script automates the entire setup process:

```bash
./init.sh
```

**Volume Cleanup Behavior:**

By default, the script removes Docker volumes when you stop it (Ctrl+C). This ensures a fresh start every time and prevents schema mismatch errors.

If you want to preserve data between runs for faster development, set `CLEAN_START=false`:

```bash
# Default: Volumes are removed on exit (recommended)
./init.sh

# Preserve volumes and data between runs
CLEAN_START=false ./init.sh
```

**When to preserve volumes:**
- During active development to keep test data
- When you need faster restarts without re-initializing the database

**When to remove volumes (default):**
- First-time setup
- After changing database schemas
- When encountering database-related errors

**What the script does:**

1. ✅ Checks if Docker is running
2. ✅ Starts NDX infrastructure services via Docker Compose:
   - etcd (service registry)
   - APISIX API Gateway
   - PostgreSQL database
   - Orchestration Engine
   - Consent Engine
   - Policy Decision Point
   - FUDI/ThunderID
3. ✅ Waits for services to be healthy
4. ✅ Mints a system-scoped management token from the ADMIN_CLI M2M client
5. ✅ Creates API Gateway M2M application
6. ✅ Registers API routes in APISIX Gateway
7. ✅ Creates Consent Portal SPA application
8. ✅ Creates Passport Application (M2M) for user access
9. ✅ Creates a mock user automatically (username: nayana)
10. ✅ Starts member data source services:
    - RGD API (Python/FastAPI)
    - DRP API Adapter (Ballerina)
11. ✅ Starts client applications:
    - Passport Application Frontend (http://localhost:3000)
    - Consent Portal Frontend (http://localhost:5173)
12. ✅ **Displays Passport Application credentials and next steps**

**The entire setup process is now fully automated - no manual steps required!**

### 5. Verify the Setup

Once the script completes, you should see:

```
==========================================
All services started successfully!
==========================================

============================================
  M2M Application Credentials
============================================

Application Name: Passport Application

Client ID:
<your-client-id>

Client Secret:
<your-client-secret>

⚠ Important:
  • Save these credentials securely
  • The client secret cannot be retrieved later
  • Use these credentials to call the publicly exposed endpoints

Token Endpoint:
https://thunderid:8090/oauth2/token

Public API Gateway:
http://localhost:9081/public/*
============================================

==========================================
Next Step: Test Passport Application
==========================================

Please open the passport application in your browser:
  URL: http://localhost:3000

Login with the following credentials:
  Username:   nayana
  Password:   Abc12#45

This will allow you to provide consent for the application.
==========================================

Press Ctrl+C to stop all services

All services are running. Monitoring...
```

**Important Notes:**

1. **Save M2M Credentials**: The displayed `Client ID` and `Client Secret` are needed to access the public endpoints. The client secret cannot be retrieved later.

2. **Automatically Created User**: The script automatically creates a mock user for testing:
   - **Username**: `nayana@opensource.lk` (or just `nayana` for login)
   - **Password**: `Abc12#45`

3. **Access Points**:
   - **Passport Application**: `http://localhost:3000` - Main application for testing consent flows
   - **Consent Portal**: `http://localhost:5173` - Standalone consent management interface
   - **API Gateway**: `http://localhost:9081/public/graphql` - Public GraphQL endpoint
   - **Audit Logs API**: `http://localhost:9081/api/audit-logs` - Query audit logs

4. **Keep Running**: The script will continue running and monitoring services. Press `Ctrl+C` when you want to stop all services.

## Testing the GraphQL API

**Note:** In Farajaland, the system uses **email addresses as the National Identity Card (NIC)**. This is a design choice for this reference implementation.

### Basic Query

Try a simple GraphQL query to fetch person information:

```bash
curl -X POST http://localhost:9081/public/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ personInfo(nic: \"nayana@opensource.lk\") { fullName dateOfBirth address } }"
  }'
```

**Expected Response:**

```json
{
  "data": {
    "personInfo": {
      "fullName": "Nayana Opensource",
      "dateOfBirth": "1990-01-15",
      "address": "123 Main Street, Farajaland"
    }
  }
}
```

### Query with Consent Flow

For queries requiring consent (authenticated endpoints), you'll need to:

1. Obtain an access token from FUDI using the Passport Application credentials
2. Include the token in the request
3. Grant consent if prompted
4. Retry the request

See the [API Documentation](README.md#api-documentation) section in the main README for detailed examples.

## Manual Setup (Alternative)

If you prefer to set up services manually or the `init.sh` script fails, follow these steps:

### Step 1: Start NDX Infrastructure

```bash
cd ndx

# Start all NDX services
docker-compose up -d

# Wait for services to be ready (about 30 seconds)
sleep 30

# Check service status
docker-compose ps
```

### Step 2: Configure FUDI Applications

ThunderID's bootstrap (`config/thunderid/bootstrap/02-admin-cli.sh`) already creates
an `ADMIN_CLI` M2M client with management API access during `docker-compose up`, so
you can create the required applications with curl instead of a browser console:

```bash
# Mint a management token from the ADMIN_CLI client created during bootstrap
TOKEN=$(curl -k -s -u "ADMIN_CLI:${ADMIN_CLI_SECRET:-1234}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" -d "scope=system" \
  https://thunderid:8090/oauth2/token | jq -r .access_token)

# Use $TOKEN as a Bearer token against https://thunderid:8090/applications
# (POST) to create an M2M application for the API Gateway and an SPA
# application for the Consent Portal. Note down the client IDs and secrets.
```

Or simply run `./init.sh`, which performs all of this automatically.

### Step 3: Register API Gateway Routes

Update the APISIX routes with your client credentials:

```bash
# Replace $CLIENT_ID and $CLIENT_SECRET with your values
curl --location --request PUT http://localhost:9180/apisix/admin/routes \
  --header "Content-Type: application/json" \
  --header "X-API-KEY: QuNGwapKysRvHfUtNkQFbUaGiiYeOcGo" \
  --data '{
    "uri": "/public/*",
    "methods": ["GET", "POST"],
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "orchestration-engine:4000": 1
      }
    },
    "plugins": {
      "openid-connect": {
        "discovery": "https://thunderid:8090/.well-known/openid-configuration",
        "bearer_only": true,
        "client_id": "YOUR_CLIENT_ID",
        "client_secret": "YOUR_CLIENT_SECRET",
        "ssl_verify": false
      }
    },
    "id": "oe-endpoint"
  }'
```

### Step 4: Start Member Services

```bash
cd members

# Make the script executable
chmod +x run-member-services.sh

# Start all member services
./run-member-services.sh all
```

Or start services individually:

**RGD API:**
```bash
cd members/rgd/data-sources/rgd-api
python -m uvicorn main:app --port 8080
```

**DRP API Adapter:**
```bash
cd members/drp/data-sources/drp-api-adapter
bal run
```

## Troubleshooting

### Docker Issues

**Error: "Docker is not running"**
```bash
# Start Docker Desktop application
# Or start Docker daemon on Linux:
sudo systemctl start docker
```

**Error: "Port already in use"**
```bash
# Find and kill the process using the port (example for port 9081):
lsof -ti:9081 | xargs kill -9

# Or change the port in docker-compose.yml
```

### Service Health Check Failures

**PostgreSQL not ready:**
```bash
# Check PostgreSQL logs
cd ndx
docker-compose logs postgres

# Restart PostgreSQL
docker-compose restart postgres
```

**ThunderID timeout:**
```bash
# Check ThunderID logs (db-init and setup run once and exit; thunderid is the long-running server)
docker-compose logs thunderid thunderid-setup thunderid-db-init

# Or allocate more memory to Docker (increase to 4GB+)
```

### Python/Ballerina Issues

**Python dependencies missing:**
```bash
cd members/rgd/data-sources/rgd-api
pip install -r requirements.txt
```

**Ballerina build errors:**
```bash
cd members/drp/data-sources/drp-api-adapter
bal clean
bal build
```

### Script Permission Errors

```bash
# Make all shell scripts executable
chmod +x init.sh
chmod +x members/run-member-services.sh
chmod +x members/rgd/data-sources/rgd-api/start.sh
```

### jq Command Not Found

**macOS:**
```bash
brew install jq
```

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install jq
```

**Windows:**
Download from [stedolan/jq](https://stedolan.github.io/jq/download/) and add to PATH

## Stopping Services

### Using init.sh

If you started services with `./init.sh`, simply press `Ctrl+C` in the terminal where the script is running. The cleanup trap will automatically:

1. Stop all member services
2. Stop all Docker Compose services
3. Clean up resources (based on `CLEAN_START` setting)

**Volume Cleanup Behavior:**

- By default (`CLEAN_START=true`), volumes are removed to ensure a fresh start
- With `CLEAN_START=false`, volumes are preserved to keep your data between runs

```bash
# Example: Preserve data when stopping
CLEAN_START=false ./init.sh
# Then press Ctrl+C to stop - data will be preserved
```

### Manual Cleanup

If you need to stop services manually:

```bash
# Stop Docker Compose services (preserve volumes)
cd ndx
docker-compose down

# Stop Docker Compose services and remove volumes (clean start)
cd ndx
docker-compose down -v

# Stop member services (if running in background)
# Find and kill the processes
ps aux | grep uvicorn  # RGD
ps aux | grep ballerina  # DRP

# Kill the processes
kill <PID>
```

### Complete Cleanup (Remove Data)

To remove all data and start fresh:

```bash
# Stop and remove all containers, networks, and volumes
cd ndx
docker-compose down -v

# Or manually remove specific volume
docker volume rm ndx_pg_data

# This will delete all database data and OAuth2 applications
# You'll need to run init.sh again to recreate everything
```

**Note:** If you encounter schema mismatch errors (like "invalid UUID length"), it's usually because the database wasn't properly initialized. Use `docker-compose down -v` to remove the old volume and start fresh.

## Next Steps

Once your setup is complete and verified:

1. **Explore the GraphQL API**: Check out the [API Documentation](README.md#api-documentation)
2. **Understand the Architecture**: Read about the [Technical Architecture](README.md#technical-architecture)
3. **Try the Business Workflow**: Follow [The Business Workflow](README.md#the-business-workflow) guide
4. **Add New Data Sources**: Learn how to [Add a New Data Source](README.md#adding-a-new-data-source)
5. **Develop Client Applications**: Build applications that consume federated data

## Getting Help

If you encounter issues not covered in this guide:

1. Check the [main README](README.md) for additional documentation
2. Review service logs: `docker-compose logs <service-name>`
3. Open an issue on [GitHub Issues](https://github.com/opendif/opendif-farajaland/issues)
4. Ask in [GitHub Discussions](https://github.com/opendif/opendif-farajaland/discussions)

## Configuration Files

Key configuration files you may need to modify:

- `ndx/docker-compose.yml` - Infrastructure services configuration
- `ndx/fl-config.json` - Orchestration Engine data source configuration
- `ndx/schema.graphql` - Unified GraphQL schema
- `ndx/.env` - Environment variables for NDX services
- `ndx/config/apisix/conf.yaml` - API Gateway configuration
- `ndx/config/thunderid/deployment.yaml` - FUDI/ThunderID configuration
- `ndx/config/thunderid/bootstrap/02-admin-cli.sh` - ThunderID bootstrap script (creates the ADMIN_CLI management client)

## Advanced Configuration

### Enabling Additional Services

The `docker-compose.yml` includes optional services that are disabled by default. To enable them, uncomment the service definition in `ndx/docker-compose.yml` and restart:

```bash
cd ndx
docker-compose up -d
```

### Custom Environment Variables

Create or modify `ndx/.env`:

```bash
OE_CONFIG_PATH=./fl-config.json
OE_SCHEMA_PATH=./schema.graphql
ENVIRONMENT=local
DATABASE_URL=postgresql://exchange:exchange@postgres:5432/exchange_service
```

### Production Deployment

For production deployments:

1. Enable TLS/SSL for all services
2. Change default passwords and secrets
3. Use proper secrets management (e.g., HashiCorp Vault)
4. Harden ThunderID configuration (rotate `ADMIN_PASSWORD`/`ADMIN_CLI_SECRET`, use a real SMTP server, use a CA-signed TLS certificate)
5. Set up monitoring and logging
6. Configure proper backup strategies

See the [Security & Privacy](README.md#security--privacy) section in the main README for production recommendations.