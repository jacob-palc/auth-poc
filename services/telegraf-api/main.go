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
	serviceName := getEnv("SERVICE_NAME", "telegraf-api")
	port := getEnv("SERVICE_PORT", "8080")

	http.HandleFunc("/", handleRequest(serviceName))
	http.HandleFunc("/health", healthCheck)
	http.HandleFunc("/api/metrics", handleMetrics(serviceName))
	http.HandleFunc("/api/collectors", handleCollectors(serviceName))
	http.HandleFunc("/api/outputs", handleOutputs(serviceName))

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
		response := buildResponse(serviceName, "Welcome to "+serviceName+" - Telemetry Service", r)
		sendJSON(w, response)
	}
}

func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
}

func handleMetrics(serviceName string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		roles := extractRoles(r)
		if !hasAnyRole(roles, []string{"admin", "telegraf-admin", "telegraf-user", "operator", "viewer"}) {
			sendForbidden(w, "Access denied: requires telegraf role")
			return
		}

		metrics := map[string]interface{}{
			"service":   serviceName,
			"endpoint":  "/api/metrics",
			"timestamp": time.Now().Format(time.RFC3339),
			"user":      extractUser(r),
			"roles":     roles,
			"data": []map[string]interface{}{
				{"name": "cpu_usage", "value": 45.2, "unit": "percent", "host": "server-01"},
				{"name": "memory_usage", "value": 67.8, "unit": "percent", "host": "server-01"},
				{"name": "disk_usage", "value": 52.1, "unit": "percent", "host": "server-01"},
				{"name": "network_in", "value": 1024.5, "unit": "mbps", "host": "server-01"},
				{"name": "network_out", "value": 512.3, "unit": "mbps", "host": "server-01"},
			},
		}
		sendJSON(w, metrics)
	}
}

func handleCollectors(serviceName string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		roles := extractRoles(r)
		if !hasAnyRole(roles, []string{"admin", "telegraf-admin", "operator"}) {
			sendForbidden(w, "Access denied: requires telegraf-admin or operator role")
			return
		}

		collectors := map[string]interface{}{
			"service":   serviceName,
			"endpoint":  "/api/collectors",
			"timestamp": time.Now().Format(time.RFC3339),
			"user":      extractUser(r),
			"roles":     roles,
			"data": []map[string]interface{}{
				{"id": 1, "name": "snmp", "status": "active", "targets": 150},
				{"id": 2, "name": "prometheus", "status": "active", "targets": 45},
				{"id": 3, "name": "statsd", "status": "active", "targets": 30},
				{"id": 4, "name": "netflow", "status": "active", "targets": 10},
			},
		}
		sendJSON(w, collectors)
	}
}

func handleOutputs(serviceName string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		roles := extractRoles(r)
		// Outputs config requires admin role
		if !hasAnyRole(roles, []string{"admin", "telegraf-admin"}) {
			sendForbidden(w, "Access denied: requires admin or telegraf-admin role")
			return
		}

		outputs := map[string]interface{}{
			"service":   serviceName,
			"endpoint":  "/api/outputs",
			"timestamp": time.Now().Format(time.RFC3339),
			"user":      extractUser(r),
			"roles":     roles,
			"data": []map[string]interface{}{
				{"id": 1, "name": "influxdb", "status": "connected", "url": "http://influxdb:8086"},
				{"id": 2, "name": "kafka", "status": "connected", "brokers": []string{"kafka:9092"}},
			},
		}
		sendJSON(w, outputs)
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
