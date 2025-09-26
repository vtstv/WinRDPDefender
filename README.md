# RDP Defender - Windows Server 2025 Remote Desktop Protection System

> **Copyright (c) 2025 Murr**  
> **Repository:** https://github.com/vtstv/WinRDPDefender  
> **License:** MIT License

## Overview
RDP Defender is a comprehensive PowerShell-based security solution designed to protect Windows Server 2025 from RDP brute force attacks. The system automatically monitors failed RDP attempts, blocks malicious IP addresses, and provides detailed reporting capabilities.

## Features

### 🛡️ Core Protection
- **Automatic IP Blocking**: Blocks IP addresses after configurable failed attempt thresholds
- **Configurable Thresholds**: Customizable failed attempt limits and time windows
- **Temporary Blocks**: Automatically removes blocks after specified duration

### 📊 Monitoring & Reporting
- **Real-time Monitoring**: Continuous surveillance of RDP login attempts
- **Detailed Analytics**: Comprehensive attack pattern analysis
- **Geolocation Tracking**: Identifies attacker locations and ISP information
- **HTML Reports**: Professional security reports with charts and statistics
- **CSV Export**: Data export for further analysis

### 🔧 Management Tools
- **Attack Monitor**: Real-time attack statistics and analysis
- **Automated Cleanup**: Removes expired blocks and rotates logs
- **Configuration Management**: Centralized configuration file

### ⚡ Automation
- **Scheduled Tasks**: Automated monitoring and maintenance
- **Log Rotation**: Automatic log file management
- **Self-Healing**: Automatic cleanup of expired rules and tasks

## System Requirements

- **Operating System**: Windows Server 2025 (compatible with Server 2019/2022)
- **PowerShell**: Version 5.1 or higher
- **Permissions**: Administrator privileges required
- **Disk Space**: Minimum 100MB for logs and reports
- **Network**: Internet access for IP geolocation (optional)

## Quick Installation

### Automated Installation (Recommended)
1. **Download** all scripts to a folder (e.g., `D:\Dev\WinRDPDefender`)
2. **Open PowerShell as Administrator** (required for installation)
3. **Navigate** to the script directory: `cd "D:\Dev\WinRDPDefender"`
4. **Run the installer**:
   ```powershell
   # Basic installation
   .\Install-RDPDefender.ps1
   
   # Installation with scheduled tasks (automated monitoring)
   .\Install-RDPDefender.ps1 -CreateScheduledTasks
   
   # Force overwrite existing installation
   .\Install-RDPDefender.ps1 -Force
   
   # Installation without desktop shortcuts
   .\Install-RDPDefender.ps1 -NoDesktopShortcuts
   ```

### Custom Installation Options
```powershell
# Custom installation path and settings
.\Install-RDPDefender.ps1 -InstallPath "D:\Security\RDPDefender" -MaxFailedAttempts 3 -BlockDurationHours 48 -CreateScheduledTasks

# Conservative settings for low-security environments
.\Install-RDPDefender.ps1 -MaxFailedAttempts 10 -TimeWindowMinutes 60 -BlockDurationHours 12

# Aggressive settings for high-security environments  
.\Install-RDPDefender.ps1 -MaxFailedAttempts 3 -TimeWindowMinutes 15 -BlockDurationHours 72 -CreateScheduledTasks

# Server installation without desktop shortcuts
.\Install-RDPDefender.ps1 -CreateScheduledTasks -NoDesktopShortcuts
```

### Desktop Shortcuts (Automatic)
After installation, you'll find a **"RDP Defender"** folder on your desktop containing these convenient shortcuts:
- **Show Stats**: View current attack statistics  
- **Generate Report**: Create comprehensive HTML security report
- **Quick Status**: Fast overview of recent attacks and active blocks
- **Management Console**: Opens persistent PowerShell console with command help and current directory set
- **Change RDP Port**: Interactive RDP port configuration tool

### Installation Verification
After installation, verify the setup:
```powershell
# Navigate to installation directory
cd "C:\WinRDPDefender"

# Test the system
.\RDPDefender.ps1 -TestMode

# View current statistics
.\RDPMonitor.ps1 -ShowStats

# Check if scheduled tasks were created (if used -CreateScheduledTasks)
Get-ScheduledTask -TaskName "RDPDefender_*"
```

## Uninstallation

RDP Defender provides two uninstaller scripts for complete system cleanup:

### Complete Uninstaller (Recommended)
The main uninstaller provides detailed control and safety options:

```powershell
# Basic uninstallation (with confirmation prompt)
.\Uninstall-RDPDefender.ps1

# Custom installation path
.\Uninstall-RDPDefender.ps1 -InstallPath "D:\Security\RDPDefender"

# Preserve logs and reports
.\Uninstall-RDPDefender.ps1 -KeepLogs -KeepReports

# Force removal without confirmation
.\Uninstall-RDPDefender.ps1 -Force

# Preview what would be removed (no actual changes)
.\Uninstall-RDPDefender.ps1 -DryRun
```

**Uninstaller Features:**
- **Safe Removal**: Confirmation prompts prevent accidental deletion
- **Selective Cleanup**: Options to preserve logs and reports
- **Backup Creation**: Automatically backs up preserved data to temp directory
- **Comprehensive Logging**: Detailed uninstall log for troubleshooting
- **Dry Run Mode**: Preview removal actions without making changes
- **Verification**: Post-uninstall verification of cleanup success

### Quick Uninstaller
For immediate removal without confirmations:

```powershell
# Immediate removal of all components
.\Quick-Uninstall.ps1

# Custom installation path
.\Quick-Uninstall.ps1 -InstallPath "D:\Security\RDPDefender"
```

**What Gets Removed:**
- ✅ All firewall rules (`RDPDefender_Block_*`)
- ✅ All scheduled tasks (`RDPDefender_Unblock_*`)
- ✅ Installation directory and all contents
- ✅ Log files and reports (unless preserved)
- ✅ Temporary files and cache
- ✅ Configuration files

**Preserved Data Locations:**
When using `-KeepLogs` or `-KeepReports`, data is backed up to:
- Logs: `%TEMP%\RDPDefender_Logs_Backup_[timestamp]`
- Reports: `%TEMP%\RDPDefender_Reports_Backup_[timestamp]`

## Configuration

### Default Settings
- **Max Failed Attempts**: 5 attempts
- **Time Window**: 30 minutes
- **Block Duration**: 24 hours
- **Monitoring Interval**: 5 minutes
- **Log Retention**: 30 days

### Customization
Edit the configuration file at `C:\WinRDPDefender\config.json`:
```json
{
  "MaxFailedAttempts": 5,
  "TimeWindowMinutes": 30,
  "BlockDurationHours": 24,
  "LogPath": "C:\\WinRDPDefender\\Logs",
  "ReportPath": "C:\\WinRDPDefender\\Reports"
}
```

## Usage Guide

### Monitoring and Analysis
```powershell
# View current attack statistics
.\RDPMonitor.ps1 -ShowStats

# Generate detailed HTML report
.\RDPMonitor.ps1 -GenerateReport -DaysBack 7

# Export data to CSV
.\RDPMonitor.ps1 -ExportCSV -DaysBack 30

# Analyze specific time period
.\RDPMonitor.ps1 -ShowStats -DaysBack 1
```

### Manual Protection
```powershell
# Run defender manually (test mode)
.\RDPDefender.ps1 -TestMode

# Run with custom settings
.\RDPDefender.ps1 -MaxFailedAttempts 3 -TimeWindowMinutes 15 -BlockDurationHours 48

# Check specific time window
.\RDPDefender.ps1 -TimeWindowMinutes 60
```

### Maintenance
```powershell
# Run cleanup manually
.\CleanupTasks.ps1

# Dry run cleanup (preview changes)
.\CleanupTasks.ps1 -DryRun

# Custom cleanup settings
.\CleanupTasks.ps1 -CleanupDays 60 -MaxLogSizeMB 200
```

### RDP Port Security
```powershell
# Interactive mode - prompts for port selection (3390 or custom)
.\Change-RDPPort.ps1

# Change to specific port with confirmation prompt
.\Change-RDPPort.ps1 -NewPort 5555

# Change to specific port silently (no prompts)
.\Change-RDPPort.ps1 -NewPort 5555 -Force

# Check current RDP configuration
.\Change-RDPPort.ps1 -CheckOnly

# Restore to default port (3389) with confirmation
.\Change-RDPPort.ps1 -RestoreDefault

# Show help and usage examples
.\Change-RDPPort.ps1 -Help
```

## File Structure

```
C:\WinRDPDefender\
├── RDPDefender.ps1            # Main protection script
├── RDPMonitor.ps1             # Attack monitoring and reporting
├── CleanupTasks.ps1           # Maintenance and cleanup
├── Change-RDPPort.ps1         # Secure RDP port configuration
├── config.json                # Configuration file
├── Install-RDPDefender.ps1    # Installation script
├── Uninstall-RDPDefender.ps1  # Complete uninstaller with options
├── Quick-Uninstall.ps1        # Fast uninstaller without prompts
├── README.md                  # Documentation
├── EXAMPLES.md                # Usage examples
├── Logs\
│   ├── RDPDefender.log        # Main activity log
│   ├── Cleanup.log            # Cleanup operations log
│   └── Installation.log       # Installation log
└── Reports\
    ├── RDP_Security_Report_*.html  # HTML reports
    └── RDP_Events_*.csv           # CSV exports
```

## How It Works

### 1. Event Monitoring
- Monitors Windows Security Event Log (Event IDs 4624, 4625)
- Filters for RDP-specific logon attempts (Logon Types 3 and 10)
- Tracks failed attempts by source IP address

### 2. Threat Detection
- Counts failed attempts within configurable time windows
- Compares against threshold settings
- Blocks ALL IPs that exceed the threshold

### 3. Response Actions
- Creates Windows Firewall rules to block malicious IPs
- Schedules automatic removal of blocks
- Logs all security events with timestamps

### 4. Maintenance
- Automatically removes expired firewall rules
- Rotates log files when they exceed size limits
- Cleans up old scheduled tasks
- Generates periodic security reports

## Security Considerations

### ✅ Best Practices
- **Regular Monitoring**: Review logs and reports weekly
- **Strong Passwords**: Use complex passwords for all accounts
- **Multi-Factor Authentication**: Enable MFA when possible
- **VPN Access**: Consider VPN for remote access
- **Port Changes**: Change default RDP port from 3389
- **Network Level Authentication**: Enable NLA for RDP

### ⚠️ Important Notes
- **ALL IPs will be blocked** after failed attempts - no exceptions
- **Test in a controlled environment** before production deployment
- **Monitor blocked IPs** to ensure legitimate users aren't affected
- **Keep firewall logs enabled** for audit purposes
- **Regular backups** of configuration files

## Troubleshooting

### Common Issues

#### 1. Script Execution Policy
```powershell
# Enable script execution (run as Administrator)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```

#### 2. Locked Out of RDP
- **Physical Access**: Log in locally to remove blocks
- **PowerShell Command**: 
  ```powershell
  Get-NetFirewallRule -DisplayName "RDPDefender_Block_*" | Remove-NetFirewallRule
  ```

#### 3. Scripts Not Running
- Verify Administrator privileges
- Check Windows Event Log for errors
- Ensure all files are in correct locations
- Verify scheduled tasks are created and enabled

### Logging and Diagnostics
- **Main Log**: `C:\WinRDPDefender\Logs\RDPDefender.log`
- **Windows Event Log**: Security log (Event IDs 4624, 4625)
- **Firewall Log**: `%SystemRoot%\System32\LogFiles\Firewall\pfirewall.log`
- **Task Scheduler**: Check scheduled task history

### Performance Optimization
- **Log Rotation**: Configure appropriate log size limits
- **Cleanup Frequency**: Adjust cleanup intervals based on activity
- **Monitoring Window**: Balance security vs. performance

## Command Reference

### Main Protection Script
```powershell
# Basic usage
.\RDPDefender.ps1

# Test mode (no actual blocking)
.\RDPDefender.ps1 -TestMode

# Custom settings
.\RDPDefender.ps1 -MaxFailedAttempts 3 -TimeWindowMinutes 15 -BlockDurationHours 48
```

### Monitoring and Reports
```powershell
# Show current statistics
.\RDPMonitor.ps1 -ShowStats

# Generate HTML report
.\RDPMonitor.ps1 -GenerateReport -DaysBack 7

# Export to CSV
.\RDPMonitor.ps1 -ExportCSV -DaysBack 30
```

### Cleanup and Maintenance
```powershell
# Standard cleanup
.\CleanupTasks.ps1

# Preview changes without executing
.\CleanupTasks.ps1 -DryRun
```

## Emergency Commands

### Remove All Blocks
```powershell
# Remove all RDP Defender firewall rules
Get-NetFirewallRule -DisplayName "RDPDefender_Block_*" | Remove-NetFirewallRule

# Remove all scheduled unblock tasks
Get-ScheduledTask -TaskName "RDPDefender_Unblock_*" | Unregister-ScheduledTask -Confirm:$false
```

### Check Current Blocks
```powershell
# List all blocked IPs
Get-NetFirewallRule -DisplayName "RDPDefender_Block_*" | 
    ForEach-Object { $_.DisplayName -replace "RDPDefender_Block_", "" -replace "_", "." }
```

## Support and Maintenance

### Regular Maintenance Tasks
- **Weekly**: Review attack reports and statistics
- **Monthly**: Review and optimize configuration settings
- **Quarterly**: Review security policies and thresholds

### Backup Strategy
```powershell
# Backup configuration and entire directory
Copy-Item "C:\WinRDPDefender" "C:\Backup\WinRDPDefender_$(Get-Date -Format 'yyyyMMdd')" -Recurse
```

## License and Disclaimer

This software is provided "as is" without warranty of any kind. Use at your own risk. Always test thoroughly before deploying in production environments. The authors are not responsible for any damage or security breaches that may occur.

## License and Copyright

**Copyright (c) 2025 Murr**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### Repository Information
- **GitHub Repository:** https://github.com/vtstv/WinRDPDefender
- **Documentation:** Available in this repository
- **Issues and Support:** Please use GitHub Issues for bug reports and feature requests
- **Contributions:** Pull requests are welcome

### Attribution
If you use this software in your environment, attribution is appreciated but not required. When sharing or modifying this code, please maintain the copyright notice and license information.

---

**RDP Defender** - Protecting Windows Server 2025 from brute force attacks with aggressive IP blocking.