package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"

	"chaos-monitor-tui/models"
	"chaos-monitor-tui/monitor"
	"chaos-monitor-tui/ui"

	tea "github.com/charmbracelet/bubbletea"
)

const (
	baseURL        = "http://localhost:4566"
	nginxURL       = "http://localhost:4566/nginx-hello-world"
	updateInterval = 2 * time.Second
)

type tickMsg time.Time

type model struct {
	state  models.MonitorState
	width  int
	height int
	err    error
}

func initialModel() model {
	return model{
		state: models.MonitorState{
			Stats: models.Statistics{
				NginxStats:   make(map[string]*models.EndpointStats),
				ServiceStats: make(map[string]*models.ServiceStats),
				StartTime:    time.Now(),
			},
		},
	}
}

func (m model) Init() tea.Cmd {
	return tea.Batch(
		tickCmd(),
		tea.EnterAltScreen,
	)
}

func tickCmd() tea.Cmd {
	return tea.Tick(updateInterval, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			return m, tea.Quit
		case "r":
			// Force refresh
			return m, func() tea.Msg {
				return tickMsg(time.Now())
			}
		}

	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height

	case tickMsg:
		// Update monitoring data
		m.updateMonitoringData()
		return m, tickCmd()
	}

	return m, nil
}

func (m *model) updateMonitoringData() {
	m.state.UpdateCount++
	m.state.LastUpdate = time.Now()

	// Update Chaos API status
	m.updateChaosAPIStatus()

	// Update Nginx endpoints
	m.updateNginxEndpoints()

	// Update AWS services
	m.updateAWSServices()

	// Update statistics
	m.updateStatistics()

	// Detect active chaos tests
	m.detectActiveChaosTests()
}

func (m *model) updateChaosAPIStatus() {
	// Get faults
	resp, err := http.Get(baseURL + "/_localstack/chaos/faults")
	if err == nil && resp.StatusCode == 200 {
		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()

		var faults []models.ChaosAPIFault
		if err := json.Unmarshal(body, &faults); err == nil {
			m.state.ChaosAPIFaults = faults
		}
	}

	// Get effects
	resp, err = http.Get(baseURL + "/_localstack/chaos/effects")
	if err == nil && resp.StatusCode == 200 {
		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()

		var effects []models.ChaosAPIEffect
		if err := json.Unmarshal(body, &effects); err == nil {
			m.state.ChaosAPIEffects = effects
		}
	}
}

func (m *model) updateNginxEndpoints() {
	endpoints := []struct {
		name string
		url  string
	}{
		{"US-EAST-1", nginxURL + "/us-east-1.html"},
		{"US-EAST-2", nginxURL + "/us-east-2.html"},
		{"Main Site", nginxURL + "/index.html"},
	}

	m.state.NginxEndpoints = nil

	for _, ep := range endpoints {
		status := m.checkHTTPEndpoint(ep.url)
		status.Name = ep.name
		status.URL = ep.url
		m.state.NginxEndpoints = append(m.state.NginxEndpoints, status)
	}
}

func (m *model) checkHTTPEndpoint(url string) models.EndpointStatus {
	start := time.Now()
	status := models.EndpointStatus{
		LastChecked: start,
	}

	client := &http.Client{
		Timeout: 5 * time.Second,
	}

	resp, err := client.Get(url)
	if err != nil {
		if strings.Contains(err.Error(), "timeout") {
			status.Status = "timeout"
		} else {
			status.Status = "failed"
		}
		status.ResponseTime = time.Since(start).Seconds()
		return status
	}
	defer resp.Body.Close()

	status.HTTPCode = resp.StatusCode
	status.ResponseTime = time.Since(start).Seconds()

	if resp.StatusCode == 200 {
		status.Status = "ok"
	} else {
		status.Status = "failed"
	}

	return status
}

func (m *model) updateAWSServices() {
	services := []string{"s3", "dynamodb", "lambda"}
	m.state.AWSServices = nil

	for _, service := range services {
		status := m.checkAWSService(service)
		status.Name = strings.ToUpper(service)
		m.state.AWSServices = append(m.state.AWSServices, status)
	}
}

func (m *model) checkAWSService(service string) models.ServiceStatus {
	start := time.Now()
	status := models.ServiceStatus{
		LastChecked: start,
	}

	var cmd *exec.Cmd
	switch service {
	case "s3":
		cmd = exec.Command("docker", "run", "--rm", "--network", "host",
			"-e", "AWS_ACCESS_KEY_ID=test",
			"-e", "AWS_SECRET_ACCESS_KEY=test",
			"-e", "AWS_DEFAULT_REGION=us-east-1",
			"amazon/aws-cli",
			"--endpoint-url", baseURL,
			"s3", "ls")
	case "dynamodb":
		cmd = exec.Command("docker", "run", "--rm", "--network", "host",
			"-e", "AWS_ACCESS_KEY_ID=test",
			"-e", "AWS_SECRET_ACCESS_KEY=test",
			"-e", "AWS_DEFAULT_REGION=us-east-1",
			"amazon/aws-cli",
			"--endpoint-url", baseURL,
			"dynamodb", "list-tables")
	case "lambda":
		cmd = exec.Command("docker", "run", "--rm", "--network", "host",
			"-e", "AWS_ACCESS_KEY_ID=test",
			"-e", "AWS_SECRET_ACCESS_KEY=test",
			"-e", "AWS_DEFAULT_REGION=us-east-1",
			"amazon/aws-cli",
			"--endpoint-url", baseURL,
			"lambda", "list-functions")
	}

	var out bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &stderr

	err := cmd.Run()
	status.ResponseTime = time.Since(start).Seconds()

	output := out.String() + stderr.String()

	if err != nil {
		if strings.Contains(output, "ServiceUnavailable") || strings.Contains(output, "InternalError") {
			status.Status = "outage"
			status.FailureType = "service_outage"
		} else if strings.Contains(output, "SlowDown") || strings.Contains(output, "TooManyRequests") ||
			strings.Contains(output, "ThrottlingException") {
			status.Status = "throttled"
			status.FailureType = "throttled"
		} else if strings.Contains(output, "QuotaExceeded") || strings.Contains(output, "ResourceInUseException") {
			status.Status = "exhausted"
			status.FailureType = "resource_exhausted"
		} else {
			status.Status = "outage"
			status.FailureType = "error"
		}
	} else {
		status.Status = "healthy"
		status.FailureType = "ok"
	}

	return status
}

func (m *model) updateStatistics() {
	// Update Nginx stats
	for _, endpoint := range m.state.NginxEndpoints {
		stats, exists := m.state.Stats.NginxStats[endpoint.Name]
		if !exists {
			stats = &models.EndpointStats{}
			m.state.Stats.NginxStats[endpoint.Name] = stats
		}

		stats.TotalChecks++
		if endpoint.Status != "ok" {
			stats.Failures++
		}
		stats.SuccessRate = float64(stats.TotalChecks-stats.Failures) * 100 / float64(stats.TotalChecks)
	}

	// Update Service stats
	for _, service := range m.state.AWSServices {
		stats, exists := m.state.Stats.ServiceStats[service.Name]
		if !exists {
			stats = &models.ServiceStats{}
			m.state.Stats.ServiceStats[service.Name] = stats
		}

		stats.TotalChecks++
		switch service.FailureType {
		case "ok":
			stats.OKCount++
		case "throttled":
			stats.ThrottledCount++
		case "service_outage":
			stats.OutageCount++
		case "resource_exhausted":
			stats.ExhaustedCount++
		}
		stats.AvailabilityPct = float64(stats.OKCount) * 100 / float64(stats.TotalChecks)
	}
}

func (m *model) detectActiveChaosTests() {
	// Clear previous detections
	m.state.ActiveTests = []models.ActiveChaosTest{}

	// First check for test status files
	fileTests := monitor.DetectChaosTestFromFiles()
	m.state.ActiveTests = append(m.state.ActiveTests, fileTests...)

	// If we have file-based tests, don't do behavioral detection to avoid duplicates
	if len(fileTests) > 0 {
		return
	}

	// Otherwise, detect based on Chaos API and behavior
	// This provides backwards compatibility for tests that don't write status files
	
	// Detect based on Chaos API faults
	if len(m.state.ChaosAPIFaults) > 0 {
		for _, fault := range m.state.ChaosAPIFaults {
			testType := "service-outage"
			details := fmt.Sprintf("%.0f%% failure rate, Error %d", fault.Probability*100, fault.Error.StatusCode)
			
			// Check if it might be API throttling based on error code
			if fault.Error.StatusCode == 429 || strings.Contains(fault.Error.Code, "Throttl") {
				testType = "api-throttling"
				details = fmt.Sprintf("Rate limiting active, Error %d", fault.Error.StatusCode)
			}
			
			test := models.ActiveChaosTest{
				Type:      testType,
				Target:    fault.Service + " (" + fault.Region + ")",
				Status:    "active",
				StartTime: time.Now(),
				Details:   details,
			}
			m.state.ActiveTests = append(m.state.ActiveTests, test)
		}
	}

	// Detect network effects
	if len(m.state.ChaosAPIEffects) > 0 {
		for _, effect := range m.state.ChaosAPIEffects {
			test := models.ActiveChaosTest{
				Type:      "network-partition",
				Target:    "all services",
				Status:    "active",
				StartTime: time.Now(),
				Details:   fmt.Sprintf("%dms latency injected", effect.Latency),
			}
			m.state.ActiveTests = append(m.state.ActiveTests, test)
		}
	}
}

func (m model) View() string {
	if m.err != nil {
		return fmt.Sprintf("Error: %v\nPress 'q' to quit.", m.err)
	}

	if m.width == 0 || m.height == 0 {
		return "Initializing..."
	}

	return ui.RenderDashboard(&m.state, m.width, m.height)
}

func main() {
	// Check if LocalStack is running
	resp, err := http.Get(baseURL + "/_localstack/health")
	if err != nil || resp.StatusCode != 200 {
		fmt.Println("Error: LocalStack is not running at", baseURL)
		fmt.Println("Please start LocalStack with 'make start'")
		os.Exit(1)
	}

	p := tea.NewProgram(initialModel(), tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Printf("Error: %v", err)
		os.Exit(1)
	}
}