# Automated Cleanup Script for RDP Defender
# This script removes old blocked IPs and cleans up logs
#
# Copyright (c) 2025 Murr
# Repository: https://github.com/vtstv/WinRDPDefender
# Licensed under MIT License

param(
    [int]$CleanupDays = 30,
    [string]$LogPath = "C:\WinRDPDefender\Logs",
    [int]$MaxLogSizeMB = 100,
    [switch]$DryRun = $false
)

# Function to write log entries
function Write-CleanupLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    if (Test-Path $LogPath) {
        Add-Content -Path "$LogPath\Cleanup.log" -Value $logEntry
    }
}

# Function to clean up old firewall rules
function Remove-ExpiredFirewallRules {
    Write-CleanupLog "Checking for expired RDP Defender firewall rules..."
    
    $rules = Get-NetFirewallRule -DisplayName "RDPDefender_Block_*" -ErrorAction SilentlyContinue
    $removedCount = 0
    
    foreach ($rule in $rules) {
        # Check if the corresponding scheduled task exists
        $taskName = $rule.DisplayName -replace "RDPDefender_Block_", "RDPDefender_Unblock_"
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        
        if (!$task) {
            # Task doesn't exist, rule might be expired
            if (!$DryRun) {
                Remove-NetFirewallRule -DisplayName $rule.DisplayName
                Write-CleanupLog "Removed expired firewall rule: $($rule.DisplayName)" "INFO"
                $removedCount++
            } else {
                Write-CleanupLog "[DRY RUN] Would remove expired firewall rule: $($rule.DisplayName)" "INFO"
                $removedCount++
            }
        }
    }
    
    Write-CleanupLog "Removed $removedCount expired firewall rules"
}

# Function to clean up old scheduled tasks
function Remove-ExpiredScheduledTasks {
    Write-CleanupLog "Checking for expired RDP Defender scheduled tasks..."
    
    $tasks = Get-ScheduledTask -TaskName "RDPDefender_Unblock_*" -ErrorAction SilentlyContinue
    $removedCount = 0
    
    foreach ($task in $tasks) {
        $lastRunTime = $task.LastRunTime
        if ($lastRunTime -and $lastRunTime -lt (Get-Date).AddDays(-$CleanupDays)) {
            if (!$DryRun) {
                Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false
                Write-CleanupLog "Removed expired scheduled task: $($task.TaskName)" "INFO"
                $removedCount++
            } else {
                Write-CleanupLog "[DRY RUN] Would remove expired scheduled task: $($task.TaskName)" "INFO"
                $removedCount++
            }
        }
    }
    
    Write-CleanupLog "Removed $removedCount expired scheduled tasks"
}

# Function to rotate log files
function Invoke-LogRotation {
    Write-CleanupLog "Checking log files for rotation..."
    
    if (!(Test-Path $LogPath)) {
        Write-CleanupLog "Log directory does not exist: $LogPath" "WARNING"
        return
    }
    
    $logFiles = Get-ChildItem -Path $LogPath -Filter "*.log"
    
    foreach ($logFile in $logFiles) {
        $fileSizeMB = [Math]::Round($logFile.Length / 1MB, 2)
        
        if ($fileSizeMB -gt $MaxLogSizeMB) {
            $backupName = "$($logFile.BaseName)_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
            $backupPath = Join-Path $LogPath $backupName
            
            if (!$DryRun) {
                Move-Item -Path $logFile.FullName -Destination $backupPath
                New-Item -ItemType File -Path $logFile.FullName | Out-Null
                Write-CleanupLog "Rotated log file: $($logFile.Name) (${fileSizeMB}MB) -> $backupName" "INFO"
            } else {
                Write-CleanupLog "[DRY RUN] Would rotate log file: $($logFile.Name) (${fileSizeMB}MB)" "INFO"
            }
        }
    }
    
    # Clean up old backup log files
    $oldBackups = Get-ChildItem -Path $LogPath -Filter "*_*.log" | Where-Object { 
        $_.LastWriteTime -lt (Get-Date).AddDays(-$CleanupDays) 
    }
    
    foreach ($backup in $oldBackups) {
        if (!$DryRun) {
            Remove-Item -Path $backup.FullName -Force
            Write-CleanupLog "Removed old backup log: $($backup.Name)" "INFO"
        } else {
            Write-CleanupLog "[DRY RUN] Would remove old backup log: $($backup.Name)" "INFO"
        }
    }
}

# Function to clean up old event log entries (if needed)
function Invoke-EventLogCleanup {
    Write-CleanupLog "Checking Windows Event Log size..."
    
    try {
        $securityLog = Get-WinEvent -ListLog Security
        $maxSizeMB = [Math]::Round($securityLog.MaximumSizeInBytes / 1MB, 0)
        $currentSizeMB = [Math]::Round($securityLog.FileSize / 1MB, 2)
        
        Write-CleanupLog "Security Event Log: ${currentSizeMB}MB / ${maxSizeMB}MB"
        
        if ($currentSizeMB / $maxSizeMB -gt 0.9) {
            Write-CleanupLog "Security Event Log is over 90% full. Consider archiving old events." "WARNING"
        }
    } catch {
        Write-CleanupLog "Could not check Event Log size: $($_.Exception.Message)" "WARNING"
    }
}

# Function to generate cleanup report
function New-CleanupReport {
    $reportPath = Join-Path $LogPath "cleanup_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    
    $report = @"
RDP Defender Cleanup Report
===========================
Generated: $(Get-Date)
Server: $env:COMPUTERNAME

Configuration:
- Cleanup Days: $CleanupDays
- Max Log Size: ${MaxLogSizeMB}MB
- Dry Run Mode: $DryRun

Current Status:
"@

    # Check firewall rules
    $currentRules = Get-NetFirewallRule -DisplayName "RDPDefender_Block_*" -ErrorAction SilentlyContinue
    $report += "`n- Active Firewall Rules: $($currentRules.Count)"
    
    # Check scheduled tasks
    $currentTasks = Get-ScheduledTask -TaskName "RDPDefender_Unblock_*" -ErrorAction SilentlyContinue
    $report += "`n- Active Scheduled Tasks: $($currentTasks.Count)"
    
    # Check log files
    if (Test-Path $LogPath) {
        $logFiles = Get-ChildItem -Path $LogPath -Filter "*.log"
        $totalLogSizeMB = [Math]::Round(($logFiles | Measure-Object Length -Sum).Sum / 1MB, 2)
        $report += "`n- Log Files: $($logFiles.Count)"
        $report += "`n- Total Log Size: ${totalLogSizeMB}MB"
    }
    
    $report += "`n`nCleanup completed at: $(Get-Date)"
    
    if (!$DryRun) {
        $report | Out-File -FilePath $reportPath -Encoding UTF8
        Write-CleanupLog "Cleanup report saved: $reportPath"
    } else {
        Write-Host $report
    }
}

# Main execution
Write-CleanupLog "=== RDP Defender Cleanup Started ===" "INFO"

if ($DryRun) {
    Write-CleanupLog "Running in DRY RUN mode - no changes will be made" "WARNING"
}

# Ensure script runs with administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-CleanupLog "This script must be run as Administrator!" "ERROR"
    exit 1
}

# Create log directory if it doesn't exist
if (!(Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
    Write-CleanupLog "Created log directory: $LogPath"
}

# Perform cleanup tasks
Remove-ExpiredFirewallRules
Remove-ExpiredScheduledTasks
Invoke-LogRotation
Invoke-EventLogCleanup

# Generate report
New-CleanupReport

Write-CleanupLog "=== RDP Defender Cleanup Completed ===" "INFO"