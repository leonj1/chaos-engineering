package monitor

import (
	"chaos-monitor-tui/models"
	"encoding/json"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// TestStatusFile represents the structure of a chaos test status file
type TestStatusFile struct {
	TestType    string    `json:"test_type"`
	Target      string    `json:"target"`
	Status      string    `json:"status"`
	StartTime   time.Time `json:"start_time"`
	Details     string    `json:"details"`
	PID         int       `json:"pid,omitempty"`
}

// DetectChaosTestFromFiles checks for chaos test status files
func DetectChaosTestFromFiles() []models.ActiveChaosTest {
	var tests []models.ActiveChaosTest
	
	// Check common locations for test status files
	statusDirs := []string{
		"/tmp/chaos-tests",
		"/var/tmp/chaos-tests",
		"./chaos-tests/status",
	}
	
	for _, dir := range statusDirs {
		if _, err := os.Stat(dir); os.IsNotExist(err) {
			continue
		}
		
		files, err := ioutil.ReadDir(dir)
		if err != nil {
			continue
		}
		
		for _, file := range files {
			if strings.HasSuffix(file.Name(), ".status.json") {
				fullPath := filepath.Join(dir, file.Name())
				if test := readTestStatusFile(fullPath); test != nil {
					tests = append(tests, *test)
				}
			}
		}
	}
	
	return tests
}

func readTestStatusFile(path string) *models.ActiveChaosTest {
	data, err := ioutil.ReadFile(path)
	if err != nil {
		return nil
	}
	
	var status TestStatusFile
	if err := json.Unmarshal(data, &status); err != nil {
		return nil
	}
	
	// Check if test is still active (file modified within last 5 minutes)
	info, err := os.Stat(path)
	if err != nil {
		return nil
	}
	
	if time.Since(info.ModTime()) > 5*time.Minute {
		// Test is probably stale
		return nil
	}
	
	// Check if process is still running (if PID is provided)
	if status.PID > 0 {
		if !isProcessRunning(status.PID) {
			// Process has ended, test might be complete
			status.Status = "completed"
		}
	}
	
	return &models.ActiveChaosTest{
		Type:      status.TestType,
		Target:    status.Target,
		Status:    status.Status,
		StartTime: status.StartTime,
		Details:   status.Details,
	}
}

func isProcessRunning(pid int) bool {
	// Check if process exists by sending signal 0
	process, err := os.FindProcess(pid)
	if err != nil {
		return false
	}
	
	err = process.Signal(os.Signal(nil))
	return err == nil
}

// DetectFromProcessList checks running processes for chaos test scripts
func DetectFromProcessList() []models.ActiveChaosTest {
	var tests []models.ActiveChaosTest
	
	// This is a simplified version - in production you'd use proper process listing
	// For now, we'll check for common python scripts
	
	return tests
}

// FormatTestType converts test script names to readable test types
func FormatTestType(scriptName string) string {
	typeMap := map[string]string{
		"region_failure.py":     "region-failure",
		"latency_injection.py":  "latency-injection",
		"service_outage.py":     "service-outage",
		"api_throttling.py":     "api-throttling",
		"cascade_failure.py":    "cascade-failure",
		"network_partition.py":  "network-partition",
		"resource_exhaustion.py": "resource-exhaustion",
	}
	
	for script, testType := range typeMap {
		if strings.Contains(scriptName, script) {
			return testType
		}
	}
	
	return "unknown"
}