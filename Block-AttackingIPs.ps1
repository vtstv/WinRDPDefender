# Emergency IP Blocking Script for RDP Defender
# Blocks known attacking IP addresses immediately
#
# Copyright (c) 2025 Murr
# Repository: https://github.com/vtstv/WinRDPDefender
# Licensed under MIT License

param(
    [switch]$Force = $false,
    [int]$BlockDurationHours = 168  # 7 days default
)

# Ensure script runs with administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator!"
    exit 1
}

# Known attacking IPs 
$attackingIPs = @(
    "95.214.55.72",     # 8 attempts - Poland/Warsaw/MEVSPACE
    "59.94.28.178"      # 2 attempts - India/Wayanad/BSNL
)

# Also block entire MEVSPACE subnet ranges (known malicious hosting)
$attackingSubnets = @(
    "95.214.55.0/24",   # MEVSPACE range 1
    "95.214.53.0/24",   # MEVSPACE range 2
)

Write-Host "`n=== Emergency IP Blocking Script ===" -ForegroundColor Red
Write-Host "This will block the following attacking IPs:" -ForegroundColor Yellow
Write-Host "`nIndividual IPs: $($attackingIPs.Count)" -ForegroundColor White
foreach ($ip in $attackingIPs) {
    Write-Host "  - $ip" -ForegroundColor Cyan
}

Write-Host "`nSubnet Ranges: $($attackingSubnets.Count)" -ForegroundColor White
foreach ($subnet in $attackingSubnets) {
    Write-Host "  - $subnet" -ForegroundColor Cyan
}

Write-Host "`nBlock Duration: $BlockDurationHours hours ($([math]::Round($BlockDurationHours/24, 1)) days)" -ForegroundColor White

if (-not $Force) {
    $confirm = Read-Host "`nDo you want to proceed with blocking these IPs? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "`nBlocking attacking IPs..." -ForegroundColor Yellow
$blockedCount = 0
$alreadyBlockedCount = 0
$failedCount = 0

# Block individual IPs
foreach ($ip in $attackingIPs) {
    $ruleName = "RDPDefender_Block_$($ip -replace '\.', '_')"
    
    # Check if already blocked
    $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    if ($existingRule) {
        Write-Host "  [SKIP] $ip - already blocked" -ForegroundColor Yellow
        $alreadyBlockedCount++
        continue
    }
    
    try {
        # Block the IP on all ports for maximum security
        New-NetFirewallRule -DisplayName $ruleName `
            -Direction Inbound `
            -RemoteAddress $ip `
            -Action Block `
            -Enabled True `
            -Profile Any `
            -Description "RDP Defender: Emergency block - attacking IP (blocked on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))" | Out-Null
        
        Write-Host "  [BLOCKED] $ip - all ports blocked" -ForegroundColor Green
        $blockedCount++
        
        # Schedule unblock
        $taskName = "RDPDefender_Unblock_$($ip -replace '\.', '_')"
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-Command `"Remove-NetFirewallRule -DisplayName '$ruleName' -ErrorAction SilentlyContinue`""
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddHours($BlockDurationHours)
        $settings = New-ScheduledTaskSettingsSet -DeleteExpiredTaskAfter 01:00:00
        
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -User "SYSTEM" -Force | Out-Null
        
    } catch {
        Write-Host "  [FAILED] $ip - Error: $($_.Exception.Message)" -ForegroundColor Red
        $failedCount++
    }
}

# Block subnet ranges
Write-Host "`nBlocking subnet ranges..." -ForegroundColor Yellow
foreach ($subnet in $attackingSubnets) {
    $ruleName = "RDPDefender_Block_Subnet_$($subnet -replace '[\.\/]', '_')"
    
    # Check if already blocked
    $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    if ($existingRule) {
        Write-Host "  [SKIP] $subnet - already blocked" -ForegroundColor Yellow
        $alreadyBlockedCount++
        continue
    }
    
    try {
        # Block the entire subnet
        New-NetFirewallRule -DisplayName $ruleName `
            -Direction Inbound `
            -RemoteAddress $subnet `
            -Action Block `
            -Enabled True `
            -Profile Any `
            -Description "RDP Defender: Emergency block - attacking subnet range (blocked on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))" | Out-Null
        
        Write-Host "  [BLOCKED] $subnet - entire subnet blocked" -ForegroundColor Green
        $blockedCount++
        
        # Schedule unblock for subnet
        $taskName = "RDPDefender_Unblock_Subnet_$($subnet -replace '[\.\/]', '_')"
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-Command `"Remove-NetFirewallRule -DisplayName '$ruleName' -ErrorAction SilentlyContinue`""
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddHours($BlockDurationHours)
        $settings = New-ScheduledTaskSettingsSet -DeleteExpiredTaskAfter 01:00:00
        
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -User "SYSTEM" -Force | Out-Null
        
    } catch {
        Write-Host "  [FAILED] $subnet - Error: $($_.Exception.Message)" -ForegroundColor Red
        $failedCount++
    }
}

# Summary
Write-Host "`n=== Blocking Summary ===" -ForegroundColor Cyan
Write-Host "Successfully blocked: $blockedCount" -ForegroundColor Green
Write-Host "Already blocked: $alreadyBlockedCount" -ForegroundColor Yellow
Write-Host "Failed to block: $failedCount" -ForegroundColor Red
Write-Host "`nAll blocked IPs will be automatically unblocked in $BlockDurationHours hours" -ForegroundColor White

# Log to RDP Defender log
$logPath = "C:\WinRDPDefender\Logs"
if (Test-Path $logPath) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [CRITICAL] Emergency blocking executed: $blockedCount IPs blocked, $alreadyBlockedCount already blocked, $failedCount failed"
    Add-Content -Path "$logPath\RDPDefender.log" -Value $logEntry
}

Write-Host "`nTo view currently blocked IPs, run:" -ForegroundColor Yellow
Write-Host "  Get-NetFirewallRule -DisplayName 'RDPDefender_Block_*' | Format-Table DisplayName, Enabled" -ForegroundColor Cyan

Write-Host "`nTo manually unblock a specific IP, run:" -ForegroundColor Yellow
Write-Host "  Remove-NetFirewallRule -DisplayName 'RDPDefender_Block_95_214_55_72'" -ForegroundColor Cyan

Write-Host "`n"
