package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"
	"time"
)

type Response struct {
	Service     string            `json:"service"`
	Message     string            `json:"message"`
	Timestamp   string            `json:"timestamp"`
	Headers     map[string]string `json:"headers,omitempty"`
	User        string            `json:"user,omitempty"`
	Roles       []string          `json:"roles,omitempty"`
	RequestPath string            `json:"request_path"`
}

func main() {
	serviceName := getEnv("SERVICE_NAME", "netbox-api")
	port := getEnv("SERVICE_PORT", "8080")

	http.HandleFunc("/", handleRequest(serviceName))
	http.HandleFunc("/health", healthCheck)
	http.HandleFunc("/api/dcim/devices", handleDevices(serviceName))
	http.HandleFunc("/api/ipam/prefixes", handlePrefixes(serviceName))
	http.HandleFunc("/api/tenancy/tenants", handleTenants(serviceName))

	log.Printf("%s starting on port %s", serviceName, port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func getEnv(key, defaultValue string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return defaultValue
}

func handleRequest(serviceName string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		response := buildResponse(serviceName, "Welcome to "+serviceName+" - Device Management Service", r)
		sendJSON(w, response)
	}
}

func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
}

func handleDevices(serviceName string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		roles := extractRoles(r)
		if !hasAnyRole(roles, []string{"admin", "netbox-admin", "netbox-user", "operator", "viewer"}) {
			sendForbidden(w, "Access denied: requires netbox role")
			return
		}

		devices := map[string]interface{}{
			"service":   serviceName,
			"endpoint":  "/api/dcim/devices",
			"timestamp": time.Now().Format(time.RFC3339),
			"user":      extractUser(r),
			"roles":     roles,
			"count":     5,
			"results": []map[string]interface{}{
				{"id": 1, "name": "core-router-01", "device_type": "Cisco ISR 4451", "site": "DC-1", "status": "active"},
				{"id": 2, "name": "core-switch-01", "device_type": "Cisco Nexus 9300", "site": "DC-1", "status": "active"},
				{"id": 3, "name": "edge-router-01", "device_type": "Juniper MX204", "site": "DC-2", "status": "active"},
				{"id": 4, "name": "firewall-01", "device_type": "Palo Alto PA-3260", "site": "DC-1", "status": "active"},
				{"id": 5, "name": "load-balancer-01", "device_type": "F5 BIG-IP", "site": "DC-1", "status": "planned"},
			},
		}
		sendJSON(w, devices)
	}
}

func handlePrefixes(serviceName string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		roles := extractRoles(r)
		if !hasAnyRole(roles, []string{"admin", "netbox-admin", "netbox-user", "operator"}) {
			sendForbidden(w, "Access denied: requires netbox-admin or operator role")
			return
		}

		prefixes := map[string]interface{}{
			"service":   serviceName,
			"endpoint":  "/api/ipam/prefixes",
			"timestamp": time.Now().Format(time.RFC3339),
			"user":      extractUser(r),
			"roles":     roles,
			"count":     4,
			"results": []map[string]interface{}{
				{"id": 1, "prefix": "10.0.0.0/8", "status": "container", "vrf": "Production"},
				{"id": 2, "prefix": "10.1.0.0/16", "status": "active", "vrf": "Production"},
				{"id": 3, "prefix": "192.168.0.0/16", "status": "container", "vrf": "Management"},
				{"id": 4, "prefix": "192.168.1.0/24", "status": "active", "vrf": "Management"},
			},
		}
		sendJSON(w, prefixes)
	}
}

func handleTenants(serviceName string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		roles := extractRoles(r)
		// Tenants management requires admin role
		if !hasAnyRole(roles, []string{"admin", "netbox-admin"}) {
			sendForbidden(w, "Access denied: requires admin or netbox-admin role")
			return
		}

		tenants := map[string]interface{}{
			"service":   serviceName,
			"endpoint":  "/api/tenancy/tenants",
			"timestamp": time.Now().Format(time.RFC3339),
			"user":      extractUser(r),
			"roles":     roles,
			"count":     3,
			"results": []map[string]interface{}{
				{"id": 1, "name": "Acme Corp", "slug": "acme-corp", "group": "Enterprise"},
				{"id": 2, "name": "TechStart Inc", "slug": "techstart-inc", "group": "SMB"},
				{"id": 3, "name": "Global Networks", "slug": "global-networks", "group": "Enterprise"},
			},
		}
		sendJSON(w, tenants)
	}
}

func buildResponse(serviceName, message string, r *http.Request) Response {
	headers := make(map[string]string)
	for key, values := range r.Header {
		if strings.HasPrefix(strings.ToLower(key), "x-") {
			headers[key] = strings.Join(values, ", ")
		}
	}

	return Response{
		Service:     serviceName,
		Message:     message,
		Timestamp:   time.Now().Format(time.RFC3339),
		Headers:     headers,
		User:        extractUser(r),
		Roles:       extractRoles(r),
		RequestPath: r.URL.Path,
	}
}

func extractUser(r *http.Request) string {
	if user := r.Header.Get("X-Userinfo"); user != "" {
		return user
	}
	if user := r.Header.Get("X-Consumer-Username"); user != "" {
		return user
	}
	if user := r.Header.Get("X-Authenticated-Userid"); user != "" {
		return user
	}
	return "anonymous"
}

func extractRoles(r *http.Request) []string {
	if rolesHeader := r.Header.Get("X-User-Roles"); rolesHeader != "" {
		return strings.Split(rolesHeader, ",")
	}
	if rolesHeader := r.Header.Get("X-Realm-Roles"); rolesHeader != "" {
		return strings.Split(rolesHeader, ",")
	}
	return []string{}
}

func hasAnyRole(userRoles []string, requiredRoles []string) bool {
	if len(userRoles) == 0 {
		return true // For demo purposes
	}
	for _, userRole := range userRoles {
		for _, required := range requiredRoles {
			if strings.TrimSpace(userRole) == required {
				return true
			}
		}
	}
	return false
}

func sendJSON(w http.ResponseWriter, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}

func sendForbidden(w http.ResponseWriter, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusForbidden)
	json.NewEncoder(w).Encode(map[string]string{
		"error":   "forbidden",
		"message": message,
	})
}
