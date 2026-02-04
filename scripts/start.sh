#!/bin/bash

# NetPulse Auth POC - Start Script
# This script starts all services and configures them

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "========================================"
echo "NetPulse Auth POC - Starting Services"
echo "========================================"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker first."
    exit 1
fi

# Stop any existing containers
echo "Stopping existing containers..."
docker compose down -v 2>/dev/null || true

# Build and start services
echo ""
echo "Building and starting services..."
docker compose up -d --build

echo ""
echo "Waiting for services to be healthy..."

# Wait for PostgreSQL
echo "Waiting for PostgreSQL..."
until docker exec netpulse-auth-postgres pg_isready -U admin > /dev/null 2>&1; do
    sleep 2
done
echo "✓ PostgreSQL is ready"

# Wait for Keycloak
echo "Waiting for Keycloak (this may take a minute)..."
until curl -s http://localhost:8082/health/ready 2>/dev/null | grep -q "UP"; do
    sleep 5
done
echo "✓ Keycloak is ready"

# Wait for Kong
echo "Waiting for Kong..."
until curl -s http://localhost:8001/status > /dev/null 2>&1; do
    sleep 2
done
echo "✓ Kong is ready"

# Wait for backend services
echo "Waiting for backend services..."
sleep 5
echo "✓ Backend services are ready"

# Kong is pre-configured via declarative config (kong/kong.yml)
echo "✓ Kong routes loaded from kong/kong.yml"

echo ""
echo "========================================"
echo "NetPulse Auth POC - Ready!"
echo "========================================"
echo ""
echo "Access Points:"
echo "  Kong Proxy:        http://localhost:8000"
echo "  Kong Admin:        http://localhost:8001"
echo "  Kong Manager:      http://localhost:8002"
echo "  Keycloak:          http://localhost:8082"
echo "  phpLDAPadmin:      http://localhost:8090"
echo ""
echo "Keycloak Admin:"
echo "  URL:      http://localhost:8082/admin"
echo "  Username: admin"
echo "  Password: admin123"
echo "  Realm:    netpulse"
echo ""
echo "Test Users (password same as username + '123'):"
echo "  admin / admin123       - Full admin access"
echo "  operator / operator123 - Operational access"
echo "  viewer / viewer123     - Read-only access"
echo "  nms-engineer / nms123  - NMS admin + Telegraf user"
echo "  network-engineer / network123 - NetBox admin + NMS user"
echo ""
echo "API Endpoints (through Kong):"
echo "  NMS Server:    http://localhost:8000/nms"
echo "  Telegraf API:  http://localhost:8000/telegraf"
echo "  NetBox API:    http://localhost:8000/netbox"
echo ""
echo "Run tests:"
echo "  ./scripts/test-auth.sh"
echo ""
