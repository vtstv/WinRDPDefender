# RDP Port Configuration Script
# This script safely changes the default RDP port and updates firewall rules
# 
# USAGE:
#   .\Change-RDPPort.ps1                    # Interactive mode - prompts for port selection
#   .\Change-RDPPort.ps1 -NewPort 5555      # Change to specific port with confirmation
#   .\Change-RDPPort.ps1 -NewPort 5555 -Force  # Change to specific port without prompts
#   .\Change-RDPPort.ps1 -CheckOnly         # Show current RDP configuration
#   .\Change-RDPPort.ps1 -RestoreDefault    # Restore to default port 3389
#
# Copyright (c) 2025 Murr
# Repository: https://github.com/vtstv/WinRDPDefender
# Licensed under MIT License

param(
    [int]$NewPort = 0,
    [switch]$Force = $false,
    [switch]$TestMode = $false,
    [switch]$RestoreDefault = $false,
    [switch]$CheckOnly = $false,
    [switch]$Help = $false,
    [string]$LogPath = "C:\WinRDPDefender\Logs"
)

# Show help if requested
if ($Help) {
    Write-Host "`nRDP Port Configuration Script" -ForegroundColor Cyan
    Write-Host "===========================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  Safely changes the RDP port and updates firewall rules with backup/restore capabilities."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  .\Change-RDPPort.ps1                    # Interactive mode - prompts for port selection"
    Write-Host "  .\Change-RDPPort.ps1 -NewPort 5555      # Change to specific port with confirmation"
    Write-Host "  .\Change-RDPPort.ps1 -NewPort 5555 -Force  # Change to specific port without prompts"
    Write-Host "  .\Change-RDPPort.ps1 -CheckOnly         # Show current RDP configuration"
    Write-Host "  .\Change-RDPPort.ps1 -RestoreDefault    # Restore to default port 3389"
    Write-Host "  .\Change-RDPPort.ps1 -Help              # Show this help message"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -NewPort <int>      Port number to change to (1024-65535)"
    Write-Host "  -Force              Skip confirmation prompts"
    Write-Host "  -CheckOnly          Show current configuration only"
    Write-Host "  -RestoreDefault     Restore to default port 3389"
    Write-Host "  -TestMode           Test mode - shows what would be done without making changes"
    Write-Host "  -Help               Show this help message"
    Write-Host "  -LogPath <string>   Custom log directory path"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  .\Change-RDPPort.ps1                    # Interactive menu"
    Write-Host "  .\Change-RDPPort.ps1 -CheckOnly         # Check current port"
    Write-Host "  .\Change-RDPPort.ps1 -NewPort 3390      # Change to 3390 with prompts"
    Write-Host "  .\Change-RDPPort.ps1 -RestoreDefault -Force # Restore to 3389 silently"
    Write-Host ""
    exit 0
}

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
function Write-RDPPortLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(
        switch ($Level) {
            "INFO" { "White" }
            "WARNING" { "Yellow" }
            "ERROR" { "Red" }
            "SUCCESS" { "Green" }
            "CRITICAL" { "Magenta" }
            default { "Gray" }
        }
    )
    Add-Content -Path "$LogPath\RDPPortConfig.log" -Value $logEntry
}

# Function to validate port number
function Test-ValidPort {
    param([int]$Port)
    
    if ($Port -lt 1024 -or $Port -gt 65535) {
        Write-RDPPortLog "Invalid port number $Port. Must be between 1024-65535" "ERROR"
        return $false
    }
    
    if ($Port -eq 3389) {
        Write-RDPPortLog "Port 3389 is the default RDP port (not recommended for security)" "WARNING"
    }
    
    # Check if port is in use by another service
    try {
        $portInUse = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
        if ($portInUse) {
            Write-RDPPortLog "Port $Port is already in use by another service" "ERROR"
            $portInUse | ForEach-Object {
                Write-RDPPortLog "  Process: $($_.OwningProcess), State: $($_.State)" "ERROR"
            }
            return $false
        }
    } catch {
        # If we can't check, proceed with warning
        Write-RDPPortLog "Could not verify if port $Port is in use: $($_.Exception.Message)" "WARNING"
    }
    
    return $true
}

# Function to get current RDP configuration
function Get-CurrentRDPConfig {
    try {
        # Get RDP port from registry
        $rdpPort = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "PortNumber" -ErrorAction Stop
        $currentPort = $rdpPort.PortNumber
        
        # Get RDP service status
        $rdpService = Get-Service -Name "TermService" -ErrorAction Stop
        
        # Get firewall rules for RDP
        $firewallRules = Get-NetFirewallRule -DisplayName "*Remote Desktop*" -ErrorAction SilentlyContinue
        
        # Get Windows Firewall status
        $firewallProfiles = Get-NetFirewallProfile | Select-Object Name, Enabled
        
        $config = [PSCustomObject]@{
            CurrentPort = $currentPort
            ServiceStatus = $rdpService.Status
            ServiceStartType = $rdpService.StartType
            FirewallRules = $firewallRules
            FirewallProfiles = $firewallProfiles
        }
        
        return $config
    } catch {
        Write-RDPPortLog "Failed to get current RDP configuration: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# Function to display current configuration
function Show-CurrentConfig {
    Write-RDPPortLog "=== Current RDP Configuration ===" "INFO"
    
    $config = Get-CurrentRDPConfig
    if (-not $config) {
        return
    }
    
    Write-RDPPortLog "RDP Port: $($config.CurrentPort)" "INFO"
    Write-RDPPortLog "RDP Service Status: $($config.ServiceStatus)" "INFO"
    Write-RDPPortLog "RDP Service Start Type: $($config.ServiceStartType)" "INFO"
    
    Write-RDPPortLog "`nWindows Firewall Profiles:" "INFO"
    foreach ($firewallProfile in $config.FirewallProfiles) {
        $status = if ($firewallProfile.Enabled) { "Enabled" } else { "Disabled" }
        Write-RDPPortLog "  $($firewallProfile.Name): $status" "INFO"
    }
    
    Write-RDPPortLog "`nActive RDP Firewall Rules:" "INFO"
    if ($config.FirewallRules) {
        foreach ($rule in $config.FirewallRules) {
            $status = if ($rule.Enabled) { "Enabled" } else { "Disabled" }
            Write-RDPPortLog "  $($rule.DisplayName): $status" "INFO"
        }
    } else {
        Write-RDPPortLog "  No RDP firewall rules found" "WARNING"
    }
    
    # Check for custom firewall rules
    $customRules = Get-NetFirewallRule -DisplayName "*RDP*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -notlike "*Remote Desktop*" }
    if ($customRules) {
        Write-RDPPortLog "`nCustom RDP-related Firewall Rules:" "INFO"
        foreach ($rule in $customRules) {
            $status = if ($rule.Enabled) { "Enabled" } else { "Disabled" }
            Write-RDPPortLog "  $($rule.DisplayName): $status" "INFO"
        }
    }
}

# Function to backup current configuration
function Backup-RDPConfig {
    try {
        $backupPath = Join-Path $LogPath "RDP_Config_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        
        $config = Get-CurrentRDPConfig
        if (-not $config) {
            return $false
        }
        
        # Add registry backup
        $registryBackup = @{
            PortNumber = $config.CurrentPort
            fDenyTSConnections = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections").fDenyTSConnections
            UserAuthentication = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "UserAuthentication").UserAuthentication
        }
        
        $backupData = @{
            BackupDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            CurrentPort = $config.CurrentPort
            ServiceStatus = $config.ServiceStatus.ToString()
            ServiceStartType = $config.ServiceStartType.ToString()
            RegistrySettings = $registryBackup
            FirewallRules = @()
        }
        
        # Backup firewall rules
        foreach ($rule in $config.FirewallRules) {
            $ruleInfo = Get-NetFirewallRule -Name $rule.Name | Get-NetFirewallPortFilter
            $backupData.FirewallRules += @{
                Name = $rule.Name
                DisplayName = $rule.DisplayName
                Enabled = $rule.Enabled
                Direction = $rule.Direction.ToString()
                Action = $rule.Action.ToString()
                LocalPort = $ruleInfo.LocalPort
                Protocol = $ruleInfo.Protocol
            }
        }
        
        $backupData | ConvertTo-Json -Depth 3 | Out-File -FilePath $backupPath -Encoding UTF8
        Write-RDPPortLog "Configuration backed up to: $backupPath" "SUCCESS"
        return $backupPath
    } catch {
        Write-RDPPortLog "Failed to backup configuration: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Function to change RDP port in registry
function Set-RDPPort {
    param([int]$Port)
    
    try {
        if ($TestMode) {
            Write-RDPPortLog "[TEST MODE] Would change RDP port to $Port" "INFO"
            return $true
        }
        
        # Change the port in registry
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "PortNumber" -Value $Port -ErrorAction Stop
        Write-RDPPortLog "Changed RDP port in registry to $Port" "SUCCESS"
        
        return $true
    } catch {
        Write-RDPPortLog "Failed to change RDP port in registry: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Function to update firewall rules
function Update-FirewallRules {
    param([int]$NewPort, [int]$OldPort)
    
    try {
        Write-RDPPortLog "Updating firewall rules for port $NewPort..." "INFO"
        
        if ($TestMode) {
            Write-RDPPortLog "[TEST MODE] Would update firewall rules from port $OldPort to $NewPort" "INFO"
            return $true
        }
        
        # Disable existing RDP firewall rules
        $existingRules = Get-NetFirewallRule -DisplayName "*Remote Desktop*" -ErrorAction SilentlyContinue
        foreach ($rule in $existingRules) {
            if ($rule.Enabled) {
                Set-NetFirewallRule -Name $rule.Name -Enabled False
                Write-RDPPortLog "Disabled existing firewall rule: $($rule.DisplayName)" "INFO"
            }
        }
        
        # Create new firewall rules for the custom port
        $ruleName = "RDP_Custom_Port_$NewPort"
        
        # Inbound rule
        if (-not (Get-NetFirewallRule -DisplayName "$ruleName (Inbound)" -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName "$ruleName (Inbound)" -Direction Inbound -Protocol TCP -LocalPort $NewPort -Action Allow -Profile Domain,Private,Public -Description "Custom RDP port $NewPort (Inbound)" | Out-Null
            Write-RDPPortLog "Created inbound firewall rule for port $NewPort" "SUCCESS"
        } else {
            Write-RDPPortLog "Inbound firewall rule for port $NewPort already exists" "INFO"
        }
        
        # Outbound rule (optional, for strict environments)
        if (-not (Get-NetFirewallRule -DisplayName "$ruleName (Outbound)" -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName "$ruleName (Outbound)" -Direction Outbound -Protocol TCP -LocalPort $NewPort -Action Allow -Profile Domain,Private,Public -Description "Custom RDP port $NewPort (Outbound)" | Out-Null
            Write-RDPPortLog "Created outbound firewall rule for port $NewPort" "SUCCESS"
        } else {
            Write-RDPPortLog "Outbound firewall rule for port $NewPort already exists" "INFO"
        }
        
        return $true
    } catch {
        Write-RDPPortLog "Failed to update firewall rules: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Function to restart RDP service
function Restart-RDPService {
    try {
        if ($TestMode) {
            Write-RDPPortLog "[TEST MODE] Would restart Terminal Services (TermService)" "INFO"
            return $true
        }
        
        Write-RDPPortLog "Restarting Terminal Services..." "WARNING"
        Write-RDPPortLog "NOTE: This will disconnect any active RDP sessions!" "WARNING"
        
        # Give user a chance to abort
        if (-not $TestMode) {
            Write-Host "`nWARNING: About to restart Terminal Services. This will disconnect active RDP sessions." -ForegroundColor Yellow
            Write-Host "Press Ctrl+C within 10 seconds to abort, or wait to continue..." -ForegroundColor Yellow
            Start-Sleep -Seconds 10
        }
        
        Restart-Service -Name "TermService" -Force -ErrorAction Stop
        Write-RDPPortLog "Terminal Services restarted successfully" "SUCCESS"
        
        # Wait for service to fully start
        Start-Sleep -Seconds 5
        
        # Verify service is running
        $service = Get-Service -Name "TermService"
        if ($service.Status -eq "Running") {
            Write-RDPPortLog "Terminal Services is running on new port" "SUCCESS"
            return $true
        } else {
            Write-RDPPortLog "Terminal Services status: $($service.Status)" "WARNING"
            return $false
        }
        
    } catch {
        Write-RDPPortLog "Failed to restart Terminal Services: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Function to update RDP Defender scripts for new port
function Update-RDPDefenderScripts {
    param([int]$NewPort)
    
    try {
        Write-RDPPortLog "Updating RDP Defender scripts for port $NewPort..." "INFO"
        
        $scriptPath = Split-Path -Parent $LogPath
        $rdpDefenderScript = Join-Path $scriptPath "RDPDefender.ps1"
        
        if (Test-Path $rdpDefenderScript) {
            if ($TestMode) {
                Write-RDPPortLog "[TEST MODE] Would update RDPDefender.ps1 for port $NewPort" "INFO"
                return $true
            }
            
            $content = Get-Content $rdpDefenderScript -Raw
            
            # Update the firewall rule creation to use the new port
            $oldPattern = '-LocalPort 3389'
            $newPattern = "-LocalPort $NewPort"
            
            if ($content -match [regex]::Escape($oldPattern)) {
                $content = $content -replace [regex]::Escape($oldPattern), $newPattern
                $content | Out-File -FilePath $rdpDefenderScript -Encoding UTF8
                Write-RDPPortLog "Updated RDPDefender.ps1 to use port $NewPort" "SUCCESS"
            } else {
                Write-RDPPortLog "RDPDefender.ps1 already configured for custom port or pattern not found" "INFO"
            }
        } else {
            Write-RDPPortLog "RDPDefender.ps1 not found at expected location" "WARNING"
        }
        
        return $true
    } catch {
        Write-RDPPortLog "Failed to update RDP Defender scripts: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Function to restore default RDP port (3389)
function Restore-DefaultRDPPort {
    try {
        Write-RDPPortLog "Restoring default RDP port (3389)..." "INFO"
        
        if ($TestMode) {
            Write-RDPPortLog "[TEST MODE] Would restore RDP port to 3389" "INFO"
            return $true
        }
        
        # Backup current configuration
        $backupPath = Backup-RDPConfig
        if (-not $backupPath) {
            Write-RDPPortLog "Could not backup current configuration before restore" "WARNING"
        }
        
        # Set port back to 3389
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "PortNumber" -Value 3389 -ErrorAction Stop
        Write-RDPPortLog "Restored RDP port to 3389 in registry" "SUCCESS"
        
        # Re-enable default firewall rules
        $defaultRules = Get-NetFirewallRule -DisplayName "*Remote Desktop*" -ErrorAction SilentlyContinue
        foreach ($rule in $defaultRules) {
            if (-not $rule.Enabled) {
                Set-NetFirewallRule -Name $rule.Name -Enabled True
                Write-RDPPortLog "Re-enabled default firewall rule: $($rule.DisplayName)" "SUCCESS"
            }
        }
        
        # Remove custom firewall rules
        $customRules = Get-NetFirewallRule -DisplayName "RDP_Custom_Port_*" -ErrorAction SilentlyContinue
        foreach ($rule in $customRules) {
            Remove-NetFirewallRule -Name $rule.Name -Confirm:$false
            Write-RDPPortLog "Removed custom firewall rule: $($rule.DisplayName)" "SUCCESS"
        }
        
        # Update RDP Defender scripts back to default port
        $scriptPath = Split-Path -Parent $LogPath
        $rdpDefenderScript = Join-Path $scriptPath "RDPDefender.ps1"
        
        if (Test-Path $rdpDefenderScript) {
            $content = Get-Content $rdpDefenderScript -Raw
            $content = $content -replace '-LocalPort \d+', '-LocalPort 3389'
            $content | Out-File -FilePath $rdpDefenderScript -Encoding UTF8
            Write-RDPPortLog "Updated RDPDefender.ps1 back to default port 3389" "SUCCESS"
        }
        
        # Restart RDP service
        Restart-RDPService | Out-Null
        
        Write-RDPPortLog "Successfully restored default RDP configuration" "SUCCESS"
        return $true
        
    } catch {
        Write-RDPPortLog "Failed to restore default RDP port: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Function to verify RDP connectivity
function Test-RDPConnectivity {
    param([int]$Port)
    
    try {
        Write-RDPPortLog "Testing RDP connectivity on port $Port..." "INFO"
        
        # Test if the port is listening
        $listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
        if ($listener) {
            Write-RDPPortLog "RDP service is listening on port $Port" "SUCCESS"
            return $true
        } else {
            Write-RDPPortLog "RDP service is not listening on port $Port" "ERROR"
            return $false
        }
        
    } catch {
        Write-RDPPortLog "Failed to test RDP connectivity: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Main execution
function Start-RDPPortConfiguration {
    Write-RDPPortLog "=== RDP Port Configuration Started ===" "INFO"
    
    if ($CheckOnly) {
        Show-CurrentConfig
        return
    }
    
    if ($RestoreDefault) {
        if (-not $Force) {
            Write-Host "`n[WARNING] This will restore RDP to default port 3389" -ForegroundColor Yellow
            $confirm = Read-Host "Do you want to continue? (y/N)"
            if ($confirm -ne 'y' -and $confirm -ne 'Y') {
                Write-Host "Operation cancelled by user." -ForegroundColor Yellow
                return
            }
        }
        $success = Restore-DefaultRDPPort
        if ($success) {
            Write-RDPPortLog "=== Default RDP Port Restoration Completed ===" "SUCCESS"
        } else {
            Write-RDPPortLog "=== Default RDP Port Restoration Failed ===" "ERROR"
        }
        return
    }
    
    # Interactive port selection if no port specified
    if ($NewPort -eq 0 -and -not $Force) {
        Write-Host "`n=== RDP Port Configuration ===" -ForegroundColor Cyan
        Write-Host "Current RDP Configuration:" -ForegroundColor White
        Show-CurrentConfig
        
        Write-Host "`nSelect an option:" -ForegroundColor Yellow
        Write-Host "1) Use recommended port 3390 (most common alternative)" -ForegroundColor White
        Write-Host "2) Enter custom port number" -ForegroundColor White
        Write-Host "3) Cancel operation" -ForegroundColor White
        
        do {
            $choice = Read-Host "`nEnter your choice (1-3)"
            switch ($choice) {
                "1" {
                    $NewPort = 3390
                    Write-Host "Selected port: 3390" -ForegroundColor Green
                    break
                }
                "2" {
                    do {
                        $customPort = Read-Host "Enter custom port number (1024-65535)"
                        if ([int]::TryParse($customPort, [ref]$NewPort)) {
                            if ($NewPort -ge 1024 -and $NewPort -le 65535) {
                                Write-Host "Selected port: $NewPort" -ForegroundColor Green
                                break
                            } else {
                                Write-Host "Port must be between 1024-65535" -ForegroundColor Red
                            }
                        } else {
                            Write-Host "Please enter a valid number" -ForegroundColor Red
                        }
                    } while ($true)
                    break
                }
                "3" {
                    Write-Host "Operation cancelled by user." -ForegroundColor Yellow
                    return
                }
                default {
                    Write-Host "Please enter 1, 2, or 3" -ForegroundColor Red
                }
            }
        } while ($choice -ne "1" -and $choice -ne "2" -and $choice -ne "3")
        
        # Final confirmation
        Write-Host "`n[WARNING] This will change your RDP port to $NewPort" -ForegroundColor Yellow
        Write-Host "Make sure you update your RDP clients and firewall rules!" -ForegroundColor Yellow
        $confirm = Read-Host "Do you want to continue? (y/N)"
        if ($confirm -ne 'y' -and $confirm -ne 'Y') {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            return
        }
    } elseif ($NewPort -eq 0) {
        Write-RDPPortLog "No port specified and Force mode enabled. Using default 3390" "WARNING"
        $NewPort = 3390
    }
    
    # Validate new port
    if (-not (Test-ValidPort -Port $NewPort)) {
        return
    }
    
    # Get current configuration
    $currentConfig = Get-CurrentRDPConfig
    if (-not $currentConfig) {
        return
    }
    
    $oldPort = $currentConfig.CurrentPort
    
    if ($oldPort -eq $NewPort) {
        Write-RDPPortLog "RDP is already configured for port $NewPort" "INFO"
        return
    }
    
    Write-RDPPortLog "Changing RDP port from $oldPort to $NewPort" "INFO"
    
    if ($TestMode) {
        Write-RDPPortLog "Running in TEST MODE - no changes will be made" "WARNING"
    }
    
    # Backup current configuration
    $backupPath = Backup-RDPConfig
    if (-not $backupPath) {
        Write-RDPPortLog "Could not backup current configuration" "WARNING"
        if (-not $TestMode) {
            $response = Read-Host "Continue without backup? (y/N)"
            if ($response -notin @('y', 'Y', 'yes', 'Yes', 'YES')) {
                Write-RDPPortLog "Operation cancelled by user" "INFO"
                return
            }
        }
    }
    
    # Execute configuration changes
    $success = $true
    
    # Step 1: Update registry
    if (-not (Set-RDPPort -Port $NewPort)) {
        $success = $false
    }
    
    # Step 2: Update firewall rules
    if ($success -and -not (Update-FirewallRules -NewPort $NewPort -OldPort $oldPort)) {
        $success = $false
    }
    
    # Step 3: Update RDP Defender scripts
    if ($success) {
        Update-RDPDefenderScripts -NewPort $NewPort | Out-Null
    }
    
    # Step 4: Restart RDP service
    if ($success -and -not $TestMode) {
        if (-not (Restart-RDPService)) {
            $success = $false
        }
    }
    
    # Step 5: Verify connectivity
    if ($success -and -not $TestMode) {
        Start-Sleep -Seconds 2
        Test-RDPConnectivity -Port $NewPort | Out-Null
    }
    
    if ($success) {
        Write-RDPPortLog "=== RDP Port Configuration Completed Successfully ===" "SUCCESS"
        if (-not $TestMode) {
            Write-Host "`n[SUCCESS] RDP Port Change Summary:" -ForegroundColor Green
            Write-Host "   Old Port: $oldPort" -ForegroundColor White
            Write-Host "   New Port: $NewPort" -ForegroundColor White
            Write-Host "   Firewall Rules: Updated" -ForegroundColor White
            Write-Host "   RDP Service: Restarted" -ForegroundColor White
            Write-Host "   Backup: $backupPath" -ForegroundColor White
            Write-Host "`n[WARNING] Important Notes:" -ForegroundColor Yellow
            Write-Host "   - Update your RDP clients to use port $NewPort" -ForegroundColor Yellow
            Write-Host "   - Test connectivity before closing this session" -ForegroundColor Yellow
            Write-Host "   - Backup is saved for rollback if needed" -ForegroundColor Yellow
        }
    } else {
        Write-RDPPortLog "=== RDP Port Configuration Failed ===" "ERROR"
        Write-Host "`n[ERROR] Configuration failed. Check logs for details." -ForegroundColor Red
        if ($backupPath) {
            Write-Host "   Backup available at: $backupPath" -ForegroundColor Yellow
        }
    }
}

# Execute main function
Start-RDPPortConfiguration

Write-RDPPortLog "=== RDP Port Configuration Script Completed ===" "INFO"