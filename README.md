# National Data Exchange (NDX) For Farajaland Powered by OpenDIF

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![OpenDIF](https://img.shields.io/badge/OpenDIF-Reference%20Implementation-green.svg)](https://opendif.org)

The **National Data Exchange (NDX)** is a reference implementation of the **Open Data Interchange Framework (OpenDIF)** for the fictional country of Farajaland. NDX demonstrates secure, privacy-preserving data exchange across government agencies through a citizen-centric, consent-based approach.

## Table of Contents

- [Understanding the OpenDIF Ecosystem](#understanding-the-farajaland-ndx-ecosystem)
- [Example: Passport Application via NDX](#example-passport-application-via-ndx)
- [Member Organizations](#member-organizations)
- [Security & Privacy](#security--privacy)

## Understanding the Farajaland NDX Ecosystem

The Farajaland NDX ecosystem consists of various member organizations that participate in the data exchange network.

### Members of the Ecosystem

**Members** are organizations registered in the NDX ecosystem. Each member can:
- Have **multiple data sources** that provide data (making them data providers)
- Have **multiple applications** that consume data (making them data consumers)
- Be **both a provider and consumer** simultaneously

**Current Members**:
- **RGD (Registrar General's Department)**: Provides birth records and civil registration data
- **DRP (Department of Registration of Persons)**: Provides personal registration, address, and profession data
- **DMT (Department of Motor Traffic)**: Will provide vehicle registration data *(coming soon)*
- **DIE (Department of Immigration and Emigration)**: Consumes data for passport application processing

**Important Principle**: Member organizations that provide data are **custodians**, not owners. Citizens own their data. This is why consent is required before any data sharing occurs.

### The NDX: The Trust Fabric

The **NDX (National Data Exchange)** is the central infrastructure that:
- Provides a **single GraphQL endpoint** for all data consumers
- **Federates queries** across multiple data providers
- **Enforces consent** and policy rules
- Manages **authentication and authorization**
- Provides **audit trails** for all data access

### The Trusted Identity Provider

**FUDI (Farajaland Unique Digital Identity)** serves as Farajaland's trusted identity provider:
- A national digital identity platform powered by ThunderID
- All citizens have FUDI accounts registered in the system
- Provides secure authentication for the consent portal
- Issues tokens for authenticated sessions
- Integrates with the consent management flow

## Example: Passport Application via NDX

The **DIE Passport Application** is a registered consumer application in NDX that fetches user-specific data from multiple data providers. Here's how it works when **Nayana**, a citizen of Farajaland, applies for a passport. The application queries NDX to verify several pieces of information about him:

- His **full name, birth date, and birth place** - maintained by the **Registrar General's Department (RGD)**
- His **current address and profession** - maintained by the **Department of Registration of Persons (DRP)**

### The Old Way: Point-to-Point Integration Chaos

Traditionally, DIE would need to:
1. Integrate directly with RGD's API to fetch birth records
2. Integrate separately with DRP's API to fetch registration details
3. Manage separate authentication credentials for each system
4. Handle different API formats, versions, and protocols
5. Build and maintain custom integration code for each department
6. Update integrations whenever any department changes their API

This creates a tangled web of point-to-point connections. With just 3 departments, there are already 2 integrations to manage. As more departments join (Motor Traffic, Health, Education), the complexity grows exponentially: **N × (N-1) / 2** integration points.

### The OpenDIF Way: Federated Data Exchange with Consent

As a **registered application in NDX**, the DIE Passport Application can query user-specific data from multiple providers through a single endpoint:

1. **Nayana logs into the DIE passport application** (registered as an NDX consumer)
2. The application makes a **first data request** to NDX with a GraphQL query for Nayana's user-specific information
3. **NDX checks for consent** - since Nayana hasn't granted consent yet, NDX doesn't return the data. Instead, it returns a response containing:
   - A **consent portal URL** where Nayana needs to grant permission
   - Details of what data is being requested
   - Which data providers will be accessed (RGD, DRP)
4. The **passport application redirects Nayana** to the consent portal URL
5. Nayana **authenticates using his FUDI credentials** (Farajaland's national digital identity)
6. The Consent Portal shows Nayana exactly what data will be shared:
   - Full name, birth date, and birth place (from RGD)
   - Current address and profession (from DRP)
   - Who is requesting the data (DIE)
   - For what purpose (passport application)
7. **Nayana grants consent** - he is the data owner, and the departments (RGD, DRP) are merely custodians
8. After granting consent, Nayana is **redirected back to the passport application**
9. The DIE application makes a **second data request** to NDX with the same GraphQL query
10. This time, NDX orchestrates the data retrieval:
    - Verifies Nayana's active consent ✓
    - Checks access policies ✓
    - Federates the query across RGD and DRP
    - Aggregates the results
11. DIE receives a **unified response with all required data**
12. Nayana's passport application is **auto-populated and processed** seamlessly

**The key differences**:
- The **Passport Application is registered in NDX** as an authorized consumer
- The application **queries NDX for user-specific data** - never calling data providers directly
- The **first data request triggers the consent flow** if consent doesn't exist
- The **consent portal URL is provided in the response**, not hardcoded in the application
- Only the **second data request (after consent) returns the actual data**
- NDX handles all complexity of consent verification, data federation, and policy enforcement

---

## 📋 Want to See the Complete Workflow?

For a detailed, step-by-step walkthrough of Nayana's passport application journey—including consent flows, data federation, and policy enforcement—check out our **[Business Workflow Guide](BUSINESS_WORKFLOW.md)**.

The guide covers:
- All 10 steps of the workflow in detail
- Technical flow diagrams
- API request/response examples
- Workflow variations (consent already granted, denied, etc.)
- Value proposition for citizens, consumers, and providers

**Quick Summary**: The workflow demonstrates the two-request pattern where the first request triggers consent, and the second request (after consent is granted) returns the federated data from multiple sources.

---

## 🚀 Ready to Try It?

If you're excited to see OpenDIF Farajaland in action, head over to our **[Setup Guide](SETUP.md)** to get started in minutes!

The setup guide will walk you through:
- Installing prerequisites
- Running the automated `./init.sh` script
- Verifying your local deployment
- Testing the GraphQL API
- Troubleshooting common issues

**Quick Start:** Simply run `./init.sh` and watch the entire ecosystem spin up automatically!

---

## 🏗️ Technical Architecture

For comprehensive technical architecture details—including system components, data flow, security architecture, and deployment patterns—check out our **[Technical Architecture Guide](ARCHITECTURE.md)**.

The architecture guide covers:
- High-level architecture diagrams
- Five-layer architecture (Client, Gateway, Orchestration, Policy & Consent, Data Source)
- Core NDX components and their responsibilities
- Data source adapter patterns with implementation examples
- Security architecture and authentication flows
- Data flow diagrams for standard queries and consent flows
- Deployment architectures (Local, Kubernetes, Docker Swarm, VM-based)
- Scalability and performance optimization strategies

**Quick Overview**: OpenDIF Farajaland uses a federated architecture where data stays with providers, queries are orchestrated by NDX, and citizen consent is enforced before any data access.

---

## Member Organizations

This section details the member organizations participating in the OpenDIF Farajaland ecosystem, including both data providers and data consumers.

### Data Providers

Data providers are custodians of citizen data. They expose their data through standardized APIs that integrate with NDX.

#### DRP - Department of Registration of Persons

**Technology**: Ballerina (GraphQL Adapter)
**Port**: 9090
**Authentication**: API Key (Choreo)
**Schema ID**: `drp-schema-v1`

Provides personal registration data:
- Full name and other names
- Permanent address
- Profession
- National Identity Card (NIC) details

**Integration Approach**: DRP uses an **adapter pattern**. The underlying DRP system exposes a REST JSON API. The `drp-api-adapter` (built with Ballerina) translates GraphQL queries from NDX into REST calls to the original DRP API, demonstrating how to onboard legacy systems without modification.

**Location**: `members/drp/data-sources/drp-api-adapter/`

#### RGD - Registrar General's Department

**Technology**: Python (FastAPI)
**Port**: 8080
**Authentication**: OAuth2 Client Credentials
**Schema ID**: `abc-212`

Provides birth and civil registration data:
- Date of birth
- Sex/gender
- Birth registration number
- Birth place and district

**Location**: `members/rgd/data-sources/rgd-api/`

#### DMT - Department of Motor Traffic

**Technology**: TBD
**Status**: Schema defined, implementation pending
**Schema ID**: `dmt-schema-v1`

Will provide vehicle registration data:
- Registered vehicles by owner NIC
- Vehicle make, model, year
- Registration numbers
- Vehicle classifications

**Location**: `members/dmt/` (to be implemented)

### Data Consumers

Data consumers are organizations that use federated data from multiple providers to deliver services to citizens.

#### DIE - Department of Immigration and Emigration

**Role**: Data Consumer
**Primary Application**: Passport Application System
**Status**: Reference implementation (to be implemented)

The DIE consumes data from multiple providers to process passport applications:
- Fetches citizen identity and birth information from RGD
- Fetches current address and profession from DRP
- Uses NDX for federated data access with citizen consent
- Implements the consent flow for citizen authorization

**Location**: `members/die/applications/passport-app/` (planned)

**Integration Pattern**:
1. Redirects citizens to the NDX Consent Portal
2. Queries the NDX GraphQL endpoint after consent is granted
3. Receives unified data from multiple sources in a single response
4. No direct integration with individual data providers

---

## Security & Privacy

### Authentication Methods

1. **OAuth2 Client Credentials**: For service-to-service authentication (e.g., RGD)
2. **API Keys**: For simpler authenticated access (e.g., DRP via Choreo)
3. **JWT Tokens**: For user authentication (future implementation with ThunderID)

### Consent Management

Before data is shared:
1. User consent is checked via Consent Engine
2. Consent must be active and not expired
3. Consent scope must cover requested data fields

### Policy Enforcement

Policy Decision Point (PDP) enforces:
- Role-based access control (RBAC)
- Attribute-based access control (ABAC)
- Time-based access restrictions
- Purpose limitations

### Data Privacy

- **Minimal data exposure**: Only requested fields are returned
- **Source attribution**: `@sourceInfo` directives track data origin
- **Audit trails**: All data access is logged
- **Data sovereignty**: Source systems retain data ownership

### Security Recommendations

**For Development**:
- Use provided mock credentials
- Run on isolated networks
- Regularly update dependencies

**For Production**:
- Harden ThunderID for production (rotate admin/admin-cli secrets, CA-signed TLS certificate)
- Use TLS/SSL for all communications
- Implement rate limiting and DDoS protection
- Regular security audits
- Secure secrets management (e.g., HashiCorp Vault)
- Database encryption at rest
- Regular backups and disaster recovery

### Resources

- [GraphQL Best Practices](https://graphql.org/learn/best-practices/)
- [APISIX Documentation](https://apisix.apache.org/docs/)

---

**Built with OpenDIF** | **Powering Organizational Digital Transformation**

For questions or feedback, please open an issue or reach out to the maintainers.
