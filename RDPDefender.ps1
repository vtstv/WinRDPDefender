# RDP Brute Force Protection Script
# This script monitors Windows Event Log for failed RDP attempts and blocks malicious IPs
#
# Copyright (c) 2025 Murr
# Repository: https://github.com/vtstv/WinRDPDefender
# Licensed under MIT License

param(
    [int]$MaxFailedAttempts = 5,
    [int]$TimeWindowMinutes = 30,
    [int]$BlockDurationHours = 24,
    [string]$LogPath = "C:\WinRDPDefender\Logs",
    [switch]$TestMode = $false
)

# Ensure script runs with administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator!"
    exit 1
}

# Create log directory if it doesn't exist
if (!(Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

# Function to write log entries
function Write-RDPLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path "$LogPath\RDPDefender.log" -Value $logEntry
}

# Function to get current RDP port
function Get-CurrentRDPPort {
    try {
        $rdpPort = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "PortNumber" -ErrorAction Stop
        return $rdpPort.PortNumber
    } catch {
        Write-RDPLog "Could not determine RDP port, using default 3389" "WARNING"
        return 3389
    }
}

# Function to get failed RDP attempts from Event Log
function Get-FailedRDPAttempts {
    param([int]$Minutes)
    
    $startTime = (Get-Date).AddMinutes(-$Minutes)
    
    # Event ID 4625 = Failed logon attempt
    $events = Get-WinEvent -FilterHashtable @{
        LogName = 'Security'
        ID = 4625
        StartTime = $startTime
    } -ErrorAction SilentlyContinue
    
    $failedAttempts = @{}
    
    foreach ($logEvent in $events) {
        $xml = [xml]$logEvent.ToXml()
        $sourceIP = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'IpAddress' } | Select-Object -ExpandProperty '#text'
        $userName = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'TargetUserName' } | Select-Object -ExpandProperty '#text'
        $logonType = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'LogonType' } | Select-Object -ExpandProperty '#text'
        
        # Filter for RDP attempts (Logon Type 3 and 10)
        if ($logonType -eq "3" -or $logonType -eq "10") {
            if ($sourceIP -and $sourceIP -ne "-" -and $sourceIP -ne "127.0.0.1") {
                if ($failedAttempts.ContainsKey($sourceIP)) {
                    $failedAttempts[$sourceIP] += 1
                } else {
                    $failedAttempts[$sourceIP] = 1
                }
                
                Write-RDPLog "Failed RDP attempt from $sourceIP (User: $userName, Total: $($failedAttempts[$sourceIP]))" "WARNING"
            }
        }
    }
    
    return $failedAttempts
}

# Function to block IP using Windows Firewall
function Block-IPAddress {
    param([string]$IPAddress, [int]$Hours)
    
    $ruleName = "RDPDefender_Block_$($IPAddress -replace '\.', '_')"
    
    # Check if rule already exists
    $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    if ($existingRule) {
        Write-RDPLog "IP $IPAddress is already blocked" "INFO"
        return
    }
    
    # Get current RDP port
    $rdpPort = Get-CurrentRDPPort
    
    if (!$TestMode) {
        try {
            # Create firewall rule to block the IP on RDP port
            # Note: Blocking on all ports for maximum security
            New-NetFirewallRule -DisplayName $ruleName `
                -Direction Inbound `
                -RemoteAddress $IPAddress `
                -Action Block `
                -Enabled True `
                -Profile Any `
                -Description "RDP Defender: Blocked due to $MaxFailedAttempts failed login attempts on port $rdpPort" | Out-Null
            
            Write-RDPLog "Blocked IP address: $IPAddress (all ports) for $Hours hours - RDP port: $rdpPort" "CRITICAL"
            
            # Schedule removal of the block
            $taskName = "RDPDefender_Unblock_$($IPAddress -replace '\.', '_')"
            $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-Command `"Remove-NetFirewallRule -DisplayName '$ruleName' -ErrorAction SilentlyContinue`""
            $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddHours($Hours)
            $settings = New-ScheduledTaskSettingsSet -DeleteExpiredTaskAfter 01:00:00
            
            Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -User "SYSTEM" -Force | Out-Null
            Write-RDPLog "Scheduled unblock for IP $IPAddress in $Hours hours" "INFO"
            
        } catch {
            Write-RDPLog "Failed to block IP $IPAddress`: $($_.Exception.Message)" "ERROR"
        }
    } else {
        Write-RDPLog "[TEST MODE] Would block IP address: $IPAddress for $Hours hours" "INFO"
    }
}

# Main execution
Write-RDPLog "=== RDP Defender Started ===" "INFO"
Write-RDPLog "Configuration: MaxAttempts=$MaxFailedAttempts, TimeWindow=${TimeWindowMinutes}min, BlockDuration=${BlockDurationHours}h" "INFO"

if ($TestMode) {
    Write-RDPLog "Running in TEST MODE - no actual blocking will occur" "WARNING"
}

# Get failed attempts in the specified time window
$failedAttempts = Get-FailedRDPAttempts -Minutes $TimeWindowMinutes

if ($failedAttempts.Count -eq 0) {
    Write-RDPLog "No failed RDP attempts found in the last $TimeWindowMinutes minutes" "INFO"
} else {
    Write-RDPLog "Found $($failedAttempts.Count) unique IP addresses with failed attempts" "INFO"
    
    foreach ($ip in $failedAttempts.Keys) {
        $attempts = $failedAttempts[$ip]
        
        if ($attempts -ge $MaxFailedAttempts) {
            Write-RDPLog "IP $ip exceeded threshold with $attempts failed attempts" "CRITICAL"
            Block-IPAddress -IPAddress $ip -Hours $BlockDurationHours
        } else {
            Write-RDPLog "IP $ip has $attempts failed attempts (below threshold of $MaxFailedAttempts)" "INFO"
        }
    }
}

Write-RDPLog "=== RDP Defender Completed ===" "INFO"