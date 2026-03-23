# RDP Defender - Examples

> **Copyright (c) 2025 Murr**  
> **Repository:** https://github.com/vtstv/WinRDPDefender  
> **License:** MIT License

## Installation

```powershell
# Basic installation (includes desktop shortcuts)
.\Install-RDPDefender.ps1

# With automated monitoring (recommended)
.\Install-RDPDefender.ps1 -CreateScheduledTasks

# Custom path
.\Install-RDPDefender.ps1 -InstallPath "D:\Security\RDPDefender" -CreateScheduledTasks

# Server installation without shortcuts
.\Install-RDPDefender.ps1 -CreateScheduledTasks -NoDesktopShortcuts
```

## Desktop Shortcuts

After installation, use shortcuts in **RDP Defender** folder:
- **Show Stats** - View security statistics
- **Generate Report** - Create HTML report
- **Quick Status** - Recent attacks overview
- **Management Console** - Interactive menu
- **Change RDP Port** - Port configuration

## Configuration

```powershell
# Conservative (low risk)
.\Install-RDPDefender.ps1 -MaxFailedAttempts 10 -TimeWindowMinutes 60 -BlockDurationHours 12 -CreateScheduledTasks

# Aggressive (high risk)
.\Install-RDPDefender.ps1 -MaxFailedAttempts 3 -TimeWindowMinutes 15 -BlockDurationHours 72 -CreateScheduledTasks

# Enterprise
.\Install-RDPDefender.ps1 -InstallPath "D:\Security\RDPDefender" -MaxFailedAttempts 5 -TimeWindowMinutes 30 -BlockDurationHours 48 -CreateScheduledTasks
```

## Commands

### Protection
```powershell
# Basic usage
.\RDPDefender.ps1

# Test mode
.\RDPDefender.ps1 -TestMode

# Custom settings
.\RDPDefender.ps1 -MaxFailedAttempts 3 -TimeWindowMinutes 15 -BlockDurationHours 48
```

### Monitoring
```powershell
# Statistics
.\RDPMonitor.ps1 -ShowStats

# HTML report (last 7 days)
.\RDPMonitor.ps1 -GenerateReport -DaysBack 7

# Export CSV
.\RDPMonitor.ps1 -ExportCSV -DaysBack 30
```

### Cleanup
```powershell
# Standard cleanup
.\CleanupTasks.ps1

# Preview only
.\CleanupTasks.ps1 -DryRun

# Custom settings
.\CleanupTasks.ps1 -CleanupDays 60 -MaxLogSizeMB 200
```

### RDP Port
```powershell
# Interactive menu
.\Change-RDPPort.ps1

# Check current port
.\Change-RDPPort.ps1 -CheckOnly

# Change port
.\Change-RDPPort.ps1 -NewPort 5555

# Restore default
.\Change-RDPPort.ps1 -RestoreDefault
```

## Troubleshooting

### Check blocks
```powershell
# List firewall rules
Get-NetFirewallRule -DisplayName "RDPDefender_Block_*" | Select-Object DisplayName, Enabled

# Check scheduled tasks
Get-ScheduledTask -TaskName "RDPDefender_*" | Select-Object TaskName, State
```

### Remove blocks
```powershell
# Remove all blocks
Get-NetFirewallRule -DisplayName "RDPDefender_Block_*" | Remove-NetFirewallRule
Get-ScheduledTask -TaskName "RDPDefender_Unblock_*" | Unregister-ScheduledTask -Confirm:$false
```

### View logs
```powershell
# Recent entries
Get-Content "C:\WinRDPDefender\Logs\RDPDefender.log" -Tail 50

# Real-time monitoring
Get-Content "C:\WinRDPDefender\Logs\RDPDefender.log" -Wait -Tail 10

# Search IP
Select-String -Path "C:\WinRDPDefender\Logs\RDPDefender.log" -Pattern "192.168.1.100"
```

## Firewall Management

```powershell
# Block IP manually
New-NetFirewallRule -DisplayName "Manual_Block_192.168.1.100" -Direction Inbound -RemoteAddress "192.168.1.100" -Action Block

# Unblock IP
Remove-NetFirewallRule -DisplayName "RDPDefender_Block_192_168_1_100"

# List blocked IPs
Get-NetFirewallRule -DisplayName "RDPDefender_Block_*" | 
    ForEach-Object { $_.DisplayName -replace "RDPDefender_Block_", "" -replace "_", "." }
```

## Scheduled Tasks

```powershell
# List tasks
Get-ScheduledTask -TaskName "RDPDefender_*" | Format-Table TaskName, State

# Change monitoring interval (3 minutes)
$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 3) -RepetitionDuration (New-TimeSpan -Days 365) -Once -At (Get-Date)
Set-ScheduledTask -TaskName "RDPDefender_Monitor" -Trigger $trigger

# Disable/enable
Disable-ScheduledTask -TaskName "RDPDefender_Monitor"
Enable-ScheduledTask -TaskName "RDPDefender_Monitor"

# Run immediately
Start-ScheduledTask -TaskName "RDPDefender_Monitor"
```

## Uninstallation

```powershell
# Standard uninstall
.\Uninstall-RDPDefender.ps1

# Preview only
.\Uninstall-RDPDefender.ps1 -DryRun

# Keep logs and reports
.\Uninstall-RDPDefender.ps1 -KeepLogs -KeepReports

# Force removal
.\Uninstall-RDPDefender.ps1 -Force

# Quick removal
.\Quick-Uninstall.ps1
```

### Verify removal
```powershell
Get-NetFirewallRule -DisplayName "RDPDefender_*" -ErrorAction SilentlyContinue
Get-ScheduledTask -TaskName "RDPDefender_*" -ErrorAction SilentlyContinue
Test-Path "C:\WinRDPDefender"
```