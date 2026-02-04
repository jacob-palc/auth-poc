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
	serviceName := getEnv("SERVICE_NAME", "nms-server")
	port := getEnv("SERVICE_PORT", "8080")

	http.HandleFunc("/", handleRequest(serviceName))
	http.HandleFunc("/health", healthCheck)
	http.HandleFunc("/api/devices", handleDevices(serviceName))
	http.HandleFunc("/api/alerts", handleAlerts(serviceName))
	http.HandleFunc("/api/config", handleConfig(serviceName))

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
		response := buildResponse(serviceName, "Welcome to "+serviceName, r)
		sendJSON(w, response)
	}
}

func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
}

func handleDevices(serviceName string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Check for required role
		roles := extractRoles(r)
		if !hasAnyRole(roles, []string{"admin", "nms-admin", "nms-user", "operator"}) {
			sendForbidden(w, "Access denied: requires nms-admin, nms-user, or operator role")
			return
		}

		devices := map[string]interface{}{
			"service":   serviceName,
			"endpoint":  "/api/devices",
			"timestamp": time.Now().Format(time.RFC3339),
			"user":      extractUser(r),
			"roles":     roles,
			"data": []map[string]interface{}{
				{"id": 1, "name": "Router-01", "status": "online", "type": "router"},
				{"id": 2, "name": "Switch-01", "status": "online", "type": "switch"},
				{"id": 3, "name": "Firewall-01", "status": "warning", "type": "firewall"},
			},
		}
		sendJSON(w, devices)
	}
}

func handleAlerts(serviceName string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		roles := extractRoles(r)
		if !hasAnyRole(roles, []string{"admin", "nms-admin", "nms-user", "operator", "viewer"}) {
			sendForbidden(w, "Access denied: requires appropriate role")
			return
		}

		alerts := map[string]interface{}{
			"service":   serviceName,
			"endpoint":  "/api/alerts",
			"timestamp": time.Now().Format(time.RFC3339),
			"user":      extractUser(r),
			"roles":     roles,
			"data": []map[string]interface{}{
				{"id": 1, "severity": "warning", "message": "High CPU usage on Router-01", "device": "Router-01"},
				{"id": 2, "severity": "critical", "message": "Link down on Switch-01 port 24", "device": "Switch-01"},
			},
		}
		sendJSON(w, alerts)
	}
}

func handleConfig(serviceName string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		roles := extractRoles(r)
		// Config endpoint requires admin role
		if !hasAnyRole(roles, []string{"admin", "nms-admin"}) {
			sendForbidden(w, "Access denied: requires admin or nms-admin role")
			return
		}

		config := map[string]interface{}{
			"service":   serviceName,
			"endpoint":  "/api/config",
			"timestamp": time.Now().Format(time.RFC3339),
			"user":      extractUser(r),
			"roles":     roles,
			"data": map[string]interface{}{
				"polling_interval": 60,
				"retention_days":   30,
				"snmp_version":     "v3",
				"enabled_modules":  []string{"discovery", "monitoring", "alerting"},
			},
		}
		sendJSON(w, config)
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
	// Check headers that Kong/Keycloak might set
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
	// Check for roles in headers
	if rolesHeader := r.Header.Get("X-User-Roles"); rolesHeader != "" {
		return strings.Split(rolesHeader, ",")
	}
	if rolesHeader := r.Header.Get("X-Realm-Roles"); rolesHeader != "" {
		return strings.Split(rolesHeader, ",")
	}
	return []string{}
}

func hasAnyRole(userRoles []string, requiredRoles []string) bool {
	// If no roles are passed (unauthenticated through Kong), allow for demo
	if len(userRoles) == 0 {
		return true // For demo purposes - in production, return false
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
