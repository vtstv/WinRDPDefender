# RDP Defender Management Console
# Interactive menu for managing RDP Defender
#
# Copyright (c) 2025 Murr
# Repository: https://github.com/vtstv/WinRDPDefender
# Licensed under MIT License

param(
    [string]$InstallPath = "C:\WinRDPDefender"
)

# Set location to installation directory
Set-Location $InstallPath

function Show-Menu {
    Clear-Host
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "   RDP Defender Management Console" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1.  View Attack Statistics" -ForegroundColor White
    Write-Host "2.  Generate HTML Report" -ForegroundColor White
    Write-Host "3.  Export to CSV" -ForegroundColor White
    Write-Host "4.  List Blocked IPs" -ForegroundColor White
    Write-Host "5.  Test Protection System" -ForegroundColor White
    Write-Host "6.  Run Cleanup (Preview)" -ForegroundColor White
    Write-Host "7.  Run Cleanup (Execute)" -ForegroundColor White
    Write-Host "8.  Change RDP Port" -ForegroundColor White
    Write-Host "9.  Unblock Specific IP" -ForegroundColor White
    Write-Host "10. Unblock All IPs" -ForegroundColor White
    Write-Host "11. View Configuration" -ForegroundColor White
    Write-Host "12. View Recent Logs" -ForegroundColor White
    Write-Host "0.  Exit" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Statistics {
    Write-Host ""
    Write-Host "Loading attack statistics..." -ForegroundColor Yellow
    Write-Host ""
    
    $days = Read-Host "Enter number of days to analyze (default: 7)"
    if ([string]::IsNullOrWhiteSpace($days)) { $days = 7 }
    
    & "$InstallPath\RDPMonitor.ps1" -ShowStats -DaysBack $days
    
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Generate-Report {
    Write-Host ""
    Write-Host "Generating HTML report..." -ForegroundColor Yellow
    Write-Host ""
    
    $days = Read-Host "Enter number of days to include (default: 7)"
    if ([string]::IsNullOrWhiteSpace($days)) { $days = 7 }
    
    & "$InstallPath\RDPMonitor.ps1" -GenerateReport -DaysBack $days
    
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Export-CSV {
    Write-Host ""
    Write-Host "Exporting data to CSV..." -ForegroundColor Yellow
    Write-Host ""
    
    $days = Read-Host "Enter number of days to export (default: 30)"
    if ([string]::IsNullOrWhiteSpace($days)) { $days = 30 }
    
    & "$InstallPath\RDPMonitor.ps1" -ExportCSV -DaysBack $days
    
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Show-BlockedIPs {
    Write-Host ""
    Write-Host "Currently Blocked IP Addresses:" -ForegroundColor Yellow
    Write-Host ""
    
    $rules = Get-NetFirewallRule -DisplayName "RDPDefender_Block_*" -ErrorAction SilentlyContinue
    
    if ($rules) {
        $count = 0
        foreach ($rule in $rules) {
            $ip = $rule.DisplayName -replace "RDPDefender_Block_", "" -replace "_", "."
            $status = if ($rule.Enabled) { "Active" } else { "Disabled" }
            $count++
            Write-Host "  [$count] $ip - $status" -ForegroundColor $(if ($rule.Enabled) { "Red" } else { "Gray" })
        }
        Write-Host ""
        Write-Host "Total blocked IPs: $count" -ForegroundColor Cyan
    } else {
        Write-Host "  No IPs are currently blocked." -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Test-Protection {
    Write-Host ""
    Write-Host "Testing RDP Defender protection system..." -ForegroundColor Yellow
    Write-Host ""
    
    & "$InstallPath\RDPDefender.ps1" -TestMode
    
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Run-CleanupPreview {
    Write-Host ""
    Write-Host "Preview cleanup actions (no changes will be made)..." -ForegroundColor Yellow
    Write-Host ""
    
    & "$InstallPath\CleanupTasks.ps1" -DryRun
    
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Run-CleanupExecute {
    Write-Host ""
    Write-Host "Execute cleanup tasks..." -ForegroundColor Yellow
    Write-Host ""
    
    $confirm = Read-Host "Are you sure you want to run cleanup? (y/N)"
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        & "$InstallPath\CleanupTasks.ps1"
    } else {
        Write-Host "Cleanup cancelled." -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Change-RDPPort {
    Write-Host ""
    & "$InstallPath\Change-RDPPort.ps1"
    
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Unblock-SpecificIP {
    Write-Host ""
    Write-Host "Unblock Specific IP Address" -ForegroundColor Yellow
    Write-Host ""
    
    $rules = Get-NetFirewallRule -DisplayName "RDPDefender_Block_*" -ErrorAction SilentlyContinue
    
    if (-not $rules) {
        Write-Host "No IPs are currently blocked." -ForegroundColor Green
        Write-Host ""
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    Write-Host "Currently blocked IPs:" -ForegroundColor Cyan
    $ipList = @()
    $count = 0
    foreach ($rule in $rules) {
        $ip = $rule.DisplayName -replace "RDPDefender_Block_", "" -replace "_", "."
        $count++
        $ipList += $ip
        Write-Host "  [$count] $ip" -ForegroundColor White
    }
    
    Write-Host ""
    $selection = Read-Host "Enter number to unblock (or 0 to cancel)"
    
    if ($selection -match '^\d+$' -and [int]$selection -gt 0 -and [int]$selection -le $ipList.Count) {
        $ipToUnblock = $ipList[[int]$selection - 1]
        $ruleName = "RDPDefender_Block_" + ($ipToUnblock -replace '\.', '_')
        
        try {
            Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction Stop
            Write-Host ""
            Write-Host "Successfully unblocked IP: $ipToUnblock" -ForegroundColor Green
            
            # Remove scheduled task if exists
            $taskName = "RDPDefender_Unblock_" + ($ipToUnblock -replace '\.', '_')
            $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            if ($task) {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
                Write-Host "Removed scheduled unblock task." -ForegroundColor Green
            }
        } catch {
            Write-Host ""
            Write-Host "Failed to unblock IP: $($_.Exception.Message)" -ForegroundColor Red
        }
    } elseif ($selection -ne "0") {
        Write-Host ""
        Write-Host "Invalid selection." -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Unblock-AllIPs {
    Write-Host ""
    Write-Host "Unblock All IP Addresses" -ForegroundColor Yellow
    Write-Host ""
    
    $rules = Get-NetFirewallRule -DisplayName "RDPDefender_Block_*" -ErrorAction SilentlyContinue
    
    if (-not $rules) {
        Write-Host "No IPs are currently blocked." -ForegroundColor Green
        Write-Host ""
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    $count = ($rules | Measure-Object).Count
    Write-Host "This will unblock $count IP addresses." -ForegroundColor Yellow
    Write-Host ""
    $confirm = Read-Host "Are you sure? (y/N)"
    
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        Write-Host ""
        Write-Host "Removing firewall rules..." -ForegroundColor Yellow
        
        $removed = 0
        foreach ($rule in $rules) {
            try {
                Remove-NetFirewallRule -Name $rule.Name -ErrorAction Stop
                $removed++
            } catch {
                Write-Host "Failed to remove rule: $($rule.DisplayName)" -ForegroundColor Red
            }
        }
        
        Write-Host "Removed $removed firewall rules." -ForegroundColor Green
        
        # Remove all scheduled unblock tasks
        Write-Host "Removing scheduled tasks..." -ForegroundColor Yellow
        $tasks = Get-ScheduledTask -TaskName "RDPDefender_Unblock_*" -ErrorAction SilentlyContinue
        if ($tasks) {
            foreach ($task in $tasks) {
                Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false
            }
            Write-Host "Removed scheduled tasks." -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "All IPs have been unblocked." -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Operation cancelled." -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Show-Configuration {
    Write-Host ""
    Write-Host "Current Configuration:" -ForegroundColor Yellow
    Write-Host ""
    
    $configPath = Join-Path $InstallPath "config.json"
    if (Test-Path $configPath) {
        $config = Get-Content $configPath | ConvertFrom-Json
        Write-Host "  Max Failed Attempts:  $($config.MaxFailedAttempts)" -ForegroundColor White
        Write-Host "  Time Window:          $($config.TimeWindowMinutes) minutes" -ForegroundColor White
        Write-Host "  Block Duration:       $($config.BlockDurationHours) hours" -ForegroundColor White
        Write-Host "  Log Path:             $($config.LogPath)" -ForegroundColor White
        Write-Host "  Report Path:          $($config.ReportPath)" -ForegroundColor White
        Write-Host "  Install Date:         $($config.InstallDate)" -ForegroundColor White
        Write-Host "  Version:              $($config.Version)" -ForegroundColor White
    } else {
        Write-Host "  Configuration file not found." -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Scheduled Tasks:" -ForegroundColor Yellow
    $tasks = Get-ScheduledTask -TaskName "RDPDefender_*" -ErrorAction SilentlyContinue
    if ($tasks) {
        foreach ($task in $tasks) {
            $status = $task.State
            Write-Host "  $($task.TaskName): $status" -ForegroundColor $(if ($status -eq "Ready") { "Green" } else { "Yellow" })
        }
    } else {
        Write-Host "  No scheduled tasks found." -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Show-RecentLogs {
    Write-Host ""
    Write-Host "Recent Log Entries:" -ForegroundColor Yellow
    Write-Host ""
    
    $logPath = Join-Path $InstallPath "Logs\RDPDefender.log"
    if (Test-Path $logPath) {
        $lines = Read-Host "How many lines to display? (default: 20)"
        if ([string]::IsNullOrWhiteSpace($lines)) { $lines = 20 }
        
        Write-Host ""
        Get-Content $logPath -Tail $lines | ForEach-Object {
            if ($_ -match '\[ERROR\]') {
                Write-Host $_ -ForegroundColor Red
            } elseif ($_ -match '\[WARNING\]') {
                Write-Host $_ -ForegroundColor Yellow
            } elseif ($_ -match '\[SUCCESS\]') {
                Write-Host $_ -ForegroundColor Green
            } else {
                Write-Host $_ -ForegroundColor White
            }
        }
    } else {
        Write-Host "  Log file not found." -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Main loop
while ($true) {
    Show-Menu
    $choice = Read-Host "Select an option"
    
    switch ($choice) {
        "1"  { Show-Statistics }
        "2"  { Generate-Report }
        "3"  { Export-CSV }
        "4"  { Show-BlockedIPs }
        "5"  { Test-Protection }
        "6"  { Run-CleanupPreview }
        "7"  { Run-CleanupExecute }
        "8"  { Change-RDPPort }
        "9"  { Unblock-SpecificIP }
        "10" { Unblock-AllIPs }
        "11" { Show-Configuration }
        "12" { Show-RecentLogs }
        "0"  { 
            Write-Host ""
            Write-Host "Exiting Management Console..." -ForegroundColor Yellow
            exit 
        }
        default {
            Write-Host ""
            Write-Host "Invalid option. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
}
