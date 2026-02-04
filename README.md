# NetPulse Auth POC

A Proof of Concept demonstrating authentication and authorization for NetPulse NMS microservices using Kong API Gateway and Keycloak.

## Architecture

```
                                    ┌─────────────────┐
                                    │    Keycloak     │
                                    │  (Auth Server)  │
                                    │   :8082         │
                                    └────────┬────────┘
                                             │
                                             │ OIDC/JWT
                                             │
┌─────────┐     ┌─────────────────┐         │
│ Client  │────▶│   Kong Gateway  │◀────────┘
│         │     │     :8000       │
└─────────┘     └────────┬────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ NMS Server  │  │ Telegraf API│  │ NetBox API  │
│   :8083     │  │   :8084     │  │   :8085     │
└─────────────┘  └─────────────┘  └─────────────┘
```

## Components

| Component | Port | Description |
|-----------|------|-------------|
| Kong Gateway | 8000 | API Gateway proxy |
| Kong Admin | 8001 | Kong Admin API |
| Kong Manager | 8002 | Kong Manager UI |
| Keycloak | 8082 | Identity & Access Management |
| PostgreSQL | 5433 | Database for Kong & Keycloak |
| OpenLDAP | 389 | LDAP Directory |
| phpLDAPadmin | 8090 | LDAP Admin UI |
| NMS Server | 8083 | Mock NMS Service |
| Telegraf API | 8084 | Mock Telegraf Service |
| NetBox API | 8085 | Mock NetBox Service |

## Quick Start

```bash
# Start all services
./scripts/start.sh

# Run authentication tests
./scripts/test-auth.sh
```

## Test Users

| Username | Password | Roles |
|----------|----------|-------|
| admin | admin123 | admin, nms-admin, telegraf-admin, netbox-admin |
| operator | operator123 | operator, nms-user, telegraf-user, netbox-user |
| viewer | viewer123 | viewer |
| nms-engineer | nms123 | nms-admin, telegraf-user |
| network-engineer | network123 | netbox-admin, nms-user |

## LDAP Users

| Username | Password | Group |
|----------|----------|-------|
| ldap-admin | ldapadmin123 | admins |
| ldap-operator | ldapoperator123 | operators |
| ldap-viewer | ldapviewer123 | viewers |
| john.doe | john123 | operators, nms-team |
| jane.smith | jane123 | viewers, network-team |

## API Endpoints

### Through Kong Gateway (http://localhost:8000)

| Service | Endpoint | Required Roles |
|---------|----------|---------------|
| NMS Server | /nms/ | Any authenticated |
| NMS Devices | /nms/api/devices | nms-admin, nms-user, operator |
| NMS Alerts | /nms/api/alerts | Any authenticated |
| NMS Config | /nms/api/config | admin, nms-admin |
| Telegraf Metrics | /telegraf/api/metrics | telegraf-admin, telegraf-user, viewer |
| Telegraf Collectors | /telegraf/api/collectors | telegraf-admin, operator |
| Telegraf Outputs | /telegraf/api/outputs | admin, telegraf-admin |
| NetBox Devices | /netbox/api/dcim/devices | netbox-admin, netbox-user, viewer |
| NetBox Prefixes | /netbox/api/ipam/prefixes | netbox-admin, netbox-user, operator |
| NetBox Tenants | /netbox/api/tenancy/tenants | admin, netbox-admin |

## Authentication Flow

### 1. Get Access Token from Keycloak

```bash
curl -X POST "http://localhost:8082/realms/netpulse/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=netpulse-gateway" \
  -d "client_secret=netpulse-gateway-secret" \
  -d "username=admin" \
  -d "password=admin123" \
  -d "grant_type=password"
```

### 2. Use Token to Access API

```bash
# Store token
TOKEN=$(curl -s -X POST "http://localhost:8082/realms/netpulse/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=netpulse-gateway" \
  -d "client_secret=netpulse-gateway-secret" \
  -d "username=admin" \
  -d "password=admin123" \
  -d "grant_type=password" | jq -r '.access_token')

# Access NMS API
curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/nms/api/devices
```

## Keycloak Configuration

### Realm: netpulse

The realm is pre-configured with:
- OIDC client for Kong (`netpulse-gateway`)
- Public client for frontend (`netpulse-frontend`)
- Role-based access control (RBAC)
- LDAP federation with OpenLDAP
- Group-to-role mappings

### Access Keycloak Admin

1. Open http://localhost:8082/admin
2. Login with `admin` / `admin123`
3. Select realm `netpulse`

## Kong Configuration

Kong is configured with:
- JWT authentication plugin
- Rate limiting (100 req/min)
- CORS support
- Request logging
- Route-based service proxying

### Kong Admin API Examples

```bash
# List all services
curl http://localhost:8001/services

# List all routes
curl http://localhost:8001/routes

# List all plugins
curl http://localhost:8001/plugins
```

## Troubleshooting

### Check service logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f keycloak
docker compose logs -f kong
```

### Reset everything

```bash
docker compose down -v
./scripts/start.sh
```

### Check Keycloak realm import

```bash
docker compose logs keycloak | grep -i "import"
```

## Integration with Existing Services

To integrate with your existing NetPulse services, update the Kong service URLs:

```bash
# Update NMS Server URL
curl -X PATCH http://localhost:8001/services/nms-server \
  --data "url=http://netpulse-nms-server:8081"

# Update other services similarly
```

## Security Considerations

- All passwords in this POC are for demonstration only
- In production, use strong passwords and secrets
- Enable HTTPS for all services
- Configure proper CORS policies
- Enable Keycloak brute force protection
- Use external secrets management
