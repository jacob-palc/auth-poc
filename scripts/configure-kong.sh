#!/bin/bash

# Kong Configuration Script for NetPulse Auth POC
# This script configures Kong services, routes, and plugins

KONG_ADMIN_URL="http://localhost:8001"
KEYCLOAK_URL="http://keycloak:8080"
KEYCLOAK_REALM="netpulse"

echo "Waiting for Kong to be ready..."
until curl -s $KONG_ADMIN_URL/status > /dev/null 2>&1; do
    echo "Kong is not ready yet. Waiting..."
    sleep 5
done
echo "Kong is ready!"

echo ""
echo "========================================"
echo "Configuring Kong Services and Routes"
echo "========================================"

# ============================================
# NMS Server Service
# ============================================
echo ""
echo "Creating NMS Server service..."
curl -s -X POST $KONG_ADMIN_URL/services \
  --data "name=nms-server" \
  --data "url=http://nms-server:8080" | jq .

echo "Creating NMS Server routes..."
curl -s -X POST $KONG_ADMIN_URL/services/nms-server/routes \
  --data "name=nms-server-route" \
  --data "paths[]=/nms" \
  --data "strip_path=true" | jq .

# ============================================
# Telegraf API Service
# ============================================
echo ""
echo "Creating Telegraf API service..."
curl -s -X POST $KONG_ADMIN_URL/services \
  --data "name=telegraf-api" \
  --data "url=http://telegraf-api:8080" | jq .

echo "Creating Telegraf API routes..."
curl -s -X POST $KONG_ADMIN_URL/services/telegraf-api/routes \
  --data "name=telegraf-api-route" \
  --data "paths[]=/telegraf" \
  --data "strip_path=true" | jq .

# ============================================
# NetBox API Service
# ============================================
echo ""
echo "Creating NetBox API service..."
curl -s -X POST $KONG_ADMIN_URL/services \
  --data "name=netbox-api" \
  --data "url=http://netbox-api:8080" | jq .

echo "Creating NetBox API routes..."
curl -s -X POST $KONG_ADMIN_URL/services/netbox-api/routes \
  --data "name=netbox-api-route" \
  --data "paths[]=/netbox" \
  --data "strip_path=true" | jq .

# ============================================
# Enable JWT Plugin for Authentication
# ============================================
echo ""
echo "========================================"
echo "Configuring JWT Authentication Plugin"
echo "========================================"

# Enable JWT plugin globally for all services
echo "Enabling JWT plugin for NMS Server..."
curl -s -X POST $KONG_ADMIN_URL/services/nms-server/plugins \
  --data "name=jwt" \
  --data "config.claims_to_verify=exp" | jq .

echo "Enabling JWT plugin for Telegraf API..."
curl -s -X POST $KONG_ADMIN_URL/services/telegraf-api/plugins \
  --data "name=jwt" \
  --data "config.claims_to_verify=exp" | jq .

echo "Enabling JWT plugin for NetBox API..."
curl -s -X POST $KONG_ADMIN_URL/services/netbox-api/plugins \
  --data "name=jwt" \
  --data "config.claims_to_verify=exp" | jq .

# ============================================
# Create Kong Consumer for Keycloak
# ============================================
echo ""
echo "========================================"
echo "Creating Kong Consumer for Keycloak"
echo "========================================"

curl -s -X POST $KONG_ADMIN_URL/consumers \
  --data "username=keycloak" \
  --data "custom_id=keycloak-client" | jq .

# ============================================
# Enable Request Transformer Plugin
# ============================================
echo ""
echo "========================================"
echo "Configuring Request Transformer Plugin"
echo "========================================"

# This plugin will pass user information to backend services
echo "Enabling request transformer for NMS Server..."
curl -s -X POST $KONG_ADMIN_URL/services/nms-server/plugins \
  --data "name=request-transformer" \
  --data "config.add.headers=X-Service-Name:nms-server" | jq .

echo "Enabling request transformer for Telegraf API..."
curl -s -X POST $KONG_ADMIN_URL/services/telegraf-api/plugins \
  --data "name=request-transformer" \
  --data "config.add.headers=X-Service-Name:telegraf-api" | jq .

echo "Enabling request transformer for NetBox API..."
curl -s -X POST $KONG_ADMIN_URL/services/netbox-api/plugins \
  --data "name=request-transformer" \
  --data "config.add.headers=X-Service-Name:netbox-api" | jq .

# ============================================
# Enable Rate Limiting Plugin
# ============================================
echo ""
echo "========================================"
echo "Configuring Rate Limiting Plugin"
echo "========================================"

echo "Enabling rate limiting globally..."
curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=rate-limiting" \
  --data "config.minute=100" \
  --data "config.policy=local" | jq .

# ============================================
# Enable CORS Plugin
# ============================================
echo ""
echo "========================================"
echo "Configuring CORS Plugin"
echo "========================================"

curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=cors" \
  --data "config.origins=*" \
  --data "config.methods=GET,POST,PUT,DELETE,OPTIONS" \
  --data "config.headers=Accept,Authorization,Content-Type" \
  --data "config.exposed_headers=X-Auth-Token" \
  --data "config.credentials=true" \
  --data "config.max_age=3600" | jq .

# ============================================
# Enable Logging Plugin
# ============================================
echo ""
echo "========================================"
echo "Configuring File Logging Plugin"
echo "========================================"

curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=file-log" \
  --data "config.path=/dev/stdout" | jq .

echo ""
echo "========================================"
echo "Kong Configuration Complete!"
echo "========================================"
echo ""
echo "Services configured:"
echo "  - NMS Server:    http://localhost:8000/nms"
echo "  - Telegraf API:  http://localhost:8000/telegraf"
echo "  - NetBox API:    http://localhost:8000/netbox"
echo ""
echo "Kong Admin:      http://localhost:8001"
echo "Kong Manager:    http://localhost:8002"
echo ""
