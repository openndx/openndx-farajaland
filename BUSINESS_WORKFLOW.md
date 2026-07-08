# OpenDIF Farajaland - Business Workflow

This document provides a detailed walkthrough of the complete business workflow for Nayana's passport application, demonstrating how OpenDIF Farajaland's NDX facilitates citizen-centric data exchange with consent.

## Overview

This workflow illustrates the end-to-end process of how the **Department of Immigration and Emigration (DIE)** accesses citizen data from multiple government departments (**RGD** and **DRP**) through the **NDX (National Data Exchange)** with explicit citizen consent.

**Key Participants**:
- **Nayana**: Citizen applying for a passport
- **DIE**: Department of Immigration and Emigration (Data Consumer)
- **RGD**: Registrar General's Department (Data Provider - birth records)
- **DRP**: Department of Registration of Persons (Data Provider - personal registration)
- **NDX**: National Data Exchange (Orchestration layer)
- **FUDI**: Farajaland Unique Digital Identity (Identity provider)

---

## The Complete Workflow

### Step 1: Application Initiation

- Nayana navigates to the DIE passport application portal
- He logs into the passport application
- He starts a new passport application

**What happens behind the scenes**:
- The passport application prepares to request citizen data
- The application identifies which data fields are needed from which sources

---

### Step 2: First Data Request (Consent Check)

**Actions**:
- The DIE application identifies required data fields:
  - `fullName`, `dateOfBirth`, `birthPlace` (from RGD)
  - `address`, `profession` (from DRP)
- DIE makes a **first GraphQL query** to NDX requesting Nayana's data
- **NDX checks the Consent Engine** for Nayana's active consent for DIE

**Technical Details**:
```graphql
query {
  personInfo(nic: "123456789V") {
    fullName
    dateOfBirth
    birthPlace
    address
    profession
  }
}
```

**Why this step matters**: NDX always checks for consent first before returning any data. This ensures citizens maintain control over their information.

---

### Step 3: Consent Portal URL Response

Since Nayana hasn't granted consent yet, NDX responds with:

**Response Structure**:
```json
{
  "status": "CONSENT_REQUIRED",
  "consentPortalUrl": "https://consent.ndx.gov.fl/consent?session=abc123...",
  "requestedData": {
    "fields": ["fullName", "dateOfBirth", "birthPlace", "address", "profession"],
    "providers": ["RGD", "DRP"]
  },
  "consumer": "DIE",
  "purpose": "Passport Application Processing"
}
```

**Key Points**:
- **Status**: Consent required
- **Consent Portal URL**: Where Nayana needs to grant permission
- **Data request details**: What fields are being requested
- **Provider information**: Which data providers will be accessed (RGD, DRP)
- **No data is returned** at this stage

**Why this matters**: The consent portal URL is dynamically generated and includes the session context. This ensures the consent is tied to this specific data request.

---

### Step 4: Redirect to Consent Portal

**Actions**:
- The passport application **redirects Nayana** to the consent portal URL from the response
- The URL contains parameters identifying the data consumer (DIE) and requested data scope

**User Experience**:
- Nayana's browser navigates to the consent portal
- He sees a branded consent interface with NDX and FUDI branding
- The interface clearly shows he's granting consent for his passport application

---

### Step 5: Citizen Authentication

**Actions**:
- Nayana **authenticates using his FUDI credentials** (Farajaland's national digital identity)
- Multi-factor authentication may be required for sensitive operations
- FUDI (powered by ThunderID) verifies Nayana's identity securely

**Authentication Flow**:
1. Nayana enters his FUDI username and password
2. If MFA is enabled, he receives a code on his registered mobile device
3. He enters the MFA code
4. FUDI issues an authentication token
5. The consent portal receives the authenticated session

**Security Measures**:
- Session timeout for inactive periods
- Secure token exchange
- HTTPS/TLS encryption
- Protection against CSRF and XSS attacks

---

### Step 6: Consent Review & Grant

The Consent Portal displays a detailed consent request:

**Displayed Information**:
- **Who is requesting**: Department of Immigration and Emigration
- **What data is needed**: Full name, date of birth, birth place, address, profession
- **From which sources**: RGD (birth records), DRP (registration data)
- **For what purpose**: Passport application processing
- **For how long**: Consent validity period (e.g., 30 days)

**Consent Screen Elements**:
```
╔═══════════════════════════════════════════════════════════╗
║                    Data Sharing Consent                    ║
╠═══════════════════════════════════════════════════════════╣
║                                                            ║
║  Department of Immigration and Emigration (DIE)           ║
║  is requesting access to your information                  ║
║                                                            ║
║  DATA TO BE SHARED:                                        ║
║  ✓ Full Name (from RGD)                                   ║
║  ✓ Date of Birth (from RGD)                               ║
║  ✓ Birth Place (from RGD)                                 ║
║  ✓ Current Address (from DRP)                             ║
║  ✓ Profession (from DRP)                                  ║
║                                                            ║
║  PURPOSE: Passport Application Processing                 ║
║  VALID FOR: 30 days                                       ║
║                                                            ║
║  [ Grant Consent ]  [ Deny ]  [ Learn More ]             ║
║                                                            ║
╚═══════════════════════════════════════════════════════════╝
```

**Citizen Actions**:
- Nayana reviews the request carefully
- He can click "Learn More" to understand how his data will be used
- He **grants consent** (or can deny if he chooses)
- The consent is **recorded in the Consent Engine** with:
  - Timestamp
  - Scope (specific fields and sources)
  - Expiry date
  - Audit trail

**What happens when consent is granted**:
1. Consent record is created in the Consent Engine
2. Record includes: citizen ID, consumer ID, data scope, timestamp, expiry
3. Consent is digitally signed for non-repudiation
4. Audit log entry is created

---

### Step 7: Redirect Back to Application

**Actions**:
- After granting consent, Nayana is **redirected back to the passport application**
- The application receives confirmation that consent has been granted
- The session context is maintained

**Redirect Flow**:
```
Consent Portal → Callback URL with session token → Passport Application
```

**User Experience**:
- Seamless transition back to the passport application
- Nayana sees a "Processing..." or "Fetching your information..." message
- The application prepares to make the second data request

---

### Step 8: Second Data Request (Data Retrieval)

**Actions**:
- The passport application makes a **second GraphQL query** to NDX with the same data request:

```graphql
query {
  personInfo(nic: "123456789V") {
    fullName
    dateOfBirth
    birthPlace
    address
    profession
  }
}
```

**What's Different This Time**:
- The request includes the authenticated session token
- Consent has been granted and recorded
- NDX will now proceed with data retrieval

---

### Step 9: Orchestration & Policy Enforcement

This time, NDX performs the complete orchestration:

#### 9.1 Consent Verification
- ✓ Nayana has active consent for DIE
- ✓ Consent scope includes all requested fields
- ✓ Consent has not expired

#### 9.2 Policy Check
- ✓ DIE has authorization to access this data
- ✓ DIE's access policies allow passport application processing
- ✓ No data access restrictions are violated

#### 9.3 Query Federation
NDX splits the query into sub-queries based on data source mapping:

**Sub-query to RGD**:
```graphql
query {
  getPersonInfo(nic: "123456789V") {
    fullName
    dateOfBirth
    birthPlace
  }
}
```

**Sub-query to DRP** (via Adapter):
```graphql
query {
  person(nic: "123456789V") {
    fullName
    address
    profession
  }
}
```

The DRP adapter translates this to a REST call:
```http
GET /api/person/123456789V
```

#### 9.4 Authentication
NDX authenticates to each data provider:
- **RGD**: OAuth2 Client Credentials flow
- **DRP Adapter**: API Key authentication (Choreo)

#### 9.5 Data Retrieval
**From RGD**:
```json
{
  "fullName": "Nayana Johnson",
  "dateOfBirth": "1990-03-15",
  "birthPlace": "Colombo"
}
```

**From DRP** (via adapter):
```json
{
  "fullName": "Nayana Johnson",
  "address": "123 Main Street, Colombo",
  "profession": "Software Engineer"
}
```

#### 9.6 Aggregation
NDX combines the results from both sources:
```json
{
  "data": {
    "personInfo": {
      "fullName": "Nayana Johnson",
      "dateOfBirth": "1990-03-15",
      "birthPlace": "Colombo",
      "address": "123 Main Street, Colombo",
      "profession": "Software Engineer"
    }
  }
}
```

#### 9.7 Audit Logging
NDX records the data access event:
```json
{
  "timestamp": "2025-11-27T14:23:45Z",
  "citizen": "123456789V",
  "consumer": "DIE",
  "purpose": "Passport Application",
  "dataAccessed": ["fullName", "dateOfBirth", "birthPlace", "address", "profession"],
  "sources": ["RGD", "DRP"],
  "consentId": "consent_abc123",
  "status": "SUCCESS"
}
```

---

### Step 10: Data Response & Application Processing

**Actions**:
- DIE receives the **complete data set in a single response**
- The passport application is **auto-populated** with Nayana's verified information
- Nayana reviews the pre-filled form
- Nayana submits his passport application
- The application is **processed successfully** with verified data

**Form Auto-Population**:
```
╔════════════════════════════════════════════════════╗
║        Passport Application - Personal Info        ║
╠════════════════════════════════════════════════════╣
║                                                    ║
║  Full Name: Nayana Johnson           [verified ✓]  ║
║  Date of Birth: 1990-03-15           [verified ✓]  ║
║  Birth Place: Colombo                [verified ✓]  ║
║  Current Address:                    [verified ✓]  ║
║    123 Main Street, Colombo                        ║
║  Profession: Software Engineer       [verified ✓]  ║
║                                                    ║
║  [ Review ] [ Submit Application ]                 ║
║                                                    ║
╚════════════════════════════════════════════════════╝
```

**Benefits**:
- No manual data entry errors
- Data is verified from authoritative sources
- Faster application processing
- Reduced processing time from days to minutes

---

## The Value Proposition

### For Citizens (Nayana)

**Transparency**:
- Clear visibility into who accesses his data
- Detailed consent screens showing exactly what's shared
- Audit trail of all data access

**Control**:
- He must explicitly grant consent
- Can deny consent if uncomfortable
- Can revoke consent at any time
- Granular control over what data is shared

**Convenience**:
- No need to manually provide documents
- No photocopies or physical submissions
- Auto-populated forms reduce errors
- Faster service delivery

**Trust**:
- Data comes directly from authoritative sources
- No intermediaries handling his data
- Secure authentication via FUDI
- Compliance with data protection regulations

---

### For Data Consumers (DIE)

**Simplicity**:
- Single API endpoint instead of multiple integrations
- One GraphQL query retrieves data from multiple sources
- No need to maintain separate integrations with RGD and DRP

**Reliability**:
- Standardized data format (GraphQL)
- Guaranteed data quality from source systems
- Built-in error handling and retry mechanisms

**Compliance**:
- Consent and audit trails built-in
- Automatic compliance with data protection laws
- No liability for consent management
- Clear records for regulatory audits

**Efficiency**:
- Faster application processing
- Reduced manual verification
- Lower operational costs
- Better citizen satisfaction

---

### For Data Providers (RGD, DRP)

**Sovereignty**:
- Maintain control over their data
- Data never leaves their systems
- Can enforce their own access policies
- Retain ownership and governance

**Standardization**:
- Single API standard to implement (GraphQL)
- No need to integrate with each consumer separately
- Consistent authentication and authorization

**Security**:
- Centralized authentication and authorization via NDX
- No need to manage credentials for each consumer
- Built-in security best practices

**Auditability**:
- Clear records of who accessed what data and when
- Compliance with data protection regulations
- Support for regulatory audits
- Transparency for citizens

---

## Key Principles Demonstrated

### 1. Citizen-Centric Design
The workflow ensures citizens are at the center:
- Explicit consent required
- Transparent data sharing
- Control over their information

### 2. Data Sovereignty
Each provider maintains control:
- Data stays in source systems
- Providers enforce their own policies
- No centralized data repository

### 3. Consent-Based Access
All data access requires consent:
- Consent must be explicit and informed
- Consent has defined scope and expiry
- Consent can be revoked

### 4. Federation Over Replication
Data is federated, not replicated:
- Real-time queries to source systems
- Always fresh data
- No data synchronization issues

### 5. Policy-Based Governance
Access is governed by policies:
- Who can access what data
- For what purposes
- Under what conditions

---

## Workflow Variations

### Scenario 1: Consent Already Granted

If Nayana has previously granted consent to DIE (and it hasn't expired):

1. Application Initiation (same as Step 1)
2. **First Data Request** → NDX finds valid consent → **Data returned immediately**
3. Form auto-populated (same as Step 10)

**Result**: Seamless experience, no consent prompt needed.

---

### Scenario 2: Consent Denied

If Nayana denies consent:

1. Steps 1-5 (same as main workflow)
2. **Nayana clicks "Deny" on consent screen**
3. Consent denial is recorded
4. Nayana is redirected back to passport application
5. Application shows: "Unable to fetch verified data. Please provide documents manually."

**Result**: Application continues with manual data entry.

---

### Scenario 3: Partial Consent

If NDX supports granular consent, Nayana could grant access to some fields but not others:

1. Nayana grants consent for: `fullName`, `dateOfBirth`, `address`
2. Nayana denies consent for: `birthPlace`, `profession`
3. Application receives partial data
4. Missing fields must be manually entered

**Result**: Hybrid approach, verified data where possible.

---

## Technical Flow Diagram

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│ Nayana  │     │   DIE   │     │   NDX   │     │  FUDI   │     │RGD/DRP  │
└────┬────┘     └────┬────┘     └────┬────┘     └────┬────┘     └────┬────┘
     │               │               │               │               │
     │ 1. Start App  │               │               │               │
     ├──────────────>│               │               │               │
     │               │ 2. Query      │               │               │
     │               ├──────────────>│               │               │
     │               │               │ 3. Check      │               │
     │               │               │   Consent     │               │
     │               │<──────────────┤               │               │
     │               │ (Consent URL) │               │               │
     │ 4. Redirect   │               │               │               │
     │<──────────────┤               │               │               │
     │               │               │               │               │
     │ 5. Authenticate                │               │               │
     ├───────────────────────────────────────────────>│               │
     │<──────────────────────────────────────────────┤               │
     │               │               │               │               │
     │ 6. Grant Consent               │               │               │
     ├──────────────────────────────>│               │               │
     │               │               │ (Save Consent)│               │
     │               │               │               │               │
     │ 7. Redirect   │               │               │               │
     │<──────────────┤               │               │               │
     ├──────────────>│               │               │               │
     │               │ 8. Query      │               │               │
     │               │   (2nd time)  │               │               │
     │               ├──────────────>│               │               │
     │               │               │ 9. Federate   │               │
     │               │               ├──────────────────────────────>│
     │               │               │<──────────────────────────────┤
     │               │<──────────────┤               │               │
     │               │ (Data)        │               │               │
     │               │               │               │               │
     │ 10. Review    │               │               │               │
     │<──────────────┤               │               │               │
     │               │               │               │               │
     │ Submit        │               │               │               │
     ├──────────────>│               │               │               │
     │               │               │               │               │
```

---

## Next Steps

After understanding this workflow:

1. **Try it yourself**: Follow the [Setup Guide](SETUP.md) to run the system locally
2. **Explore the API**: See [API Documentation](README.md#api-documentation) for query examples
3. **Understand the architecture**: Read the [Technical Architecture](README.md#technical-architecture) section
4. **Build your own consumer**: Learn how to integrate applications with NDX

---

For more information, return to the [main README](README.md) or check out the [Setup Guide](SETUP.md) to get started.