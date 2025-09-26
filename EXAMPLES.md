# RDP Defender - Quick Start Guide and Examples

> **Copyright (c) 2025 Murr**  
> **Repository:** https://github.com/vtstv/WinRDPDefender  
> **License:** MIT License

## Quick Start (5 Minutes Setup)

### Step 1: Installation
```powershell
# Open PowerShell as Administrator and run:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
cd "D:\Dev\WinRDPDefender"

# Basic installation to C:\WinRDPDefender (includes desktop shortcuts)
.\Install-RDPDefender.ps1

# Installation with automated monitoring (recommended)
.\Install-RDPDefender.ps1 -CreateScheduledTasks

# Custom installation path
.\Install-RDPDefender.ps1 -InstallPath "D:\Security\RDPDefender" -CreateScheduledTasks

# Server installation without desktop shortcuts
.\Install-RDPDefender.ps1 -CreateScheduledTasks -NoDesktopShortcuts
```

### Step 2: Using Desktop Shortcuts (Quickest Method)
After installation, simply double-click the desktop shortcuts:
- **RDP Defender - Show Stats**: Instantly view current security statistics
- **RDP Defender - Generate Report**: Create and open comprehensive HTML report
- **RDP Defender - Quick Status**: Fast check of recent attacks and active blocks
- **RDP Defender - Management Console**: Access PowerShell with helpful commands

### Step 3: Test the System
```powershell
# Run in test mode to verify functionality
.\RDPDefender.ps1 -TestMode

# Or use the Management Console shortcut and run:
# .\RDPDefender.ps1 -TestMode
```

### Step 4: Monitor Activity
```powershell
# View current statistics
.\RDPMonitor.ps1 -ShowStats
```

## Configuration Examples

### Conservative Setup (Low Security Risk Environment)
```powershell
# Allow more attempts, longer time window
.\Install-RDPDefender.ps1 -MaxFailedAttempts 10 -TimeWindowMinutes 60 -BlockDurationHours 12 -CreateScheduledTasks
```

### Aggressive Setup (High Security Risk Environment)
```powershell
# Strict blocking with shorter time windows
.\Install-RDPDefender.ps1 -MaxFailedAttempts 3 -TimeWindowMinutes 15 -BlockDurationHours 72 -CreateScheduledTasks
```

### Enterprise Setup
```powershell
# Professional environment configuration
.\Install-RDPDefender.ps1 -InstallPath "D:\Security\RDPDefender" -MaxFailedAttempts 5 -TimeWindowMinutes 30 -BlockDurationHours 48 -CreateScheduledTasks
```

## Common Use Cases

### Home Office / Small Business
- **Failed Attempts**: 5-7
- **Time Window**: 30-60 minutes
- **Block Duration**: 24 hours
- **Monitoring**: Manual checks weekly

### Corporate Environment
- **Failed Attempts**: 3-5
- **Time Window**: 15-30 minutes
- **Block Duration**: 48 hours
- **Monitoring**: Automated daily reports

### High-Security Environment
- **Failed Attempts**: 2-3
- **Time Window**: 10-15 minutes
- **Block Duration**: 72+ hours
- **Monitoring**: Real-time monitoring

## Command Reference

### Main Protection Script
```powershell
# Basic usage
.\RDPDefender.ps1

# Test mode (no actual blocking)
.\RDPDefender.ps1 -TestMode

# Custom settings
.\RDPDefender.ps1 -MaxFailedAttempts 3 -TimeWindowMinutes 15 -BlockDurationHours 48

# Specify custom log path
.\RDPDefender.ps1 -LogPath "D:\Security\RDPDefender\Logs"
```

### Monitoring and Reports
```powershell
# Show current statistics
.\RDPMonitor.ps1 -ShowStats

# Analyze last 24 hours
.\RDPMonitor.ps1 -ShowStats -DaysBack 1

# Generate HTML report
.\RDPMonitor.ps1 -GenerateReport -DaysBack 7

# Export to CSV
.\RDPMonitor.ps1 -ExportCSV -DaysBack 30

# Comprehensive analysis with report
.\RDPMonitor.ps1 -ShowStats -GenerateReport -ExportCSV -DaysBack 14
```

### Cleanup and Maintenance
```powershell
# Standard cleanup
.\CleanupTasks.ps1

# Preview changes without executing
.\CleanupTasks.ps1 -DryRun

# Custom cleanup settings
.\CleanupTasks.ps1 -CleanupDays 60 -MaxLogSizeMB 200

# Aggressive cleanup for disk space
.\CleanupTasks.ps1 -CleanupDays 7 -MaxLogSizeMB 50
```

## Troubleshooting Commands

### Check Current Blocks
```powershell
# List all RDP Defender firewall rules
Get-NetFirewallRule -DisplayName "RDPDefender_Block_*" | Select-Object DisplayName, Enabled, Action

# Check scheduled tasks
Get-ScheduledTask -TaskName "RDPDefender_*" | Select-Object TaskName, State, LastRunTime
```

### Remove All Blocks (Emergency)
```powershell
# Remove all RDP Defender firewall rules
Get-NetFirewallRule -DisplayName "RDPDefender_Block_*" | Remove-NetFirewallRule

# Remove all scheduled unblock tasks
Get-ScheduledTask -TaskName "RDPDefender_Unblock_*" | Unregister-ScheduledTask -Confirm:$false
```

### Check Recent RDP Events
```powershell
# Show recent failed RDP attempts
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4625; StartTime=(Get-Date).AddHours(-24)} | 
    Select-Object TimeCreated, Message | Format-Table -Wrap

# Show recent successful RDP logins
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4624; StartTime=(Get-Date).AddHours(-24)} |
    Select-Object TimeCreated, Message | Format-Table -Wrap
```

### View Logs
```powershell
# Show recent log entries
Get-Content "C:\WinRDPDefender\Logs\RDPDefender.log" -Tail 50

# Monitor log in real-time
Get-Content "C:\WinRDPDefender\Logs\RDPDefender.log" -Wait -Tail 10

# Search for specific IP in logs
Select-String -Path "C:\WinRDPDefender\Logs\RDPDefender.log" -Pattern "192.168.1.100"
```

## Firewall Rules Management

### Manual Firewall Operations
```powershell
# Block specific IP manually
New-NetFirewallRule -DisplayName "Manual_Block_192.168.1.100" -Direction Inbound -RemoteAddress "192.168.1.100" -Action Block

# Unblock specific IP
Remove-NetFirewallRule -DisplayName "RDPDefender_Block_192_168_1_100"

# List all blocked IPs
Get-NetFirewallRule -DisplayName "RDPDefender_Block_*" | 
    ForEach-Object { $_.DisplayName -replace "RDPDefender_Block_", "" -replace "_", "." }
```

## Scheduled Tasks Configuration

### View Current Tasks
```powershell
# List all RDP Defender tasks
Get-ScheduledTask -TaskName "RDPDefender_*" | Format-Table TaskName, State, LastRunTime, NextRunTime

# View task details
Get-ScheduledTask -TaskName "RDPDefender_Monitor" | Get-ScheduledTaskInfo
```

### Modify Task Frequency
```powershell
# Change monitoring interval to 3 minutes
$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 3) -RepetitionDuration (New-TimeSpan -Days 365) -Once -At (Get-Date)
Set-ScheduledTask -TaskName "RDPDefender_Monitor" -Trigger $trigger
```

### Disable/Enable Tasks
```powershell
# Disable monitoring
Disable-ScheduledTask -TaskName "RDPDefender_Monitor"

# Enable monitoring
Enable-ScheduledTask -TaskName "RDPDefender_Monitor"

# Run task immediately
Start-ScheduledTask -TaskName "RDPDefender_Monitor"
```

## Performance Optimization

### Reduce Resource Usage
```powershell
# Less frequent monitoring (every 10 minutes)
$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 10) -RepetitionDuration (New-TimeSpan -Days 365) -Once -At (Get-Date)
Set-ScheduledTask -TaskName "RDPDefender_Monitor" -Trigger $trigger

# Smaller time window analysis
.\RDPDefender.ps1 -TimeWindowMinutes 15
```

### Log Management
```powershell
# Aggressive log rotation
.\CleanupTasks.ps1 -MaxLogSizeMB 10 -CleanupDays 7

# Archive old logs instead of deleting
$oldLogs = Get-ChildItem "C:\WinRDPDefender\Logs\*.log" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }
foreach ($log in $oldLogs) {
    Compress-Archive -Path $log.FullName -DestinationPath "C:\WinRDPDefender\Logs\Archive\$($log.BaseName)_$(Get-Date -Format 'yyyyMMdd').zip"
    Remove-Item $log.FullName
}
```

## Integration Examples

### PowerBI Dashboard
```powershell
# Export data for PowerBI analysis
.\RDPMonitor.ps1 -ExportCSV -DaysBack 90
# Import the CSV file into PowerBI for visualization
```

### SIEM Integration
```powershell
# Export events for SIEM systems
$events = .\RDPMonitor.ps1 -DaysBack 1
$events | ConvertTo-Json | Out-File "C:\SIEM\RDPEvents_$(Get-Date -Format 'yyyyMMdd').json"
```

### Custom Alerting
```powershell
# Custom notification script (add to RDPDefender.ps1 after blocking)
$webhook = "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
$payload = @{
    text = "RDP Attack detected and blocked on server $env:COMPUTERNAME"
    channel = "#security"
    username = "RDP Defender"
} | ConvertTo-Json

Invoke-RestMethod -Uri $webhook -Method Post -Body $payload -ContentType 'application/json'
```

## Monitoring Different Scenarios

### Daily Security Check
```powershell
# Morning security briefing
.\RDPMonitor.ps1 -ShowStats -DaysBack 1
.\RDPDefender.ps1 -TestMode # Check system health
```

### Weekly Security Report
```powershell
# Generate comprehensive weekly report
.\RDPMonitor.ps1 -GenerateReport -ExportCSV -DaysBack 7
```

### Security Incident Response
```powershell
# When under active attack
.\RDPMonitor.ps1 -ShowStats -DaysBack 0.5  # Last 12 hours
Get-NetFirewallRule -DisplayName "RDPDefender_Block_*" | Measure-Object  # Count blocked IPs
```

## Uninstallation Examples

### Safe Removal (Recommended)
```powershell
# Standard uninstallation with confirmation
.\Uninstall-RDPDefender.ps1

# Preview what will be removed (no actual changes)
.\Uninstall-RDPDefender.ps1 -DryRun

# Keep historical data for analysis
.\Uninstall-RDPDefender.ps1 -KeepLogs -KeepReports

# Force removal without prompts
.\Uninstall-RDPDefender.ps1 -Force
```

### Emergency Removal
```powershell
# Immediate complete removal (no confirmations)
.\Quick-Uninstall.ps1

# Quick removal from custom path
.\Quick-Uninstall.ps1 -InstallPath "D:\Security\RDPDefender"
```

### Uninstall Verification
```powershell
# Verify all components are removed
Get-NetFirewallRule -DisplayName "RDPDefender_*" -ErrorAction SilentlyContinue
Get-ScheduledTask -TaskName "RDPDefender_*" -ErrorAction SilentlyContinue
Test-Path "C:\WinRDPDefender"

# Check for backup locations (when using -KeepLogs/-KeepReports)
Get-ChildItem "$env:TEMP\RDPDefender_*_Backup_*" -ErrorAction SilentlyContinue
```

### Troubleshooting Uninstall Issues
```powershell
# If standard uninstall fails, try force mode
.\Uninstall-RDPDefender.ps1 -Force

# Manual cleanup if uninstaller fails
Get-NetFirewallRule -DisplayName "RDPDefender_*" | Remove-NetFirewallRule
Get-ScheduledTask -TaskName "RDPDefender_*" | Unregister-ScheduledTask -Confirm:$false
Remove-Item "C:\WinRDPDefender" -Recurse -Force -ErrorAction SilentlyContinue

# View uninstaller log for troubleshooting
Get-Content "$env:TEMP\RDPDefender_Uninstall.log" -Tail 20
```

This guide provides practical examples for implementing, managing, and removing RDP Defender in your Windows Server 2025 environment with simplified configuration.