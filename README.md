# RDP Defender

Automated protection system for Windows Server against RDP brute force attacks.

**Copyright (c) 2025 Murr** | [GitHub](https://github.com/vtstv/WinRDPDefender) | MIT License

## Features

- Automatic IP blocking after failed login attempts
- Works with any RDP port (default or custom)
- Real-time monitoring and detailed reporting
- Geolocation tracking of attackers
- Automated cleanup and maintenance
- HTML reports with statistics

## Quick Start

### Installation

Double-click `Install.bat` - it will:
- Request administrator privileges
- Bypass execution policy automatically
- Guide you through installation options

Or use PowerShell directly:
```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\Install-RDPDefender.ps1
```

### Uninstallation

Double-click `Uninstall.bat` and choose removal options.

## Configuration

Default settings (customizable during installation):
- Max failed attempts: 5
- Time window: 30 minutes
- Block duration: 24 hours
- Monitoring interval: 5 minutes (if scheduled tasks enabled)

Edit `C:\WinRDPDefender\config.json` to adjust settings after installation.

## Usage

### Desktop Shortcuts (if created)
- **Show Stats** - View attack statistics
- **Generate Report** - Create HTML security report
- **Quick Status** - Fast overview of recent attacks
- **Management Console** - PowerShell console with commands
- **Change RDP Port** - Secure port configuration

### Command Line

```powershell
# View statistics
.\RDPMonitor.ps1 -ShowStats

# Generate HTML report (last 7 days)
.\RDPMonitor.ps1 -GenerateReport -DaysBack 7

# Export to CSV
.\RDPMonitor.ps1 -ExportCSV -DaysBack 30

# Test protection system
.\RDPDefender.ps1 -TestMode

# Change RDP port
.\Change-RDPPort.ps1

# Manual cleanup
.\CleanupTasks.ps1
```

## Emergency Commands

### Remove all blocks
```powershell
Get-NetFirewallRule -DisplayName "RDPDefender_Block_*" | Remove-NetFirewallRule
Get-ScheduledTask -TaskName "RDPDefender_Unblock_*" | Unregister-ScheduledTask -Confirm:$false
```

### List blocked IPs
```powershell
Get-NetFirewallRule -DisplayName "RDPDefender_Block_*" | 
    ForEach-Object { $_.DisplayName -replace "RDPDefender_Block_", "" -replace "_", "." }
```


## System Requirements

- Windows Server 2019/2022/2025
- PowerShell 5.1 or higher
- Administrator privileges

## Security Notes

- ALL IPs exceeding thresholds will be blocked automatically
- Test in a controlled environment first
- Keep alternative access methods available
- Monitor logs regularly
- Use strong passwords and enable NLA

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

**RDP Defender** - Protecting Windows Server from brute force attacks.
