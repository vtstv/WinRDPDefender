# RDP Defender Installation and Configuration Script
#
# Copyright (c) 2025 Murr
# Repository: https://github.com/vtstv/WinRDPDefender
# Licensed under MIT License

param(
    [string]$InstallPath = "C:\WinRDPDefender",
    [int]$MaxFailedAttempts = 5,
    [int]$TimeWindowMinutes = 30,
    [int]$BlockDurationHours = 24,
    [switch]$CreateScheduledTasks,
    [switch]$NoDesktopShortcuts,
    [switch]$Force
)

# Function to write installation log
function Write-InstallLog {
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
    
    # Also write to installation log
    if (Test-Path "$InstallPath\Logs") {
        Add-Content -Path "$InstallPath\Logs\Installation.log" -Value $logEntry -ErrorAction SilentlyContinue
    }
}

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Create required directory structure
function New-RequiredDirectories {
    Write-InstallLog "Creating directory structure..." "INFO"
    
    $directories = @(
        $InstallPath,
        "$InstallPath\Logs",
        "$InstallPath\Reports"
    )
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            try {
                New-Item -Path $dir -ItemType Directory -Force | Out-Null
                Write-InstallLog "Created directory: $dir" "SUCCESS"
            } catch {
                Write-InstallLog "Failed to create directory $dir`: $($_.Exception.Message)" "ERROR"
                return $false
            }
        } else {
            Write-InstallLog "Directory already exists: $dir" "INFO"
        }
    }
    return $true
}

# Copy script files to installation directory
function Copy-ScriptFiles {
    Write-InstallLog "Copying script files..." "INFO"
    
    $currentLocation = $PSScriptRoot
    if (-not $currentLocation) {
        $currentLocation = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    
    $scriptFiles = @(
        "RDPDefender.ps1",
        "RDPMonitor.ps1", 
        "CleanupTasks.ps1",
        "Change-RDPPort.ps1",
        "Uninstall-RDPDefender.ps1",
        "Quick-Uninstall.ps1",
        "README.md",
        "EXAMPLES.md",
        "LICENSE"
    )
    
    $copiedCount = 0
    foreach ($file in $scriptFiles) {
        $sourcePath = Join-Path $currentLocation $file
        $destPath = Join-Path $InstallPath $file
        
        if (Test-Path $sourcePath) {
            try {
                Copy-Item -Path $sourcePath -Destination $destPath -Force
                Write-InstallLog "Copied: $file" "SUCCESS"
                $copiedCount++
            } catch {
                Write-InstallLog "Failed to copy $file`: $($_.Exception.Message)" "ERROR"
            }
        } else {
            Write-InstallLog "Source file not found: $file" "WARNING"
        }
    }
    
    Write-InstallLog "Copied $copiedCount script files" "INFO"
    return $copiedCount -gt 0
}

# Create configuration file
function New-ConfigurationFile {
    Write-InstallLog "Creating configuration file..." "INFO"
    
    $config = @{
        MaxFailedAttempts = $MaxFailedAttempts
        TimeWindowMinutes = $TimeWindowMinutes
        BlockDurationHours = $BlockDurationHours
        LogPath = "$InstallPath\Logs"
        ReportPath = "$InstallPath\Reports"
        InstallDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Version = "1.0"
    }
    
    $configPath = Join-Path $InstallPath "config.json"
    try {
        $config | ConvertTo-Json -Depth 2 | Out-File -FilePath $configPath -Encoding UTF8
        Write-InstallLog "Configuration file created: $configPath" "SUCCESS"
        return $true
    } catch {
        Write-InstallLog "Failed to create configuration file: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Update script paths in copied files
function Update-ScriptPaths {
    Write-InstallLog "Updating script paths..." "INFO"
    
    $scriptFiles = @("RDPDefender.ps1", "RDPMonitor.ps1", "CleanupTasks.ps1")
    
    foreach ($scriptFile in $scriptFiles) {
        $scriptPath = Join-Path $InstallPath $scriptFile
        if (Test-Path $scriptPath) {
            try {
                $content = Get-Content $scriptPath -Raw
                
                # Update default paths to match installation directory
                $content = $content -replace [regex]::Escape('C:\WinRDPDefender\Logs'), "$InstallPath\Logs"
                $content = $content -replace [regex]::Escape('C:\WinRDPDefender\Reports'), "$InstallPath\Reports" 
                $content = $content -replace [regex]::Escape('"C:\WinRDPDefender\Logs"'), "`"$InstallPath\Logs`""
                $content = $content -replace [regex]::Escape('"C:\WinRDPDefender\Reports"'), "`"$InstallPath\Reports`""
                
                $content | Out-File -FilePath $scriptPath -Encoding UTF8
                Write-InstallLog "Updated paths in: $scriptFile" "SUCCESS"
            } catch {
                Write-InstallLog "Failed to update paths in $scriptFile`: $($_.Exception.Message)" "WARNING"
            }
        }
    }
}

# Create scheduled tasks
function New-ScheduledTasks {
    if (-not $CreateScheduledTasks) {
        Write-InstallLog "Scheduled task creation skipped (use -CreateScheduledTasks to enable)" "INFO"
        return $true
    }
    
    Write-InstallLog "Creating scheduled tasks..." "INFO"
    
    try {
        # Main monitoring task
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$InstallPath\RDPDefender.ps1`""
        $trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 365) -Once -At (Get-Date)
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        
        Register-ScheduledTask -TaskName "RDPDefender_Monitor" -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "RDP Defender - Main Protection Monitoring" -Force | Out-Null
        Write-InstallLog "Created scheduled task: RDPDefender_Monitor" "SUCCESS"
        
        # Cleanup task (daily)
        $cleanupAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$InstallPath\CleanupTasks.ps1`""
        $cleanupTrigger = New-ScheduledTaskTrigger -Daily -At "02:00"
        
        Register-ScheduledTask -TaskName "RDPDefender_Cleanup" -Action $cleanupAction -Trigger $cleanupTrigger -Settings $settings -Principal $principal -Description "RDP Defender - Daily Cleanup and Maintenance" -Force | Out-Null
        Write-InstallLog "Created scheduled task: RDPDefender_Cleanup" "SUCCESS"
        
        return $true
    } catch {
        Write-InstallLog "Failed to create scheduled tasks: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Create desktop shortcuts
function New-DesktopShortcuts {
    Write-InstallLog "Creating desktop shortcuts..." "INFO"
    
    try {
        $shell = New-Object -ComObject WScript.Shell
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        
        # Create RDP Defender folder on desktop
        $rdpDefenderFolderPath = Join-Path $desktopPath "RDP Defender"
        if (-not (Test-Path $rdpDefenderFolderPath)) {
            New-Item -ItemType Directory -Path $rdpDefenderFolderPath -Force | Out-Null
            Write-InstallLog "Created desktop folder: RDP Defender" "SUCCESS"
        }
        
        # RDP Defender - Show Stats shortcut
        $statsShortcutPath = Join-Path $rdpDefenderFolderPath "Show Stats.lnk"
        $statsShortcut = $shell.CreateShortcut($statsShortcutPath)
        $statsShortcut.TargetPath = "PowerShell.exe"
        $statsShortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& '$InstallPath\RDPMonitor.ps1' -ShowStats; Read-Host 'Press Enter to close'`""
        $statsShortcut.WorkingDirectory = $InstallPath
        $statsShortcut.Description = "View RDP attack statistics and current security status"
        $statsShortcut.IconLocation = "PowerShell.exe,0"
        $statsShortcut.WindowStyle = 1
        $statsShortcut.Save()
        Write-InstallLog "Created desktop shortcut: Show Stats" "SUCCESS"
        
        # Generate Report shortcut
        $reportShortcutPath = Join-Path $rdpDefenderFolderPath "Generate Report.lnk"
        $reportShortcut = $shell.CreateShortcut($reportShortcutPath)
        $reportShortcut.TargetPath = "PowerShell.exe"
        $reportShortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& '$InstallPath\RDPMonitor.ps1' -GenerateReport -DaysBack 7; Read-Host 'Press Enter to close'`""
        $reportShortcut.WorkingDirectory = $InstallPath
        $reportShortcut.Description = "Generate comprehensive HTML security report (last 7 days)"
        $reportShortcut.IconLocation = "PowerShell.exe,0"
        $reportShortcut.WindowStyle = 1
        $reportShortcut.Save()
        Write-InstallLog "Created desktop shortcut: Generate Report" "SUCCESS"
        
        # Quick Status shortcut
        $quickShortcutPath = Join-Path $rdpDefenderFolderPath "Quick Status.lnk"
        $quickShortcut = $shell.CreateShortcut($quickShortcutPath)
        $quickShortcut.TargetPath = "PowerShell.exe"
        $quickShortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& '$InstallPath\RDPMonitor.ps1' -ShowStats -DaysBack 1; Write-Host ''; Write-Host 'Active Firewall Rules:' -ForegroundColor Yellow; Get-NetFirewallRule -DisplayName 'RDPDefender_Block_*' | Measure-Object | ForEach-Object { Write-Host `$_.Count -ForegroundColor Green }; Read-Host 'Press Enter to close'`""
        $quickShortcut.WorkingDirectory = $InstallPath
        $quickShortcut.Description = "Quick status check - recent attacks and active blocks"
        $quickShortcut.IconLocation = "PowerShell.exe,0"
        $quickShortcut.WindowStyle = 1
        $quickShortcut.Save()
        Write-InstallLog "Created desktop shortcut: Quick Status" "SUCCESS"
        
        # Management Console shortcut
        $consoleShortcutPath = Join-Path $rdpDefenderFolderPath "Management Console.lnk"
        $consoleShortcut = $shell.CreateShortcut($consoleShortcutPath)
        $consoleShortcut.TargetPath = "PowerShell.exe"
        $consoleShortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -NoExit -Command `"" + `
            "Set-Location '$InstallPath'; " + `
            "Write-Host 'RDP Defender Management Console' -ForegroundColor Cyan; " + `
            "Write-Host '=================================' -ForegroundColor Cyan; " + `
            "Write-Host ''; Write-Host 'Available Commands:' -ForegroundColor Yellow; " + `
            "Write-Host '  .\RDPDefender.ps1 -TestMode     - Test protection system'; " + `
            "Write-Host '  .\RDPMonitor.ps1 -ShowStats     - View statistics'; " + `
            "Write-Host '  .\RDPMonitor.ps1 -GenerateReport - Generate HTML report'; " + `
            "Write-Host '  .\CleanupTasks.ps1 -DryRun      - Preview cleanup actions'; " + `
            "Write-Host '  .\Change-RDPPort.ps1            - Interactive RDP port configuration'; " + `
            "Write-Host '  Get-NetFirewallRule -DisplayName RDPDefender_Block_* - List blocked IPs'; " + `
            "Write-Host ''; Write-Host 'Current Location: $InstallPath' -ForegroundColor Green`""
        $consoleShortcut.WorkingDirectory = $InstallPath
        $consoleShortcut.Description = "Open PowerShell console in RDP Defender directory with command help"
        $consoleShortcut.IconLocation = "PowerShell.exe,0"
        $consoleShortcut.WindowStyle = 1
        $consoleShortcut.Save()
        Write-InstallLog "Created desktop shortcut: Management Console" "SUCCESS"
        
        # Change RDP Port shortcut
        $portShortcutPath = Join-Path $rdpDefenderFolderPath "Change RDP Port.lnk"
        $portShortcut = $shell.CreateShortcut($portShortcutPath)
        $portShortcut.TargetPath = "PowerShell.exe"
        $portShortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$InstallPath\Change-RDPPort.ps1`""
        $portShortcut.WorkingDirectory = $InstallPath
        $portShortcut.Description = "Change RDP port and update firewall rules securely"
        $portShortcut.IconLocation = "netcfg.dll,0"
        $portShortcut.WindowStyle = 1
        $portShortcut.Save()
        Write-InstallLog "Created desktop shortcut: Change RDP Port" "SUCCESS"
        
        # Release COM object
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null
        
        Write-InstallLog "Created 5 desktop shortcuts" "SUCCESS"
        return $true
    } catch {
        Write-InstallLog "Failed to create desktop shortcuts: $($_.Exception.Message)" "WARNING"
        return $false
    }
}

# Verify installation
function Test-Installation {
    Write-InstallLog "Verifying installation..." "INFO"
    
    $requiredFiles = @(
        "RDPDefender.ps1",
        "RDPMonitor.ps1", 
        "CleanupTasks.ps1",
        "config.json"
    )
    
    $missingFiles = @()
    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $InstallPath $file
        if (-not (Test-Path $filePath)) {
            $missingFiles += $file
        }
    }
    
    if ($missingFiles.Count -eq 0) {
        Write-InstallLog "Installation verification successful" "SUCCESS"
        return $true
    } else {
        Write-InstallLog "Missing files: $($missingFiles -join ', ')" "ERROR"
        return $false
    }
}

# Main installation process
function Start-Installation {
    Write-Host "RDP Defender Installation Script" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host "Installation Path: $InstallPath" -ForegroundColor Green
    Write-Host "Max Failed Attempts: $MaxFailedAttempts" -ForegroundColor Gray
    Write-Host "Time Window: $TimeWindowMinutes minutes" -ForegroundColor Gray
    Write-Host "Block Duration: $BlockDurationHours hours" -ForegroundColor Gray
    Write-Host "Create Scheduled Tasks: $(if($CreateScheduledTasks){'Yes'}else{'No'})" -ForegroundColor Gray
    
    # Check for existing installation
    if ((Test-Path $InstallPath) -and -not $Force) {
        Write-Host "`nInstallation directory already exists: $InstallPath" -ForegroundColor Yellow
        $response = Read-Host "Do you want to continue and overwrite existing files? (y/N)"
        if ($response -notin @('y', 'Y', 'yes', 'Yes', 'YES')) {
            Write-InstallLog "Installation cancelled by user" "INFO"
            return $false
        }
    }
    
    Write-InstallLog "Starting RDP Defender installation..." "INFO"
    
    # Execute installation steps
    if (-not (New-RequiredDirectories)) { return $false }
    if (-not (Copy-ScriptFiles)) { return $false }
    if (-not (New-ConfigurationFile)) { return $false }
    
    Update-ScriptPaths
    
    if ($CreateScheduledTasks) {
        New-ScheduledTasks | Out-Null
    }
    
    # Create desktop shortcuts (unless disabled)
    if (-not $NoDesktopShortcuts) {
        New-DesktopShortcuts | Out-Null
    }
    
    if (Test-Installation) {
        Write-InstallLog "RDP Defender installation completed successfully!" "SUCCESS"
        Write-Host "`n✅ Installation Summary:" -ForegroundColor Green
        Write-Host "   📁 Installation Directory: $InstallPath" -ForegroundColor White
        Write-Host "   📝 Logs Directory: $InstallPath\Logs" -ForegroundColor White
        Write-Host "   📊 Reports Directory: $InstallPath\Reports" -ForegroundColor White
        Write-Host "   ⚙️  Configuration File: $InstallPath\config.json" -ForegroundColor White
        
        if ($CreateScheduledTasks) {
            Write-Host "   ⏰ Scheduled Tasks: Created" -ForegroundColor White
        }
        
        if (-not $NoDesktopShortcuts) {
            Write-Host "   🖥️  Desktop Shortcuts: Created (4 shortcuts)" -ForegroundColor White
        } else {
            Write-Host "   🖥️  Desktop Shortcuts: Skipped" -ForegroundColor Gray
        }
        
        Write-Host "`n🚀 Next Steps:" -ForegroundColor Cyan
        if (-not $NoDesktopShortcuts) {
            Write-Host "   1. Use desktop shortcuts for quick access to statistics and reports" -ForegroundColor Yellow
            Write-Host "   2. Test the system: cd `"$InstallPath`" && .\RDPDefender.ps1 -TestMode" -ForegroundColor Yellow
            Write-Host "   3. Management Console: Use 'RDP Defender - Management Console' shortcut" -ForegroundColor Yellow
        } else {
            Write-Host "   1. Test the system: cd `"$InstallPath`" && .\RDPDefender.ps1 -TestMode" -ForegroundColor Yellow
            Write-Host "   2. View statistics: .\RDPMonitor.ps1 -ShowStats" -ForegroundColor Yellow
            Write-Host "   3. Generate report: .\RDPMonitor.ps1 -GenerateReport" -ForegroundColor Yellow
        }
        
        return $true
    } else {
        Write-InstallLog "Installation verification failed" "ERROR"
        return $false
    }
}

# Main execution
if (-not (Test-Administrator)) {
    Write-Host "ERROR: This script requires administrator privileges!" -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

try {
    $success = Start-Installation
    if ($success) {
        Write-Host "`n🎉 RDP Defender has been successfully installed!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "`n❌ Installation failed. Check the logs for details." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Installation failed with error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}
