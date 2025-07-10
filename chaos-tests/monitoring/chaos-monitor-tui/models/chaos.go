package models

import (
	"time"
)

// ChaosAPIFault represents a fault configuration from the Chaos API
type ChaosAPIFault struct {
	ID          string  `json:"id"`
	Service     string  `json:"service"`
	Region      string  `json:"region"`
	Probability float64 `json:"probability"`
	Error       struct {
		StatusCode int    `json:"statusCode"`
		Code       string `json:"code"`
		Message    string `json:"message"`
	} `json:"error"`
}

// ChaosAPIEffect represents a network effect configuration
type ChaosAPIEffect struct {
	ID      string `json:"id"`
	Latency int    `json:"latency"`
}

// EndpointStatus represents the status of a monitored endpoint
type EndpointStatus struct {
	Name         string
	URL          string
	Status       string // "ok", "failed", "timeout"
	ResponseTime float64
	HTTPCode     int
	LastChecked  time.Time
}

// ServiceStatus represents the status of an AWS service
type ServiceStatus struct {
	Name         string
	Status       string // "healthy", "throttled", "outage", "exhausted"
	ResponseTime float64
	LastChecked  time.Time
	FailureType  string
}

// Statistics tracks cumulative statistics
type Statistics struct {
	NginxStats   map[string]*EndpointStats
	ServiceStats map[string]*ServiceStats
	StartTime    time.Time
}

// EndpointStats tracks statistics for a single endpoint
type EndpointStats struct {
	TotalChecks int
	Failures    int
	SuccessRate float64
}

// ServiceStats tracks statistics for a single service
type ServiceStats struct {
	TotalChecks     int
	OKCount         int
	ThrottledCount  int
	OutageCount     int
	ExhaustedCount  int
	AvailabilityPct float64
}

// ActiveChaosTest represents a detected chaos test
type ActiveChaosTest struct {
	Type        string    // "region-failure", "latency", "service-outage", etc.
	Target      string    // What is being targeted (region, service, etc.)
	Status      string    // "active", "recovering", "completed"
	StartTime   time.Time
	Details     string    // Additional details about the test
}

// MonitorState represents the complete state of the monitoring system
type MonitorState struct {
	ChaosAPIFaults  []ChaosAPIFault
	ChaosAPIEffects []ChaosAPIEffect
	NginxEndpoints  []EndpointStatus
	AWSServices     []ServiceStatus
	Stats           Statistics
	LastUpdate      time.Time
	UpdateCount     int
	ActiveTests     []ActiveChaosTest // New field for detected chaos tests
}