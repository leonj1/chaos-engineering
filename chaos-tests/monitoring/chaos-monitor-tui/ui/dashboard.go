package ui

import (
	"fmt"
	"strings"
	"time"

	"chaos-monitor-tui/models"

	"github.com/charmbracelet/lipgloss"
)

var (
	// Colors
	successColor = lipgloss.Color("#00ff00")  // Bright green
	warningColor = lipgloss.Color("#ffaa00")  // Orange/yellow
	errorColor   = lipgloss.Color("#ff0000")  // Bright red
	infoColor    = lipgloss.Color("#00aaff")  // Light blue
	dimColor     = lipgloss.Color("#666666")  // Gray
	purpleColor  = lipgloss.Color("#aa00ff")  // Purple

	// Styles
	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#ffffff")).
			Background(lipgloss.Color("#5a56e0")).
			Padding(0, 1)

	sectionStyle = lipgloss.NewStyle().
			BorderStyle(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("#5a56e0")).
			Padding(0, 1)

	headerStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(infoColor).
			MarginBottom(1)

	statusOKStyle = lipgloss.NewStyle().
			Foreground(successColor).
			Bold(true)

	statusWarningStyle = lipgloss.NewStyle().
				Foreground(warningColor).
				Bold(true)

	statusErrorStyle = lipgloss.NewStyle().
			Foreground(errorColor).
			Bold(true)

	statusExhaustedStyle = lipgloss.NewStyle().
				Foreground(purpleColor).
				Bold(true)

	dimStyle = lipgloss.NewStyle().
			Foreground(dimColor)
			
	// Availability styles based on percentage
	availHighStyle = lipgloss.NewStyle().
			Foreground(successColor)  // Green for > 90%
			
	availMedStyle = lipgloss.NewStyle().
			Foreground(warningColor)  // Yellow for 50-90%
			
	availLowStyle = lipgloss.NewStyle().
			Foreground(errorColor)    // Red for < 50%
)

// RenderDashboard creates the complete dashboard view
func RenderDashboard(state *models.MonitorState, width, height int) string {
	var sections []string

	// Title bar
	title := titleStyle.Width(width - 2).Render(
		fmt.Sprintf("🔍 Chaos Engineering Monitor | %s | Updates: %d | Press 'q' to quit",
			time.Now().Format("15:04:05"),
			state.UpdateCount,
		),
	)
	sections = append(sections, title)

	// Chaos API Status
	chaosSection := renderChaosAPIStatus(state, width)
	sections = append(sections, chaosSection)

	// Nginx Web Servers
	nginxSection := renderNginxStatus(state, width)
	sections = append(sections, nginxSection)

	// AWS Services
	servicesSection := renderServicesStatus(state, width)
	sections = append(sections, servicesSection)

	// Statistics
	statsSection := renderStatistics(state, width)
	sections = append(sections, statsSection)

	return lipgloss.JoinVertical(lipgloss.Left, sections...)
}

func renderChaosAPIStatus(state *models.MonitorState, width int) string {
	var content strings.Builder

	content.WriteString(headerStyle.Render("ACTIVE CHAOS TESTS"))

	// Show detected active tests first
	if len(state.ActiveTests) > 0 {
		for _, test := range state.ActiveTests {
			var testStyle lipgloss.Style
			var icon string
			
			switch test.Type {
			case "region-failure":
				testStyle = statusErrorStyle
				icon = "🔥"
			case "service-outage":
				testStyle = statusErrorStyle
				icon = "⚠️"
			case "api-throttling":
				testStyle = statusWarningStyle
				icon = "🚦"
			case "network-latency":
				testStyle = statusWarningStyle
				icon = "🌐"
			case "cascade-failure":
				testStyle = statusErrorStyle
				icon = "📉"
			case "resource-exhaustion":
				testStyle = statusExhaustedStyle
				icon = "💾"
			default:
				testStyle = statusWarningStyle
				icon = "🧪"
			}
			
			content.WriteString(fmt.Sprintf("%s %s: %s\n", 
				icon,
				testStyle.Render(strings.ToUpper(test.Type)),
				test.Target))
			content.WriteString(fmt.Sprintf("   └─ %s\n", dimStyle.Render(test.Details)))
		}
		content.WriteString("\n")
	}

	// Then show raw Chaos API data
	if len(state.ChaosAPIFaults) == 0 && len(state.ChaosAPIEffects) == 0 && len(state.ActiveTests) == 0 {
		content.WriteString(statusOKStyle.Render("✓ No active chaos tests detected\n"))
	} else if len(state.ChaosAPIFaults) > 0 || len(state.ChaosAPIEffects) > 0 {
		content.WriteString(dimStyle.Render("Chaos API Configurations:\n"))
		
		if len(state.ChaosAPIFaults) > 0 {
			faultStyle := statusWarningStyle
			content.WriteString(faultStyle.Render(fmt.Sprintf("├─ Service Faults: %d active\n", len(state.ChaosAPIFaults))))
			for i, fault := range state.ChaosAPIFaults {
				prefix := "│  ├─"
				if i == len(state.ChaosAPIFaults)-1 {
					prefix = "│  └─"
				}
				
				// Color based on probability
				var probStyle lipgloss.Style
				if fault.Probability >= 0.8 {
					probStyle = statusErrorStyle
				} else if fault.Probability >= 0.5 {
					probStyle = statusWarningStyle
				} else {
					probStyle = dimStyle
				}
				
				content.WriteString(fmt.Sprintf("%s %s (%s): %s\n",
					prefix, fault.Service, fault.Region, 
					probStyle.Render(fmt.Sprintf("%.0f%% failure rate", fault.Probability*100))))
			}
		}

		if len(state.ChaosAPIEffects) > 0 {
			effectStyle := statusWarningStyle
			content.WriteString(effectStyle.Render(fmt.Sprintf("└─ Network Effects: %d active\n", len(state.ChaosAPIEffects))))
			for _, effect := range state.ChaosAPIEffects {
				// Color based on latency severity
				var latencyStyle lipgloss.Style
				if effect.Latency >= 5000 {
					latencyStyle = statusErrorStyle
				} else if effect.Latency >= 1000 {
					latencyStyle = statusWarningStyle
				} else {
					latencyStyle = dimStyle
				}
				
				content.WriteString(fmt.Sprintf("   └─ Latency: %s\n", 
					latencyStyle.Render(fmt.Sprintf("%dms", effect.Latency))))
			}
		}
	}

	return sectionStyle.Width(width - 2).Render(content.String())
}

func renderNginxStatus(state *models.MonitorState, width int) string {
	var content strings.Builder

	content.WriteString(headerStyle.Render("NGINX WEB SERVERS"))
	content.WriteString(fmt.Sprintf("%-30s %-10s %s\n", "Endpoint", "Status", "Response"))

	// Check if main site is down
	mainSiteDown := false
	for _, endpoint := range state.NginxEndpoints {
		if endpoint.Name == "Main Site" && endpoint.Status != "ok" {
			mainSiteDown = true
			break
		}
	}

	for _, endpoint := range state.NginxEndpoints {
		statusIcon, statusStyle := getStatusDisplay(endpoint.Status)
		
		// Special handling for main site - always red if down
		if endpoint.Name == "Main Site" && endpoint.Status != "ok" {
			statusStyle = statusErrorStyle
		}
		
		// Color the endpoint name based on importance
		endpointStyle := lipgloss.NewStyle()
		if mainSiteDown && endpoint.Name == "Main Site" {
			endpointStyle = statusErrorStyle
		}
		
		content.WriteString(fmt.Sprintf("├─ %-28s %s %-8s %s\n",
			endpointStyle.Render(endpoint.Name),
			statusStyle.Render(statusIcon),
			statusStyle.Render(strings.ToUpper(endpoint.Status)),
			dimStyle.Render(fmt.Sprintf("%.3fs", endpoint.ResponseTime)),
		))
	}

	// Calculate and display availability with colors
	if len(state.Stats.NginxStats) > 0 {
		content.WriteString("\nAvailability: ")
		var availParts []string
		for name, stats := range state.Stats.NginxStats {
			// Color based on availability percentage
			var style lipgloss.Style
			if stats.SuccessRate >= 90 {
				style = availHighStyle
			} else if stats.SuccessRate >= 50 {
				style = availMedStyle
			} else {
				style = availLowStyle
			}
			availParts = append(availParts, style.Render(fmt.Sprintf("%s: %.1f%%", name, stats.SuccessRate)))
		}
		content.WriteString(strings.Join(availParts, " | "))
	}

	return sectionStyle.Width(width - 2).Render(content.String())
}

func renderServicesStatus(state *models.MonitorState, width int) string {
	var content strings.Builder

	content.WriteString(headerStyle.Render("AWS SERVICES"))
	content.WriteString(fmt.Sprintf("%-20s %-10s %s\n", "Service", "Status", "Response"))

	for _, service := range state.AWSServices {
		statusIcon, statusStyle := getServiceStatusDisplay(service.Status)
		content.WriteString(fmt.Sprintf("├─ %-18s %s %-8s %s\n",
			service.Name,
			statusStyle.Render(statusIcon),
			statusStyle.Render(strings.ToUpper(service.Status[:6])),
			dimStyle.Render(fmt.Sprintf("%.3fs", service.ResponseTime)),
		))
	}

	return sectionStyle.Width(width - 2).Render(content.String())
}

func renderStatistics(state *models.MonitorState, width int) string {
	var content strings.Builder

	content.WriteString(headerStyle.Render("STATISTICS"))

	// Nginx stats with colors
	if len(state.Stats.NginxStats) > 0 {
		content.WriteString("Nginx: ")
		var nginxParts []string
		for name, stats := range state.Stats.NginxStats {
			// Color based on success rate
			var style lipgloss.Style
			if stats.SuccessRate >= 90 {
				style = availHighStyle
			} else if stats.SuccessRate >= 50 {
				style = availMedStyle
			} else {
				style = availLowStyle
			}
			nginxParts = append(nginxParts, style.Render(fmt.Sprintf("%s: %d/%d (%.1f%%)",
				name, stats.TotalChecks-stats.Failures, stats.TotalChecks, stats.SuccessRate)))
		}
		content.WriteString(strings.Join(nginxParts, " | "))
		content.WriteString("\n")
	}

	// Service stats with colors
	if len(state.Stats.ServiceStats) > 0 {
		content.WriteString("Services: ")
		var serviceParts []string
		for name, stats := range state.Stats.ServiceStats {
			// Color based on availability
			var style lipgloss.Style
			if stats.AvailabilityPct >= 90 {
				style = availHighStyle
			} else if stats.AvailabilityPct >= 50 {
				style = availMedStyle
			} else {
				style = availLowStyle
			}
			serviceParts = append(serviceParts, style.Render(fmt.Sprintf("%s: %.0f%%", name, stats.AvailabilityPct)))
		}
		content.WriteString(strings.Join(serviceParts, " | "))
	}

	// Uptime
	uptime := time.Since(state.Stats.StartTime)
	content.WriteString(fmt.Sprintf("\nUptime: %s", uptime.Round(time.Second)))

	return sectionStyle.Width(width - 2).Render(content.String())
}

func getStatusDisplay(status string) (string, lipgloss.Style) {
	switch status {
	case "ok":
		return "✓", statusOKStyle
	case "failed":
		return "✗", statusErrorStyle
	case "timeout":
		return "⏱", statusWarningStyle
	default:
		return "?", dimStyle
	}
}

func getServiceStatusDisplay(status string) (string, lipgloss.Style) {
	switch status {
	case "healthy":
		return "✓", statusOKStyle
	case "throttled":
		return "⚠", statusWarningStyle
	case "outage":
		return "✗", statusErrorStyle
	case "exhausted":
		return "◆", statusExhaustedStyle
	default:
		return "?", dimStyle
	}
}