# DIVE25: Digital Interoperability Verification Experiment

DIVE25 is a secure, federated document access system designed for NATO and partner nation environments. It implements a comprehensive attribute-based access control (ABAC) system following NATO STANAGs 4774, 4778, and 5636.

## System Overview

DIVE25 provides a robust platform for sharing and managing classified documents across different security domains while enforcing strict access controls based on user attributes such as clearance level, country of affiliation, and communities of interest (COI).

### Key Features

The system implements several critical security and functional capabilities:

- Federated authentication through multiple partner nation Identity Providers
- Attribute-based access control using Open Policy Agent
- Document classification and handling markings
- Real-time security policy enforcement
- Comprehensive audit logging and monitoring
- Support for NATO, EU, and FVEY security domains

### Architecture Components

DIVE25 is built using a modern microservices architecture with the following key components:

1. **Federation Hub (Keycloak)**
   - Manages federated authentication
   - Normalizes user attributes
   - Provides SSO capabilities
   - Integrates with external Identity Providers

2. **API Layer (Node.js)**
   - Implements core business logic
   - Enforces security policies
   - Manages document operations
   - Handles audit logging

3. **Frontend (Next.js)**
   - Provides user interface
   - Implements security marking display
   - Manages document workflow
   - Handles real-time updates

4. **Security Services**
   - Open Policy Agent (OPA) for ABAC
   - Kong API Gateway for access control
   - Redis for rate limiting and caching
   - MongoDB for document metadata

5. **Monitoring Stack**
   - Prometheus for metrics collection
   - Grafana for visualization
   - ELK Stack for log aggregation

## Getting Started

### Prerequisites

Before deploying DIVE25, ensure you have the following:

- Docker and Docker Compose installed
- Node.js 18 or higher
- Valid SSL certificates
- MongoDB 5.0 or higher
- Redis 6.0 or higher

### Environment Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/your-org/dive25-slim.git
   cd dive25-slim
   ```
2. Clone the repository:
   ```bash
   cp .env.template .env.production
   ```
3. Configure the required environment variables:
   ```env
   MONGO_INITDB_ROOT_USERNAME=<username>
   MONGO_INITDB_ROOT_PASSWORD=<secure-password>
   KEYCLOAK_ADMIN=admin
   KEYCLOAK_ADMIN_PASSWORD=<secure-password>
   KEYCLOAK_DB_PASSWORD=<secure-password>
   KEYCLOAK_CLIENT_SECRET=<generated-secret>
   JWT_SECRET=<generated-secret>
   API_KEY=<generated-key>
   ```

### Deployment

DIVE25 can be deployed in both development and production environments:

#### Development Deployment

```bash
docker-compose up -d mongodb redis keycloak

# Start the API and frontend
npm run dev
```

#### Production Deployment

```bash
./scripts/deployment-verify.sh

# Deploy the full stack
docker-compose -f docker-compose.production.yml up -d
```

### Security Configuration

#### Keycloak Setup

1. Access the Keycloak admin console
2. Import the provided realm configuration
3. Configure external Identity Providers
4. Set up client credentials

#### OPA Policy Configuration

1. Load the NATO ABAC policies:
   ```bash
   ./scripts/load-policies.sh
   ```

2. Verify policy loading:
   ```bash
   curl http://localhost:8181/v1/policies
   ```

#### API Documentation

   Access the API documentation:
   ```http
   http://localhost:3000/api-docs
   ```

#### Document Operations

1. Create a document:
   ```http
   POST /api/documents
   Content-Type: application/json
   ```

2. Retrieve a document:
   ```http

API Documentation
Authentication
All API requests must include a valid JWT token:
httpCopyAuthorization: Bearer <token>
Document Operations
Create Document
httpCopyPOST /api/documents
Content-Type: application/json

{
  "title": "Document Title",
  "content": "Document Content",
  "clearance": "NATO SECRET",
  "releasableTo": ["NATO"],
  "coiTags": ["OpAlpha"]
}
Retrieve Document
httpCopyGET /api/documents/:id
Security Considerations
Access Control
DIVE25 implements a comprehensive ABAC system that evaluates:

User clearance level
Country of affiliation
Communities of Interest
Document classification
Releasability markers
LACV codes

Audit Logging
All document operations are logged with:

User identification
Timestamp
Operation type
Success/failure status
Access decision rationale

Monitoring and Metrics
Health Checks
Access system health information:
httpCopyGET /health
GET /ready
GET /alive
Metrics Collection
Prometheus endpoints expose:

Request rates
Response times
Access decisions
Error rates
System resource usage

Troubleshooting
Common Issues

Authentication Failures

Verify Keycloak configuration
Check token validity
Ensure proper client secrets


Access Denied Errors

Verify user attributes
Check document classification
Review OPA policy decisions



Logging
Access logs are available through:

Docker logs
Grafana dashboards
ELK Stack interface

Contributing
Please read CONTRIBUTING.md for details on our code of conduct and the process for submitting pull requests.