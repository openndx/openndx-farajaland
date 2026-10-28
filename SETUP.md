# OpenNDX Farajaland – Setup Guide

This guide will help you set up and run the OpenNDX Farajaland reference implementation on your local machine.

The PDP, Consent Engine, Consent Portal and Orchestration Engine images are pinned
to OpenNDX **v0.6.0**. ThunderID remains at **1.0.1**, as in the upstream release.
The passport app is built from this checkout at startup so it requests the OAuth
audience required by the upgraded Orchestration Engine.

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

### 2. Hostname Resolution (No Action Needed)

**No `/etc/hosts` changes are required.**

ThunderID's OIDC issuer is `http://localhost:8090`. Your browser reaches it
directly, and the containers reach ThunderID over the Docker network — so a single
issuer works everywhere with no host-file edits and no host-IP detection.

ThunderID runs over HTTP with `server.http_only: true` in
`ndx/config/thunderid/deployment.yaml`. Browser login, discovery, token requests
and container-side JWKS fetches all use HTTP; no certificate exception is needed.

After switching an existing stack from HTTPS, restart it through `init.sh` so
the containers and APISIX routes pick up the HTTP URLs. Use a fresh browser
session to discard login state for the previous issuer. Changing only the
protocol does not require deleting database volumes.

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
   - ThunderID (with the API Gateway/Consent Portal M2M+SPA clients and CORS
     all provisioned automatically as part of its own startup - see
     `ndx/config/thunderid/bootstrap/`)
3. ✅ Waits for services to be healthy
4. ✅ Registers the Passport Application (a data-consumer app) and a demo
   citizen user - unlike the infra apps above, these happen as explicit
   runtime steps (minting an admin token and calling ThunderID's `/import`
   API), since onboarding a data-consumer application or a citizen is meant
   to happen after the exchange is already up, not as part of its own boot
   sequence (see `ndx/config/thunderid/data-consumers/` and
   `ndx/config/thunderid/demo-citizens/`)
5. ✅ Extracts ThunderID's signing key and registers API routes in APISIX
6. ✅ Starts member data source services:
   - RGD API (Python/FastAPI)
   - DRP API Adapter (Ballerina)
7. ✅ Starts client applications:
   - Passport Application Frontend (http://localhost:3000)
   - Consent Portal Frontend (http://localhost:5173)
8. ✅ **Displays Passport Application credentials and next steps**

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
http://localhost:8090/oauth2/token

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

## End-to-End Upgrade Test

### Start the stack

From the repository root, start Docker Desktop, then run:

```bash
CLEAN_START=false ./init.sh
```

Keep this terminal running. `CLEAN_START=false` preserves data when you stop the
script. If you have volumes from an older installation, follow
[Upgrading an Existing Environment](#upgrading-an-existing-environment) first;
its reset command deletes local database data. Use a private browser window for
this test to avoid stale login sessions.

In another terminal, from the repository root:

```bash
docker compose -f ndx/docker-compose.yml ps -a
curl -sS http://localhost:3000/api/health
```

Expected: the OpenNDX services are running and healthy, the two ThunderID init/setup
containers have exited with code 0, and the passport health endpoint returns
`"status":"ok"`. The published RGD v0.1.0 image may report unhealthy even while
serving GraphQL requests; the data checks below verify it separately.

Open `http://localhost:8090` to check that ThunderID is reachable.
Allow popups from `http://localhost:3000` so the passport app can open consent requests.

### Test the browser flow

1. Open `http://localhost:3000/login` directly. This is the demo applicant login:
   keep the prefilled SLUDI value and OTP (`232323`), then click **Continue** and
   **Complete Login**. This simulated OTP flow selects the demo record identified
   by `nayana@opensource.lk`; it does not send an SMS.
2. On the application form, click **Load My Details**. With no approved consent,
   a Consent Portal popup should open. Personal details must remain unavailable
   until you approve.
3. Sign in to ThunderID from the Consent Portal using **nayana** / **Abc12#45**
   (unless you changed `MOCK_USER_PASSWORD`). This is separate from the mock
   applicant login above. Review the requested fields and click **Approve**.
4. The passport app should retry automatically and fill the form. Check surname
   **Samaranayake**, other names **Nayana**, address
   **105 Bauddhaloka Mawatha, Colombo 00400**, profession **Software Engineer**,
   birth certificate **BR2025001**, and birthplace **Colombo General Hospital**.
   These combine DRP and RGD records. The fixtures contain different
   names for the same owner: DRP's full name is Nayana Samaranayake and RGD's name
   is Nuwan Fernando.
5. Open `http://localhost:5173/consents` in another tab, select the approved
   passport consent, and revoke it. Return to the passport app, reload the page,
   and click **Load My Details** again. It must request consent again, rather
   than fetching fresh data under the revoked grant. Previously rendered data
   is not erased by revocation.
6. Deny the new pending request. The app must not receive fresh provider data.
   Reload the passport page before starting a later request, which you can
   approve to restore access.

This verifies the exchange integration through the browser. Passport submission
and payment screens are demo UI flows, not additional OpenNDX service checks.

### Test the exchange through the passport API

This request uses the same fields as **Load My Details**, so switching between
browser and API tests does not change the consent's requested field set. The
passport backend obtains the OAuth token and calls APISIX, OE, PDP, CE and the
providers for you.

```bash
NDX_TEST_REQUEST='{
  "query": "query GetPersonInfo($nic: String!) { personInfo(nic: $nic) { fullName name otherNames address profession dateOfBirth sex birthInfo { birthRegistrationNumber birthPlace district } } }",
  "variables": {"nic": "nayana@opensource.lk"}
}'

curl -sS http://localhost:3000/api/graphql \
  -H 'Content-Type: application/json' \
  --data "$NDX_TEST_REQUEST" | jq .
```

Before approval, expect `errors[0].extensions.code` to be `CE_NOT_APPROVED`, with
an `extensions.consentPortalUrl`. Open that URL in the browser and approve as
`nayana`, then rerun the same command. Expect populated `data.personInfo` and no
GraphQL errors. After revocation, rerun it and expect `CE_NOT_APPROVED` again.
A GraphQL HTTP status of 200 alone does not mean success: inspect `errors`.

### Check v0.6.0 authentication

The public GraphQL endpoint requires a bearer token. A request without one must
return **401**:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' \
  http://localhost:9081/public/graphql \
  -H 'Content-Type: application/json' \
  --data "$NDX_TEST_REQUEST"
```

To call the exchange directly with the default demo client, request OE's resource
and scope explicitly:

```bash
NDX_TEST_TOKEN=$(curl -sS http://localhost:8090/oauth2/token \
  -u "passport-app:${PASSPORT_CLIENT_SECRET:-1234}" \
  --data-urlencode 'grant_type=client_credentials' \
  --data-urlencode 'resource=http://api.openndx.local' \
  --data-urlencode 'scope=getdata' | jq -er '.access_token')

curl -sS http://localhost:9081/public/graphql \
  -H "Authorization: Bearer $NDX_TEST_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "$NDX_TEST_REQUEST" | jq .
```

Expected: the same consent/data behavior as the passport proxy. Use your
configured client secret if you changed it.

### Confirm consent and audit persistence

From the repository root:

```bash
docker compose -f ndx/docker-compose.yml exec -T postgres \
  psql -U exchange -d testdb2 -c \
  "SELECT owner_id, app_id, status, updated_at FROM consent_records ORDER BY updated_at DESC;"

docker compose -f ndx/docker-compose.yml exec -T postgres \
  psql -U exchange -d audit_db -c \
  "SELECT count(*) AS audit_events FROM audit_logs;"
```

Expected: consent records for owner `nayana@opensource.lk` and app `passport-app`,
with statuses matching your actions, and an audit count greater than zero that
increases as you make requests. Audit writes are asynchronous; allow a few seconds.
These commands use the checkout's default database user and database names.

If a step fails, inspect the relevant logs:

```bash
docker compose -f ndx/docker-compose.yml logs --tail=100 \
  orchestration-engine consent-engine policy-decision-point thunderid audit-service
docker logs --tail=100 online-passport-app
```

For browser-only failures, check Developer Tools for popup blocking, stale HTTPS
login sessions, and failing requests. A successful API test with a failed browser flow
means the browser login/popup integration still needs investigation.

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
# Run from the host shell, which reaches ThunderID at the published localhost:8090
# port - no /etc/hosts entry needed.

# Mint a management token from the ADMIN_CLI client created during bootstrap
TOKEN=$(curl -sS -u "ADMIN_CLI:${ADMIN_CLI_SECRET:-1234}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" -d "scope=system" \
  --data-urlencode "resource=https://localhost:8090/mcp" \
  http://localhost:8090/oauth2/token | jq -r .access_token)

# Use $TOKEN as a Bearer token against http://localhost:8090/applications
# (POST) to create an M2M application for the API Gateway and an SPA
# application for the Consent Portal. Note down the client IDs and secrets.
```

Or simply run `./init.sh`, which performs all of this automatically.

The System resource's `https://localhost:8090/mcp` identifier is fixed in
ThunderID 1.0.1, including in HTTP mode. It is an OAuth audience string; the
management token and application API requests still connect over HTTP.

### Step 3: Register API Gateway Routes

Register the APISIX routes. APISIX verifies each token's RS256 signature locally
against ThunderID's signing public key, so first extract that key from the
ThunderID container:

```bash
# Extract ThunderID's signing public key (PEM)
docker cp "$([ -d ndx ] && cd ndx; docker-compose ps -q thunderid):/opt/thunderid/config/certs/signing.cert" /tmp/signing.cert
PUBLIC_KEY=$(openssl x509 -in /tmp/signing.cert -pubkey -noout)

# Register the OE route (jq inlines the PEM with correct JSON escaping)
jq -n --arg pk "$PUBLIC_KEY" '{
    uri: "/public/*",
    methods: ["GET", "POST"],
    upstream: { type: "roundrobin", nodes: { "orchestration-engine:4000": 1 } },
    plugins: {
      "openid-connect": {
        client_id: "ndx-api-gateway",
        client_secret: "1234",
        discovery: "http://thunderid:8090/.well-known/openid-configuration",
        bearer_only: true,
        public_key: $pk,
        token_signing_alg_values_expected: "RS256",
        claim_validator: { issuer: { valid_issuers: ["http://localhost:8090"] } },
        set_userinfo_header: true
      }
    },
    id: "oe-endpoint"
  }' | curl --location --request PUT http://localhost:9180/apisix/admin/routes \
    --header "Content-Type: application/json" \
    --header "X-API-KEY: QuNGwapKysRvHfUtNkQFbUaGiiYeOcGo" \
    --data @-
```

> **Why local (public_key) validation instead of JWKS?** With the issuer set to
> `http://localhost:8090`, the JWKS URL advertised in the discovery document is
> `http://localhost:8090/oauth2/jwks`, which the APISIX container cannot reach
> (`localhost` there means APISIX itself). Verifying the RS256 signature locally
> against ThunderID's public key needs no network call to the IdP — the `localhost`
> issuer is only ever compared as a string (`valid_issuers`), never dereferenced.
> `client_id` is required by the plugin schema but unused for local verification.

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

### Upgrading an Existing Environment

This checkout targets OpenNDX **v0.6.0** (`0.6.0` container tags). It builds on
these upstream guides:

- [v0.4.0 to v0.5.0](https://github.com/openndx/openndx-core/blob/main/docs/MIGRATION-v0.4-to-v0.5.md)
- [v0.5.0 to v0.6.0](https://github.com/openndx/openndx-core/blob/main/docs/MIGRATION-v0.5-to-v0.6.md)

The demo runs PDP, Consent Engine, Orchestration Engine and Consent Portal.
Portal Backend, Admin Portal and Member Portal are not deployed by this stack.
The legacy Portal Backend tables in `opendif_schema.sql` are not migrated here.
If you deploy Portal Backend separately, follow both guides for its organization
units, `members.ou_id` migration, management client, scopes and YAML configuration.

**Configuration changes in v0.6.0:**

- `ndx/config/openndx/{pdp,ce,oe}.yaml` configure the three Go services.
  Compose mounts each at `/app/config/config.yaml`. Environment values affect a
  service only through an explicit `{{env:NAME}}` placeholder in its YAML file.
  Logging and database settings, TLS options and token verification use these files.
- `OE_CONFIG_PATH=./config/openndx/oe.yaml` replaces `./fl-config.json` in
  `ndx/.env`. The old JSON is retained only as a rollback reference; v0.6.0 does
  not load it. Preserve your v0.5.0 schema and Compose/env files before upgrading.
- `ndx/schema.graphql` is mounted at `/app/config/schema.graphql`, next to
  OE's config. `providerKey` and the unused source-argument directive are removed.
  DMT is still a future provider: its unconfigured vehicle fields and mapping
  have been removed. The passport query continues to use DRP and RGD.
- Provider IDs remain **`drp-schema-v1`** and **`abc-212`**, matching the existing
  database and PDP grants. The renamed IDs in upstream's local sample are not
  required for this deployment. Both mappings declare `targetArgType: "ID!"`
  because the provider APIs take `ID!` while the consumer schema takes `String!`.
- OE explicitly sets `pdp.url` and `consentEngine.url` (ending in
  `/internal/api/v1`). Keep these keys: an empty PDP URL disables policy and
  consent checks. Provider secrets now come from `DRP_API_KEY`, `RGD_CLIENT_ID`
  and `RGD_CLIENT_SECRET` in `ndx/.env`; retain your existing values there.
  Argus authentication now comes from `audit.apiKey` using `ARGUS_API_KEY`.
- CE requires the issuer, audience and JWKS URL. Its audience remains
  `CONSENT_PORTAL_APP`; `idp.subjectClaim` remains `email` because this demo's
  data-owner identifiers are email addresses. OE's separate audience remains
  `http://api.openndx.local`. Keep certificate verification enabled.
- Health probes use `/health`. CE's old `/api/v1/health` and
  `/internal/api/v1/health` are removed; OE's health body is now
  `{"service":"orchestration-engine","status":"healthy"}`. Status-code probes
  continue to work. OE no longer handles CORS: the browser uses the passport
  backend proxy, which makes the server-side request to OE.
- These services connect to the existing database without startup migrations.
  The services wait for PostgreSQL/ThunderID health before starting.

**Changes carried forward from v0.5.0:** consumer tokens request OE's resource
and `getdata` scope; the passport app is built locally with that token request.
`init.sh` imports its client and role at runtime. CE routes expose both
`/api/v1/consents` and `/api/v1/consents/*`, and OE uses a file schema instead of
its removed `/sdl` API/database. GraphQL responses can contain both `data` and
`errors`; fields that failed are unavailable, and the app surfaces the error.

**Upgrade without deleting data:** back up PostgreSQL and ThunderID, save your
old configuration/schema for rollback, and stop any running `init.sh` gracefully
with its volume cleanup disabled. Its default `CLEAN_START=true` deletes volumes
on exit; always use `CLEAN_START=false` for a persistent environment. If an old
`init.sh` is already running with the default, back up before stopping it.
Then run from the repository root:

```bash
cd ndx
docker compose config --quiet
docker compose pull policy-decision-point consent-engine orchestration-engine consent-portal
docker compose up -d
cd ..
CLEAN_START=false ./init.sh
```

`init.sh` also registers the passport app, demo citizen and gateway routes;
`docker compose up` alone does not perform those steps. The v0.5.0 to v0.6.0
upgrade needs no database migration or volume reset. If you use an alternate
Compose env file, also update its OE path and provider credentials.

Verify `/health` and startup logs, check the unauthenticated request returns
`401`, and run the passport query above before consent, after approval, and
after revocation. Confirm an application without a policy grant gets
`PDP_NOT_ALLOWED`, authorized queries fetch data from both DRP and RGD, and
Argus records the requests. An HTTP `200` alone does not prove authorization.

To roll back to v0.5.0, restore the saved v0.5.0 Compose/env files, JSON config
and schema with `providerKey`, then redeploy the v0.5.0 images. Database data
can stay in place. If upgrading from v0.4.0 with a separate Portal Backend,
its member migration also requires the database backup for rollback.

For installations older than OpenNDX v0.3.0 / ThunderID 1.0.1, follow the
intermediate migration steps first: CE removed `owner_email`, and ThunderID
1.0.1 changed its SQLite database filenames. Those older changes are separate
from this v0.6.0 configuration update.

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
- `ndx/config/openndx/{pdp,ce,oe}.yaml` - Backend service configuration
- `ndx/schema.graphql` - Unified GraphQL schema
- `ndx/.env` - Environment variables for NDX services
- `ndx/config/apisix/conf.yaml` - API Gateway configuration
- `ndx/config/thunderid/deployment.yaml` - FUDI/ThunderID configuration
- `ndx/config/thunderid/bootstrap/02-admin-cli.yaml` - ThunderID ADMIN_CLI management client

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
OE_CONFIG_PATH=./config/openndx/oe.yaml
OE_SCHEMA_PATH=./schema.graphql
ENVIRONMENT=local
DB_USER=exchange
DB_PASSWORD=<your-password>
DB_SSLMODE=disable
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
