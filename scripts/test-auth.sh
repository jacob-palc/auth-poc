#!/bin/bash

# Test Authentication Script for NetPulse Auth POC
# This script demonstrates the authentication flow with Keycloak and Kong

KEYCLOAK_URL="http://localhost:8082"
KONG_PROXY_URL="http://localhost:8000"
REALM="netpulse"
CLIENT_ID="netpulse-gateway"
CLIENT_SECRET="netpulse-gateway-secret"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${BLUE}========================================"
    echo -e "$1"
    echo -e "========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

# Function to get access token from Keycloak
get_token() {
    local username=$1
    local password=$2

    print_info "Getting token for user: $username"

    local response=$(curl -s -X POST "${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=${CLIENT_ID}" \
        -d "client_secret=${CLIENT_SECRET}" \
        -d "username=${username}" \
        -d "password=${password}" \
        -d "grant_type=password")

    local token=$(echo $response | jq -r '.access_token')

    if [ "$token" != "null" ] && [ -n "$token" ]; then
        print_success "Token obtained successfully"
        echo $token
    else
        print_error "Failed to get token"
        echo $response | jq .
        return 1
    fi
}

# Function to decode JWT token
decode_token() {
    local token=$1
    print_info "Decoding JWT token..."
    echo $token | cut -d'.' -f2 | base64 -d 2>/dev/null | jq . 2>/dev/null || echo "Failed to decode token"
}

# Function to test API endpoint
test_endpoint() {
    local endpoint=$1
    local token=$2
    local description=$3

    print_info "Testing: $description"
    print_info "Endpoint: $endpoint"

    if [ -n "$token" ]; then
        local response=$(curl -s -w "\n%{http_code}" -X GET "${KONG_PROXY_URL}${endpoint}" \
            -H "Authorization: Bearer ${token}" \
            -H "Content-Type: application/json")
    else
        local response=$(curl -s -w "\n%{http_code}" -X GET "${KONG_PROXY_URL}${endpoint}" \
            -H "Content-Type: application/json")
    fi

    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')

    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        print_success "HTTP $http_code"
    elif [ "$http_code" -eq 401 ]; then
        print_error "HTTP $http_code - Unauthorized"
    elif [ "$http_code" -eq 403 ]; then
        print_error "HTTP $http_code - Forbidden"
    else
        print_error "HTTP $http_code"
    fi

    echo "$body" | jq . 2>/dev/null || echo "$body"
    echo ""
}

# Main test sequence
main() {
    print_header "NetPulse Auth POC - Authentication Test"

    echo ""
    echo "This script will test the authentication flow:"
    echo "1. Get tokens for different users from Keycloak"
    echo "2. Test API access with different roles"
    echo "3. Demonstrate RBAC enforcement"
    echo ""

    # Wait for services
    print_header "Checking Services"

    print_info "Checking Keycloak..."
    until curl -s "${KEYCLOAK_URL}/realms/${REALM}/.well-known/openid-configuration" > /dev/null 2>&1; do
        echo "Keycloak not ready, waiting..."
        sleep 5
    done
    print_success "Keycloak is ready"

    print_info "Checking Kong..."
    until curl -s "${KONG_PROXY_URL}" > /dev/null 2>&1; do
        echo "Kong not ready, waiting..."
        sleep 5
    done
    print_success "Kong is ready"

    # Test 1: Test without authentication
    print_header "Test 1: Access Without Authentication"
    test_endpoint "/nms/" "" "NMS Server without token"

    # Test 2: Admin user authentication
    print_header "Test 2: Admin User Authentication"
    ADMIN_TOKEN=$(get_token "admin" "admin123")

    if [ -n "$ADMIN_TOKEN" ]; then
        echo ""
        print_info "Token payload:"
        decode_token "$ADMIN_TOKEN"
        echo ""

        test_endpoint "/nms/" "$ADMIN_TOKEN" "NMS Server with admin token"
        test_endpoint "/nms/api/devices" "$ADMIN_TOKEN" "NMS Devices (admin)"
        test_endpoint "/nms/api/config" "$ADMIN_TOKEN" "NMS Config (admin-only)"
        test_endpoint "/telegraf/api/metrics" "$ADMIN_TOKEN" "Telegraf Metrics (admin)"
        test_endpoint "/netbox/api/dcim/devices" "$ADMIN_TOKEN" "NetBox Devices (admin)"
    fi

    # Test 3: Operator user authentication
    print_header "Test 3: Operator User Authentication"
    OPERATOR_TOKEN=$(get_token "operator" "operator123")

    if [ -n "$OPERATOR_TOKEN" ]; then
        echo ""
        print_info "Token payload:"
        decode_token "$OPERATOR_TOKEN"
        echo ""

        test_endpoint "/nms/api/devices" "$OPERATOR_TOKEN" "NMS Devices (operator)"
        test_endpoint "/nms/api/config" "$OPERATOR_TOKEN" "NMS Config (should be restricted)"
        test_endpoint "/telegraf/api/collectors" "$OPERATOR_TOKEN" "Telegraf Collectors (operator)"
    fi

    # Test 4: Viewer user authentication
    print_header "Test 4: Viewer User Authentication"
    VIEWER_TOKEN=$(get_token "viewer" "viewer123")

    if [ -n "$VIEWER_TOKEN" ]; then
        echo ""
        test_endpoint "/nms/api/alerts" "$VIEWER_TOKEN" "NMS Alerts (viewer)"
        test_endpoint "/netbox/api/tenancy/tenants" "$VIEWER_TOKEN" "NetBox Tenants (should be restricted)"
    fi

    # Test 5: NMS Engineer user
    print_header "Test 5: NMS Engineer User (Role-based)"
    NMS_TOKEN=$(get_token "nms-engineer" "nms123")

    if [ -n "$NMS_TOKEN" ]; then
        echo ""
        test_endpoint "/nms/api/config" "$NMS_TOKEN" "NMS Config (nms-admin role)"
        test_endpoint "/telegraf/api/metrics" "$NMS_TOKEN" "Telegraf Metrics (telegraf-user role)"
        test_endpoint "/telegraf/api/outputs" "$NMS_TOKEN" "Telegraf Outputs (should be restricted)"
    fi

    # Test 6: Network Engineer user
    print_header "Test 6: Network Engineer User (Role-based)"
    NETWORK_TOKEN=$(get_token "network-engineer" "network123")

    if [ -n "$NETWORK_TOKEN" ]; then
        echo ""
        test_endpoint "/netbox/api/tenancy/tenants" "$NETWORK_TOKEN" "NetBox Tenants (netbox-admin role)"
        test_endpoint "/nms/api/devices" "$NETWORK_TOKEN" "NMS Devices (nms-user role)"
        test_endpoint "/nms/api/config" "$NETWORK_TOKEN" "NMS Config (should be restricted)"
    fi

    print_header "Test Summary"
    echo ""
    echo "Users tested:"
    echo "  - admin: Full access to all services"
    echo "  - operator: Operational access, no config changes"
    echo "  - viewer: Read-only access"
    echo "  - nms-engineer: NMS admin + Telegraf user"
    echo "  - network-engineer: NetBox admin + NMS user"
    echo ""
    echo "Services tested:"
    echo "  - NMS Server: /nms/*"
    echo "  - Telegraf API: /telegraf/*"
    echo "  - NetBox API: /netbox/*"
    echo ""
    print_success "Authentication tests completed!"
}

main "$@"
