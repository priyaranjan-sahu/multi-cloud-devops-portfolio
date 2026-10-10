package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func performRequest(t *testing.T, method, path string) *httptest.ResponseRecorder {
	t.Helper()
	router := newRouter()
	req := httptest.NewRequest(method, path, nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)
	return w
}

func TestHealthHandler(t *testing.T) {
	w := performRequest(t, http.MethodGet, "/health")
	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}
	var body map[string]string
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("invalid JSON response: %v", err)
	}
	if body["status"] != "healthy" {
		t.Errorf("expected status healthy, got %q", body["status"])
	}
}

func TestReadyHandler(t *testing.T) {
	w := performRequest(t, http.MethodGet, "/ready")
	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}
	var body map[string]string
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("invalid JSON response: %v", err)
	}
	if body["status"] != "ready" {
		t.Errorf("expected status ready, got %q", body["status"])
	}
}

func TestRootHandler(t *testing.T) {
	w := performRequest(t, http.MethodGet, "/")
	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}
	var body map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("invalid JSON response: %v", err)
	}
	if body["message"] == "" {
		t.Error("expected non-empty message")
	}
	if _, ok := body["endpoints"]; !ok {
		t.Error("expected endpoints map in response")
	}
}

func TestInfoHandler(t *testing.T) {
	w := performRequest(t, http.MethodGet, "/api/info")
	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}
	var body map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("invalid JSON response: %v", err)
	}
	if body["app"] != "devops-portfolio" {
		t.Errorf("expected app devops-portfolio, got %v", body["app"])
	}
}

func TestVersionHandler(t *testing.T) {
	w := performRequest(t, http.MethodGet, "/api/version")
	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}
	var body map[string]string
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("invalid JSON response: %v", err)
	}
	if body["version"] != version {
		t.Errorf("expected version %q, got %q", version, body["version"])
	}
}

func TestMetricsEndpoint(t *testing.T) {
	w := performRequest(t, http.MethodGet, "/metrics")
	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}
	if !strings.Contains(w.Body.String(), "http_requests_total") {
		t.Error("expected metrics output to contain http_requests_total")
	}
}
