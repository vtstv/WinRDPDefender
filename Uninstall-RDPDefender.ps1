# RDP Defender Uninstaller Script
# This script completely removes all components installed by RDP Defender
#
# Copyright (c) 2025 Murr
# Repository: https://github.com/vtstv/WinRDPDefender
# Licensed under MIT License

param(
    [string]$InstallPath = "C:\WinRDPDefender",
    [switch]$KeepLogs = $false,
    [switch]$KeepReports = $false,
    [switch]$Force = $false,
    [switch]$DryRun = $false
)

# Function to write uninstall log
function Write-UninstallLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    Write-Host $logEntry -ForegroundColor $(
        switch ($Level) {
            "INFO" { "White" }
            "WARNING" { "Yellow" }
            "ERROR" { "Red" }
            "SUCCESS" { "Green" }
            default { "Gray" }
        }
    )
    
    # Also write to temp log file for record keeping
    $tempLogPath = "$env:TEMP\RDPDefender_Uninstall.log"
    Add-Content -Path $tempLogPath -Value $logEntry -ErrorAction SilentlyContinue
}

# Function to remove all RDP Defender firewall rules
function Remove-RDPDefenderFirewallRules {
    Write-UninstallLog "Checking for RDP Defender firewall rules..." "INFO"
    
    try {
        $rules = Get-NetFirewallRule -DisplayName "RDPDefender_Block_*" -ErrorAction SilentlyContinue
        
        if ($rules) {
            $ruleCount = ($rules | Measure-Object).Count
            Write-UninstallLog "Found $ruleCount RDP Defender firewall rules" "INFO"
            
            foreach ($rule in $rules) {
                if ($DryRun) {
                    Write-UninstallLog "[DRY RUN] Would remove firewall rule: $($rule.DisplayName)" "INFO"
                } else {
                    try {
                        Remove-NetFirewallRule -DisplayName $rule.DisplayName -ErrorAction Stop
                        Write-UninstallLog "Removed firewall rule: $($rule.DisplayName)" "SUCCESS"
                    } catch {
                        Write-UninstallLog "Failed to remove firewall rule $($rule.DisplayName): $($_.Exception.Message)" "ERROR"
                    }
                }
            }
            
            if (-not $DryRun) {
                Write-UninstallLog "Removed $ruleCount firewall rules" "SUCCESS"
            }
        } else {
            Write-UninstallLog "No RDP Defender firewall rules found" "INFO"
        }
    } catch {
        Write-UninstallLog "Error checking firewall rules: $($_.Exception.Message)" "ERROR"
    }
}

# Function to remove all RDP Defender scheduled tasks
function Remove-RDPDefenderScheduledTasks {
    Write-UninstallLog "Checking for RDP Defender scheduled tasks..." "INFO"
    
    try {
        $tasks = Get-ScheduledTask -TaskName "RDPDefender_Unblock_*" -ErrorAction SilentlyContinue
        
        if ($tasks) {
            $taskCount = ($tasks | Measure-Object).Count
            Write-UninstallLog "Found $taskCount RDP Defender scheduled tasks" "INFO"
            
            foreach ($task in $tasks) {
                if ($DryRun) {
                    Write-UninstallLog "[DRY RUN] Would remove scheduled task: $($task.TaskName)" "INFO"
                } else {
                    try {
                        Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction Stop
                        Write-UninstallLog "Removed scheduled task: $($task.TaskName)" "SUCCESS"
                    } catch {
                        Write-UninstallLog "Failed to remove scheduled task $($task.TaskName): $($_.Exception.Message)" "ERROR"
                    }
                }
            }
            
            if (-not $DryRun) {
                Write-UninstallLog "Removed $taskCount scheduled tasks" "SUCCESS"
            }
        } else {
            Write-UninstallLog "No RDP Defender scheduled tasks found" "INFO"
        }
    } catch {
        Write-UninstallLog "Error checking scheduled tasks: $($_.Exception.Message)" "ERROR"
    }
}

# Function to remove installation directory and files
function Remove-InstallationDirectory {
    Write-UninstallLog "Checking installation directory: $InstallPath" "INFO"
    
    if (Test-Path $InstallPath) {
        Write-UninstallLog "Found installation directory: $InstallPath" "INFO"
        
        # Get directory size for reporting
        try {
            $dirSize = (Get-ChildItem $InstallPath -Recurse -File | Measure-Object -Property Length -Sum).Sum
            $dirSizeMB = [math]::Round($dirSize / 1MB, 2)
            Write-UninstallLog "Directory size: $dirSizeMB MB" "INFO"
        } catch {
            Write-UninstallLog "Could not calculate directory size" "WARNING"
        }
        
        # Handle logs directory
        $logsPath = Join-Path $InstallPath "Logs"
        if ((Test-Path $logsPath) -and $KeepLogs) {
            Write-UninstallLog "Preserving logs directory as requested: $logsPath" "INFO"
            
            # Move logs to a backup location
            $backupLogsPath = "$env:TEMP\RDPDefender_Logs_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            if ($DryRun) {
                Write-UninstallLog "[DRY RUN] Would backup logs to: $backupLogsPath" "INFO"
            } else {
                try {
                    Move-Item $logsPath $backupLogsPath -ErrorAction Stop
                    Write-UninstallLog "Logs backed up to: $backupLogsPath" "SUCCESS"
                } catch {
                    Write-UninstallLog "Failed to backup logs: $($_.Exception.Message)" "ERROR"
                }
            }
        }
        
        # Handle reports directory
        $reportsPath = Join-Path $InstallPath "Reports"
        if ((Test-Path $reportsPath) -and $KeepReports) {
            Write-UninstallLog "Preserving reports directory as requested: $reportsPath" "INFO"
            
            # Move reports to a backup location
            $backupReportsPath = "$env:TEMP\RDPDefender_Reports_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            if ($DryRun) {
                Write-UninstallLog "[DRY RUN] Would backup reports to: $backupReportsPath" "INFO"
            } else {
                try {
                    Move-Item $reportsPath $backupReportsPath -ErrorAction Stop
                    Write-UninstallLog "Reports backed up to: $backupReportsPath" "SUCCESS"
                } catch {
                    Write-UninstallLog "Failed to backup reports: $($_.Exception.Message)" "ERROR"
                }
            }
        }
        
        # Remove the main directory
        if ($DryRun) {
            Write-UninstallLog "[DRY RUN] Would remove installation directory: $InstallPath" "INFO"
        } else {
            try {
                if ($Force) {
                    Remove-Item $InstallPath -Recurse -Force -ErrorAction Stop
                } else {
                    Remove-Item $InstallPath -Recurse -ErrorAction Stop
                }
                Write-UninstallLog "Removed installation directory: $InstallPath" "SUCCESS"
            } catch {
                Write-UninstallLog "Failed to remove installation directory: $($_.Exception.Message)" "ERROR"
                Write-UninstallLog "Try running with -Force parameter if directory is in use" "WARNING"
            }
        }
    } else {
        Write-UninstallLog "Installation directory not found: $InstallPath" "INFO"
    }
}

# Function to clean up temporary files and cache
function Remove-TemporaryFiles {
    Write-UninstallLog "Cleaning up temporary files..." "INFO"
    
    $tempPatterns = @(
        "$env:TEMP\RDPDefender_*",
        "$env:TEMP\*.rdpdefender",
        "$env:WINDIR\Temp\RDPDefender_*"
    )
    
    foreach ($pattern in $tempPatterns) {
        $files = Get-ChildItem $pattern -ErrorAction SilentlyContinue
        if ($files) {
            foreach ($file in $files) {
                if ($DryRun) {
                    Write-UninstallLog "[DRY RUN] Would remove temp file: $($file.FullName)" "INFO"
                } else {
                    try {
                        Remove-Item $file.FullName -Force -Recurse -ErrorAction Stop
                        Write-UninstallLog "Removed temp file: $($file.Name)" "SUCCESS"
                    } catch {
                        Write-UninstallLog "Failed to remove temp file $($file.Name): $($_.Exception.Message)" "WARNING"
                    }
                }
            }
        }
    }
}

# Function to remove desktop shortcuts
function Remove-DesktopShortcuts {
    Write-UninstallLog "Removing desktop shortcuts..." "INFO"
    
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $shortcuts = @(
        "RDP Defender - Show Stats.lnk",
        "RDP Defender - Generate Report.lnk", 
        "RDP Defender - Quick Status.lnk",
        "RDP Defender - Management Console.lnk"
    )
    
    $removedCount = 0
    foreach ($shortcut in $shortcuts) {
        $shortcutPath = Join-Path $desktopPath $shortcut
        if (Test-Path $shortcutPath) {
            if ($DryRun) {
                Write-UninstallLog "[DRY RUN] Would remove desktop shortcut: $shortcut" "INFO"
            } else {
                try {
                    Remove-Item $shortcutPath -Force -ErrorAction Stop
                    Write-UninstallLog "Removed desktop shortcut: $shortcut" "SUCCESS"
                    $removedCount++
                } catch {
                    Write-UninstallLog "Failed to remove shortcut $shortcut`: $($_.Exception.Message)" "WARNING"
                }
            }
        }
    }
    
    if ($removedCount -gt 0 -or $DryRun) {
        Write-UninstallLog "Desktop shortcuts removal completed ($removedCount removed)" "INFO"
    } else {
        Write-UninstallLog "No RDP Defender desktop shortcuts found" "INFO"
    }
}

# Function to display uninstall summary
function Show-UninstallSummary {
    Write-UninstallLog "=== RDP Defender Uninstall Summary ===" "INFO"
    
    # Check remaining components
    $remainingRules = Get-NetFirewallRule -DisplayName "RDPDefender_Block_*" -ErrorAction SilentlyContinue
    $remainingTasks = Get-ScheduledTask -TaskName "RDPDefender_Unblock_*" -ErrorAction SilentlyContinue
    $remainingDir = Test-Path $InstallPath
    
    Write-UninstallLog "Remaining firewall rules: $(($remainingRules | Measure-Object).Count)" "INFO"
    Write-UninstallLog "Remaining scheduled tasks: $(($remainingTasks | Measure-Object).Count)" "INFO"
    Write-UninstallLog "Installation directory exists: $remainingDir" "INFO"
    
    if ($KeepLogs -or $KeepReports) {
        Write-UninstallLog "Backup files location: $env:TEMP\RDPDefender_*_Backup_*" "INFO"
    }
    
    $tempLogPath = "$env:TEMP\RDPDefender_Uninstall.log"
    if (Test-Path $tempLogPath) {
        Write-UninstallLog "Uninstall log saved to: $tempLogPath" "INFO"
    }
    
    # Overall status
    if (($remainingRules | Measure-Object).Count -eq 0 -and 
        ($remainingTasks | Measure-Object).Count -eq 0 -and 
        (-not $remainingDir -or $DryRun)) {
        Write-UninstallLog "RDP Defender uninstallation completed successfully!" "SUCCESS"
    } else {
        Write-UninstallLog "Uninstallation completed with some remaining components" "WARNING"
        Write-UninstallLog "You may need to manually remove remaining items or run with -Force parameter" "WARNING"
    }
}

# Main uninstall process
function Start-Uninstall {
    Write-UninstallLog "Starting RDP Defender uninstallation..." "INFO"
    Write-UninstallLog "Installation Path: $InstallPath" "INFO"
    Write-UninstallLog "Keep Logs: $KeepLogs" "INFO"
    Write-UninstallLog "Keep Reports: $KeepReports" "INFO"
    Write-UninstallLog "Force Mode: $Force" "INFO"
    Write-UninstallLog "Dry Run Mode: $DryRun" "INFO"
    
    if ($DryRun) {
        Write-UninstallLog "=== DRY RUN MODE - NO CHANGES WILL BE MADE ===" "WARNING"
    }
    
    # Confirm with user unless in force mode
    if (-not $Force -and -not $DryRun) {
        Write-Host "`nThis will completely remove RDP Defender and all its components." -ForegroundColor Yellow
        Write-Host "This includes:" -ForegroundColor Yellow
        Write-Host "- All firewall rules blocking IPs" -ForegroundColor Yellow
        Write-Host "- All scheduled tasks for unblocking" -ForegroundColor Yellow
        Write-Host "- Installation directory: $InstallPath" -ForegroundColor Yellow
        Write-Host "- Desktop shortcuts" -ForegroundColor Yellow
        
        if (-not $KeepLogs) {
            Write-Host "- All log files" -ForegroundColor Yellow
        }
        if (-not $KeepReports) {
            Write-Host "- All report files" -ForegroundColor Yellow
        }
        
        $confirmation = Read-Host "`nDo you want to continue? (y/N)"
        if ($confirmation -notin @('y', 'Y', 'yes', 'Yes', 'YES')) {
            Write-UninstallLog "Uninstallation cancelled by user" "INFO"
            return
        }
    }
    
    Write-UninstallLog "Proceeding with uninstallation..." "INFO"
    
    # Remove components in reverse order of installation
    Remove-DesktopShortcuts
    Remove-RDPDefenderScheduledTasks
    Remove-RDPDefenderFirewallRules
    Remove-InstallationDirectory
    Remove-TemporaryFiles
    
    Show-UninstallSummary
}

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Main execution
Write-Host "RDP Defender Uninstaller" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan

if (-not (Test-Administrator)) {
    Write-UninstallLog "This script requires administrator privileges" "ERROR"
    Write-UninstallLog "Please run PowerShell as Administrator and try again" "ERROR"
    exit 1
}

try {
    Start-Uninstall
} catch {
    Write-UninstallLog "Uninstallation failed with error: $($_.Exception.Message)" "ERROR"
    Write-UninstallLog "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}

Write-UninstallLog "Uninstall script completed" "INFO"