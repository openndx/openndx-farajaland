# OpenNDX Farajaland – Technical Architecture

This document provides comprehensive technical architecture details for the OpenNDX Farajaland reference implementation, including system components, data flow, integration patterns, and deployment considerations.

## Table of Contents

- [Overview](#overview)
- [High-Level Architecture](#high-level-architecture)
- [Architecture Layers](#architecture-layers)
- [Core Components](#core-components)
- [Data Source Adapters](#data-source-adapters)
- [Member Organizations](#member-organizations)
- [Key Features](#key-features)
- [Security Architecture](#security-architecture)
- [Data Flow](#data-flow)
- [Deployment Architecture](#deployment-architecture)
- [Scalability & Performance](#scalability--performance)

---

## Overview

OpenNDX Farajaland implements a **federated data exchange architecture** that enables secure, consent-based data sharing across government agencies without centralizing data storage. The architecture prioritizes:

- **Data Sovereignty**: Each agency maintains control over their data
- **Citizen Privacy**: Explicit consent required for all data access
- **Interoperability**: Standardized GraphQL interface for all consumers
- **Security**: Multi-layered security with authentication, authorization, and audit trails
- **Scalability**: Horizontal scaling of all components

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Client Applications                      │
│                    (e.g., Passport Application)                 │
└────────────────────────────┬────────────────────────────────────┘
                             │ GraphQL Query
                             │ (with citizen context)
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│                      API Gateway (APISIX)                       │
│              Authentication, Rate Limiting, Routing             │
│                         Port: 9081                              │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│                   Orchestration Engine (OE)                     │
│              GraphQL Federation & Query Planning                │
│                         Port: 4000                              │
└──────┬──────────────────────┬────────────────────┬──────────────┘
       │                      │                    │
       ↓                      ↓                    ↓
┌──────────────┐    ┌─────────────────┐   ┌──────────────────┐
│   Consent    │    │ Policy Decision │   │  Data Sources    │
│   Engine     │    │  Point (PDP)    │   │                  │
│              │    │                 │   │  ┌────────────┐  │
│ Port: 8081   │    │  Port: 8082     │   │  │ DRP (9090) │  │
│              │    │                 │   │  └────────────┘  │
└──────────────┘    └─────────────────┘   │  ┌────────────┐  │
                                          │  │ RGD (8080) │  │
                                          │  └────────────┘  │
                                          │  ┌────────────┐  │
                                          │  │ DMT (TBD)  │  │
                                          │  └────────────┘  │
                                          └──────────────────┘
       ┌──────────────────────┴─────────────────────┐
       ↓                                            ↓
┌──────────────┐                            ┌──────────────┐
│  PostgreSQL  │                            │FUDI/ThunderID│
│   Database   │                            │              │
│              │                            │              │
│ Port: 5432   │                            │ Port: 8090   │
└──────────────┘                            └──────────────┘
```

---

## Architecture Layers

The OpenNDX Farajaland architecture is organized into five distinct layers:

### 1. Client Layer
**Purpose**: Consumer applications that need federated data

**Components**:
- Web applications (e.g., Passport Application Portal)
- Mobile applications
- Backend services
- Third-party integrations

**Responsibilities**:
- Initiate data requests via GraphQL
- Handle consent flow redirects
- Display user interfaces
- Manage application state

**Integration Pattern**:
```
Client → GraphQL Query → API Gateway → Orchestration Engine
Client ← Consent URL ← API Gateway ← Orchestration Engine (if no consent)
Client → Consent Portal → FUDI Authentication → Consent Grant
Client → GraphQL Query (retry) → API Gateway → Data Response
```

---

### 2. Gateway Layer
**Purpose**: Entry point for all client requests

**Component**: Apache APISIX API Gateway

**Responsibilities**:
- **Request Routing**: Route requests to appropriate upstream services
- **Authentication**: Validate OAuth2/JWT tokens
- **Rate Limiting**: Prevent abuse and ensure fair usage
- **Load Balancing**: Distribute traffic across service instances
- **TLS Termination**: Handle HTTPS encryption
- **Logging & Monitoring**: Track all API calls

**Ports**:
- `9081`: HTTP/HTTPS traffic (client-facing)
- `9180`: Admin API (internal management)

**Security Features**:
- OAuth2/OIDC integration with FUDI
- API key validation
- IP whitelisting/blacklisting
- Request/response transformation
- CORS handling

---

### 3. Orchestration Layer
**Purpose**: Core logic for query federation and coordination

**Component**: Orchestration Engine (Go)

**Responsibilities**:
- **GraphQL Federation**: Parse and plan federated queries
- **Query Splitting**: Decompose queries into sub-queries per data source
- **Consent Verification**: Check with Consent Engine before data access
- **Policy Enforcement**: Verify access policies with PDP
- **Data Aggregation**: Combine results from multiple sources
- **Error Handling**: Manage partial failures and retries
- **Audit Logging**: Record all data access events

**Port**: 4000

**Key Operations**:
1. Receive GraphQL query from API Gateway
2. Parse query and identify required data sources
3. Check consent status for citizen + consumer + data scope
4. If no consent: Return consent portal URL
5. If consent exists: Verify policies with PDP
6. Execute sub-queries to data sources in parallel
7. Aggregate results and return unified response
8. Log audit trail

---

### 4. Policy & Consent Layer
**Purpose**: Enforce data governance and citizen consent

#### Consent Engine (Port: 8081)
**Technology**: Go

**Responsibilities**:
- Store and manage citizen consent records
- Validate consent scope (which fields, from which sources)
- Check consent expiry and status
- Provide consent portal URLs for new consent requests
- Support consent revocation
- Maintain consent audit trail

**Consent Record Structure**:
```json
{
  "consentId": "consent_abc123",
  "citizenId": "123456789V",
  "consumerId": "DIE",
  "dataScope": {
    "providers": ["RGD", "DRP"],
    "fields": ["fullName", "dateOfBirth", "address"]
  },
  "purpose": "Passport Application",
  "grantedAt": "2025-11-27T10:30:00Z",
  "expiresAt": "2025-12-27T10:30:00Z",
  "status": "ACTIVE"
}
```

#### Policy Decision Point (Port: 8082)
**Technology**: Go

**Responsibilities**:
- Evaluate access control policies (RBAC, ABAC)
- Enforce time-based restrictions
- Validate purpose limitations
- Check data classification rules
- Support policy versioning

**Policy Evaluation Flow**:
```
Request Context → Policy Engine → Evaluate Rules → Decision (PERMIT/DENY)
```

---

### 5. Data Source Layer
**Purpose**: Government department APIs providing citizen data

**Components**:
- Data Provider APIs (RGD, DRP, DMT)
- Adapters (for non-GraphQL sources)
- Authentication services
- Data stores (managed by providers)

**Integration Patterns**:
- **Native GraphQL**: Direct integration (e.g., RGD)
- **Adapter Pattern**: Translation layer for REST/SOAP (e.g., DRP)

---

## Core Components

### NDX (National Data Exchange)

The NDX is the core infrastructure layer providing orchestration, consent management, and policy enforcement.

| Component                 | Technology    | Port      | Purpose                                              | Status     |
|---------------------------|---------------|-----------|------------------------------------------------------|------------|
| **Orchestration Engine**  | Go            | 4000      | GraphQL federation, query planning, data aggregation | Production |
| **Consent Engine**        | Go            | 8081      | Citizen consent management, verification             | Production |
| **Policy Decision Point** | Go            | 8082      | Access control policy evaluation (RBAC/ABAC)         | Production |
| **API Gateway**           | Apache APISIX | 9081/9180 | Request routing, rate limiting, authentication       | Production |
| **Database**              | PostgreSQL    | 5432      | Persistent storage for consent, policies, audit logs | Production |
| **Service Registry**      | etcd          | 2379      | Service discovery, configuration management          | Production |

### Supporting Infrastructure

| Component                    | Technology           | Port | Purpose                              | Status   |
|------------------------------|----------------------|------|--------------------------------------|----------|
| **FUDI (Identity Provider)** | ThunderID             | 8090 | Citizen authentication, OAuth2/OIDC  | Optional |
| **Monitoring**               | Prometheus + Grafana | TBD  | Metrics collection and visualization | Planned  |
| **Logging**                  | ELK Stack            | TBD  | Centralized log aggregation          | Planned  |
| **Tracing**                  | Jaeger               | TBD  | Distributed request tracing          | Planned  |

---

## Data Source Adapters

### The Challenge

OpenNDX communicates with data providers using **GraphQL** for all egress calls. However, many existing government systems use legacy protocols like:
- REST (JSON/XML)
- SOAP
- XML-RPC
- Custom proprietary protocols

### The Solution: Adapter Pattern

**Adapters** are lightweight translation layers that convert GraphQL queries from NDX into the data source's native protocol.

### Architecture

```
┌──────────────────┐         ┌──────────────────┐         ┌──────────────────┐
│                  │ GraphQL │                  │  REST   │                  │
│  Orchestration   │────────>│     Adapter      │────────>│  Legacy Data     │
│     Engine       │         │   (Translator)   │         │     Source       │
│                  │<────────│                  │<────────│                  │
└──────────────────┘ GraphQL └──────────────────┘  JSON   └──────────────────┘
                             Response
```

### Example: DRP Adapter

The **DRP (Department of Registration of Persons)** has an existing REST API that returns JSON. The DRP adapter:

1. **Receives** GraphQL queries from NDX
2. **Parses** the GraphQL query structure
3. **Translates** to REST API calls (GET/POST with appropriate parameters)
4. **Calls** the original DRP REST API
5. **Transforms** REST JSON responses back to GraphQL format
6. **Returns** GraphQL response to NDX

**Technology**: Ballerina (chosen for its built-in support for protocol translation)

### Adapter Implementation Patterns

#### Pattern 1: GraphQL to REST Translation
```ballerina
service /graphql on new http:Listener(9090) {
    resource function post query(http:Request req) returns json|error {
        // Parse GraphQL query
        json query = check req.getJsonPayload();

        // Extract parameters
        string nic = check query.variables.nic;

        // Call REST API
        http:Client restClient = check new("http://drp-legacy-api:8080");
        json restResponse = check restClient->get("/person/" + nic);

        // Transform to GraphQL response format
        return {
            "data": {
                "person": restResponse
            }
        };
    }
}
```

#### Pattern 2: SOAP to GraphQL Translation
```
GraphQL Request → Parse → Build SOAP Envelope → Call SOAP Service →
Parse SOAP Response → Transform to GraphQL → Return
```

### When You Need an Adapter

✅ Your data source uses REST, SOAP, XML-RPC, or other non-GraphQL protocols
✅ Your existing API cannot be modified
✅ You need protocol translation without changing backend systems
✅ You want to maintain separation of concerns

### When You Don't Need an Adapter

❌ Your data source already speaks GraphQL natively (like RGD)
❌ You can directly modify your data source to support GraphQL
❌ You're building a new data source from scratch

### Adapter Development Guidelines

1. **Language Choice**: Use any language (Ballerina, Go, Python, Node.js, Java)
2. **GraphQL Schema**: Implement the schema defined in `ndx/schema.graphql`
3. **Error Handling**: Properly map source errors to GraphQL errors
4. **Authentication**: Support OAuth2 or API key authentication
5. **Logging**: Log all requests for audit purposes
6. **Testing**: Provide unit and integration tests
7. **Documentation**: Document the translation logic

---

## Member Organizations

This section provides technical details about member organizations in the ecosystem.

### Data Providers

Organizations that provide data as custodians. They expose data through standardized interfaces.

#### DRP - Department of Registration of Persons

**Architecture**:
- **API Type**: REST → GraphQL (via Adapter)
- **Technology Stack**: Ballerina (Adapter), REST API (Legacy)
- **Port**: 9090
- **Authentication**: API Key (Choreo platform)
- **Schema ID**: `drp-schema-v1`

**Data Model**:
```graphql
type Person {
  nic: String!
  fullName: String!
  otherNames: [String]
  permanentAddress: String!
  profession: String
}
```

**Integration Pattern**: Adapter-based
- Legacy REST API remains unchanged
- DRP Adapter translates GraphQL ↔ REST
- NDX communicates only with the adapter

**Endpoints**:
- GraphQL: `http://localhost:9090/graphql`
- Health Check: `http://localhost:9090/health`

**Location**: `members/drp/data-sources/drp-api-adapter/`

---

#### RGD - Registrar General's Department

**Architecture**:
- **API Type**: Native GraphQL
- **Technology Stack**: Python (FastAPI), Strawberry GraphQL
- **Port**: 8080
- **Authentication**: OAuth2 Client Credentials
- **Schema ID**: `abc-212`

**Data Model**:
```graphql
type BirthInfo {
  birthRegistrationNumber: String!
  dateOfBirth: String!
  birthPlace: String!
  district: String!
  sex: String!
}
```

**Integration Pattern**: Native GraphQL
- Direct GraphQL endpoint
- No adapter required
- OAuth2 token-based authentication

**Endpoints**:
- GraphQL: `http://localhost:8080/graphql`
- OAuth2 Token: `http://localhost:8080/oauth2/token`
- Health Check: `http://localhost:8080/health`

**Location**: `members/rgd/data-sources/rgd-api/`

---

#### DMT - Department of Motor Traffic

**Architecture**: (Planned)
- **API Type**: TBD (likely REST → GraphQL via Adapter)
- **Technology Stack**: TBD
- **Port**: TBD
- **Authentication**: TBD
- **Schema ID**: `dmt-schema-v1`

**Data Model**:
```graphql
type Vehicle {
  regNo: String!
  make: String!
  model: String!
  year: Int!
  class: VehicleClass!
}

type VehicleClass {
  className: String!
  classCode: String!
}
```

**Status**: Schema defined, implementation pending

**Location**: `members/dmt/` (to be implemented)

---

### Data Consumers

Organizations that consume federated data to deliver citizen services.

#### DIE - Department of Immigration and Emigration

**Architecture**:
- **Application Type**: Web Application
- **Technology Stack**: TBD (React/Vue.js + Node.js backend)
- **Integration**: GraphQL queries to NDX
- **Authentication**: OAuth2 with FUDI

**Data Requirements**:
- Citizen identity (from RGD)
- Current address and profession (from DRP)
- Vehicle ownership *(future)* (from DMT)

**Integration Pattern**:
```
DIE App → GraphQL Query → NDX API Gateway
    ↓
Check Consent → No Consent Found
    ↓
Return Consent Portal URL → DIE redirects citizen
    ↓
Citizen authenticates via FUDI → Grants consent
    ↓
Redirect back to DIE → Retry GraphQL query
    ↓
Consent Verified → Fetch data from RGD + DRP → Return aggregated data
```

**Location**: `members/die/applications/passport-app/` (planned)

---

## Key Features

### Privacy & Security

**Consent-Based Access**:
- All data access requires explicit citizen consent
- Consent has defined scope (specific fields + sources)
- Consent has expiry date
- Citizens can revoke consent at any time

**Authentication & Authorization**:
- **Service-to-Service**: OAuth2 Client Credentials
- **Citizen Authentication**: FUDI/ThunderID with OIDC
- **API Key**: Simplified authentication for trusted services
- **Policy-Based Access Control**: RBAC and ABAC via PDP

**Encryption**:
- TLS/HTTPS for all communications
- Database encryption at rest (optional)
- Token encryption for sensitive data

**Audit Logging**:
- All data access events logged
- Immutable audit trail
- Retention policies for compliance
- Query audit with citizen ID, consumer, timestamp, data accessed

---

### Data Federation

**Single API Endpoint**:
- Consumers query one GraphQL endpoint
- No need to integrate with each provider separately
- Simplified client development

**Automatic Query Federation**:
- Orchestration Engine splits queries across sources
- Parallel execution for performance
- Intelligent caching for frequently accessed data

**Field-Level Mapping**:
```graphql
type PersonInfo {
    fullName: String @sourceInfo(
        schemaId: "drp-schema-v1",
        providerField: "person.fullName"
    )
    dateOfBirth: String @sourceInfo(
        schemaId: "abc-212",
        providerField: "getPersonInfo.birthDate"
    )
}
```

**Cross-Agency Correlation**:
- Data correlated by citizen identifier (NIC)
- Automatic resolution of entity relationships
- Consistent data model across sources

---

### Developer Experience

**GraphQL Schema-Driven Development**:
- Single unified schema in `ndx/schema.graphql`
- Type-safe queries and responses
- Auto-generated documentation
- GraphQL playground for testing

**OpenAPI Compatibility**:
- Data sources can expose OpenAPI specs
- Adapter code generation from OpenAPI
- Swagger/OpenAPI documentation

**Docker-Based Development**:
- `docker-compose.yml` for local development
- All services containerized
- Easy setup with `./init.sh`

**Comprehensive Configuration**:
- `ndx/config/openndx/{pdp,ce,oe}.yaml` for backend settings
- Environment variables for secrets
- YAML configuration for APISIX

---

### Operational Excellence

**Health Checks**:
- All services expose `/health` endpoints
- Liveness and readiness probes
- Automated health monitoring

**Containerization**:
- All components run in Docker containers
- Kubernetes-ready deployment *(future)*
- Infrastructure as Code

**Scalability**:
- Horizontal scaling for all stateless services
- PostgreSQL replication for database
- etcd clustering for service discovery
- Load balancing via APISIX

**Monitoring & Observability** *(planned)*:
- Prometheus metrics collection
- Grafana dashboards
- Jaeger distributed tracing
- ELK stack for centralized logging

---

## Security Architecture

### Authentication Flow

#### Citizen Authentication (via FUDI)
```
1. Citizen accesses DIE application
2. DIE redirects to FUDI login
3. Citizen enters credentials (username/password)
4. FUDI validates credentials
5. Optional: MFA challenge
6. FUDI issues ID token + access token
7. DIE receives tokens via redirect
8. DIE stores session with tokens
```

#### Service-to-Service (OAuth2 Client Credentials)
```
1. Orchestration Engine needs to call RGD
2. OE sends client_id + client_secret to RGD token endpoint
3. RGD validates credentials
4. RGD issues access token (JWT)
5. OE includes token in Authorization header
6. RGD validates token on each request
```

#### API Key Authentication
```
1. DRP Adapter configured with API key
2. NDX includes API key in header: X-API-Key: xxx
3. Adapter validates API key
4. If valid, process request
```

---

### Authorization Model

**Consent-Based Authorization**:
- Primary authorization mechanism
- Citizen must grant consent for specific data access
- Consent checked before policy evaluation

**Policy-Based Authorization**:
- RBAC: Role-based access (admin, operator, viewer)
- ABAC: Attribute-based access (time, purpose, data classification)
- Policies defined in PDP configuration

**Multi-Layered Security**:
```
Layer 1: API Gateway (authentication, rate limiting)
    ↓
Layer 2: Orchestration Engine (consent verification)
    ↓
Layer 3: Policy Decision Point (policy evaluation)
    ↓
Layer 4: Data Source (authentication, authorization)
```

---

### Data Privacy

**Principles**:
- **Data Minimization**: Only requested fields returned
- **Purpose Limitation**: Data used only for stated purpose
- **Data Sovereignty**: Data never leaves source systems
- **Audit Trails**: All access logged and traceable
- **Consent Expiry**: Time-limited data access

**Privacy by Design**:
- No centralized data repository
- Queries executed in real-time
- No data caching (or TTL-based caching only)
- Consent required for all personal data

---

## Data Flow

### Standard Query Flow (With Consent)

```
┌─────────┐
│ Citizen │
└────┬────┘
     │ 1. Access DIE App
     ↓
┌──────────────┐
│  DIE App     │
└────┬─────────┘
     │ 2. GraphQL Query (GET personInfo)
     ↓
┌──────────────┐
│ API Gateway  │
└────┬─────────┘
     │ 3. Validate Token
     ↓
┌──────────────────┐
│ Orchestration    │
│    Engine        │
└────┬────┬────────┘
     │    │ 4. Check Consent
     │    ↓
     │ ┌──────────────┐
     │ │   Consent    │
     │ │   Engine     │
     │ └──────┬───────┘
     │        │ 5. Consent Found ✓
     │        ↓
     │ ┌──────────────┐
     │ │   Policy     │
     │ │   Decision   │
     │ │   Point      │
     │ └──────┬───────┘
     │        │ 6. Policy Permits ✓
     ↓        ↓
┌─────────────────────┐
│  Query Federation   │
│  - Sub-query to RGD │
│  - Sub-query to DRP │
└────┬────────┬───────┘
     │        │
     │ 7a.    │ 7b.
     ↓        ↓
┌─────────┐ ┌─────────┐
│   RGD   │ │   DRP   │
│   API   │ │ Adapter │
└────┬────┘ └────┬────┘
     │           │
     │ 8a.       │ 8b.
     ↓           ↓
┌─────────────────────┐
│  Data Aggregation   │
└──────────┬──────────┘
           │ 9. Unified Response
           ↓
      ┌─────────┐
      │ DIE App │
      └─────────┘
           │ 10. Display Data
           ↓
      ┌─────────┐
      │ Citizen │
      └─────────┘
```

---

### Consent Flow (No Consent Exists)

```
┌─────────┐
│ Citizen │
└────┬────┘
     │ 1. Access DIE App
     ↓
┌──────────────┐
│  DIE App     │
└────┬─────────┘
     │ 2. GraphQL Query
     ↓
┌──────────────────┐
│ Orchestration    │
│    Engine        │
└────┬─────────────┘
     │ 3. Check Consent
     ↓
┌──────────────┐
│   Consent    │
│   Engine     │
└────┬─────────┘
     │ 4. No Consent Found ✗
     │
     │ 5. Generate Consent Portal URL
     ↓
┌──────────────────┐
│ Orchestration    │
└────┬─────────────┘
     │ 6. Return URL (not data)
     ↓
┌──────────────┐
│  DIE App     │
└────┬─────────┘
     │ 7. Redirect to Consent Portal
     ↓
┌──────────────┐
│   Consent    │
│   Portal     │
└────┬─────────┘
     │ 8. Show login
     ↓
┌──────────────┐
│     FUDI     │
│ (ThunderID)  │
└────┬─────────┘
     │ 9. Authenticate
     ↓
┌─────────┐
│ Citizen │─────► 10. Enter credentials
└────┬────┘
     │ 11. MFA (if enabled)
     ↓
┌──────────────┐
│     FUDI     │
└────┬─────────┘
     │ 12. Issue token
     ↓
┌──────────────┐
│   Consent    │
│   Portal     │
└────┬─────────┘
     │ 13. Show consent screen
     ↓
┌─────────┐
│ Citizen │─────► 14. Grant consent
└────┬────┘
     │ 15. Consent recorded
     ↓
┌──────────────┐
│   Consent    │
│   Engine     │
└────┬─────────┘
     │ 16. Redirect back to DIE
     ↓
┌──────────────┐
│  DIE App     │
└────┬─────────┘
     │ 17. Retry GraphQL Query
     ↓
     (Follow Standard Query Flow)
```

---

## Deployment Architecture

### Local Development

**Setup**: `./init.sh` script
- Starts Docker Compose with all services
- Configures FUDI/ThunderID
- Registers API Gateway routes
- Starts member services

**Components**:
- All services run on localhost
- PostgreSQL for persistence
- etcd for service discovery
- APISIX for API gateway

---

### Production Deployment (Recommended)

#### Option 1: Kubernetes

**Architecture**:
```
Ingress Controller (NGINX/Traefik)
    ↓
APISIX API Gateway (Deployment + Service)
    ↓
Orchestration Engine (Deployment + Service)
    ├─ Consent Engine (Deployment + Service)
    ├─ Policy Decision Point (Deployment + Service)
    └─ Data Sources (External or in-cluster)

Supporting:
- PostgreSQL (StatefulSet + PVC)
- etcd (StatefulSet + PVC)
- ThunderID (StatefulSet + PVC)
```

**Benefits**:
- Auto-scaling based on load
- Self-healing (pod restarts)
- Rolling updates with zero downtime
- Service mesh integration (Istio/Linkerd)

---

#### Option 2: Docker Swarm

**Architecture**:
```
Load Balancer
    ↓
API Gateway (replicated service)
    ↓
Orchestration services (replicated)
    ↓
Data stores (persistent volumes)
```

**Benefits**:
- Simpler than Kubernetes
- Built-in load balancing
- Good for mid-scale deployments

---

#### Option 3: VM-Based

**Architecture**:
- Separate VMs for each component
- NGINX load balancer in front
- PostgreSQL primary + replicas
- Manual scaling

**Benefits**:
- Traditional operations model
- Fine-grained control
- Suitable for air-gapped environments

---

## Scalability & Performance

### Horizontal Scaling

**Stateless Services** (can be scaled infinitely):
- API Gateway (APISIX)
- Orchestration Engine
- Consent Engine
- Policy Decision Point

**Stateful Services** (require coordination):
- PostgreSQL (primary + read replicas)
- etcd (cluster mode)

### Performance Optimizations

**Query Optimization**:
- Parallel sub-query execution
- Query planning and optimization
- Field-level data fetching (no over-fetching)

**Caching** *(future)*:
- Redis for frequently accessed data
- TTL-based cache invalidation
- Cache key based on query + citizen ID

**Database Optimization**:
- Indexed queries on citizen ID
- Connection pooling
- Read replicas for query load

**Network Optimization**:
- Keep-alive connections
- HTTP/2 for multiplexing
- Compression (gzip/brotli)

### Capacity Planning

**Estimated Load** (per 1000 req/sec):
- API Gateway: 2-3 instances (2 vCPU, 4GB RAM each)
- Orchestration Engine: 3-5 instances (4 vCPU, 8GB RAM each)
- Consent Engine: 2-3 instances (2 vCPU, 4GB RAM each)
- PDP: 2-3 instances (2 vCPU, 4GB RAM each)
- PostgreSQL: 1 primary + 2 replicas (8 vCPU, 32GB RAM each)

---

## Next Steps

After understanding the architecture:

1. **Try it locally**: Follow the [Setup Guide](SETUP.md)
2. **Review the workflow**: Check the [Business Workflow](BUSINESS_WORKFLOW.md)
3. **Explore the API**: See [API Documentation](README.md#api-documentation)
4. **Add a data source**: Follow the [Development Guide](README.md#development)
5. **Deploy to production**: Plan your deployment architecture

---

For more information, return to the [main README](README.md).