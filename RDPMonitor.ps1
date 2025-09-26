# RDP Attack Monitor and Alerting Script
# This script provides detailed monitoring and analysis of RDP connection attempts
#
# Copyright (c) 2025 Murr
# Repository: https://github.com/vtstv/WinRDPDefender
# Licensed under MIT License

param(
    [int]$DaysBack = 7,
    [string]$LogPath = "C:\WinRDPDefender\Logs",
    [switch]$GenerateReport = $false,
    [switch]$ShowStats = $false,
    [switch]$ExportCSV = $false,
    [string]$ReportPath = "C:\WinRDPDefender\Reports"
)

# Ensure running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator!"
    exit 1
}

# Create directories if they don't exist
if (!(Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

if (($GenerateReport -or $ExportCSV) -and !(Test-Path $ReportPath)) {
    New-Item -ItemType Directory -Path $ReportPath -Force | Out-Null
}

# Function to get RDP events
function Get-RDPEvents {
    param([int]$Days)
    
    $startTime = (Get-Date).AddDays(-$Days)
    $events = @()
    
    Write-Host "Analyzing RDP events from the last $Days days..." -ForegroundColor Cyan
    
    # Get successful logon events (Event ID 4624)
    try {
        $successEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'Security'
            ID = 4624
            StartTime = $startTime
        } -ErrorAction SilentlyContinue
        
        foreach ($logEvent in $successEvents) {
            $xml = [xml]$logEvent.ToXml()
            $logonType = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'LogonType' } | Select-Object -ExpandProperty '#text'
            
            # Filter for RDP logons (Type 3 and 10)
            if ($logonType -eq "3" -or $logonType -eq "10") {
                $sourceIP = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'IpAddress' } | Select-Object -ExpandProperty '#text'
                $userName = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'TargetUserName' } | Select-Object -ExpandProperty '#text'
                $domain = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'TargetDomainName' } | Select-Object -ExpandProperty '#text'
                
                if ($sourceIP -and $sourceIP -ne "-" -and $sourceIP -ne "127.0.0.1") {
                    $events += [PSCustomObject]@{
                        TimeCreated = $logEvent.TimeCreated
                        EventType = "Success"
                        SourceIP = $sourceIP
                        UserName = $userName
                        Domain = $domain
                        LogonType = $logonType
                        EventID = $logEvent.Id
                    }
                }
            }
        }
    } catch {
        Write-Warning "Could not retrieve successful logon events: $($_.Exception.Message)"
    }
    
    # Get failed logon events (Event ID 4625)
    try {
        $failedEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'Security'
            ID = 4625
            StartTime = $startTime
        } -ErrorAction SilentlyContinue
        
        foreach ($logEvent in $failedEvents) {
            $xml = [xml]$logEvent.ToXml()
            $logonType = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'LogonType' } | Select-Object -ExpandProperty '#text'
            
            # Filter for RDP logons (Type 3 and 10)
            if ($logonType -eq "3" -or $logonType -eq "10") {
                $sourceIP = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'IpAddress' } | Select-Object -ExpandProperty '#text'
                $userName = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'TargetUserName' } | Select-Object -ExpandProperty '#text'
                $domain = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'TargetDomainName' } | Select-Object -ExpandProperty '#text'
                $failureReason = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'Status' } | Select-Object -ExpandProperty '#text'
                
                if ($sourceIP -and $sourceIP -ne "-" -and $sourceIP -ne "127.0.0.1") {
                    $events += [PSCustomObject]@{
                        TimeCreated = $logEvent.TimeCreated
                        EventType = "Failed"
                        SourceIP = $sourceIP
                        UserName = $userName
                        Domain = $domain
                        LogonType = $logonType
                        EventID = $logEvent.Id
                        FailureReason = $failureReason
                    }
                }
            }
        }
    } catch {
        Write-Warning "Could not retrieve failed logon events: $($_.Exception.Message)"
    }
    
    return $events | Sort-Object TimeCreated -Descending
}

# Function to get IP geolocation information
function Get-IPGeolocation {
    param([string]$IPAddress)
    
    try {
        $response = Invoke-RestMethod -Uri "http://ip-api.com/json/$IPAddress" -TimeoutSec 10
        if ($response.status -eq "success") {
            return [PSCustomObject]@{
                Country = $response.country
                Region = $response.regionName
                City = $response.city
                ISP = $response.isp
                Organization = $response.org
                TimeZone = $response.timezone
                Latitude = $response.lat
                Longitude = $response.lon
            }
        }
    } catch {
        # Silently fail for geolocation - it's not critical
    }
    
    return $null
}

# Function to analyze attack patterns
function Get-AttackAnalysis {
    param([array]$Events)
    
    $analysis = @{
        TotalEvents = $Events.Count
        FailedAttempts = ($Events | Where-Object { $_.EventType -eq "Failed" }).Count
        SuccessfulLogins = ($Events | Where-Object { $_.EventType -eq "Success" }).Count
        UniqueIPs = ($Events | Select-Object -ExpandProperty SourceIP -Unique).Count
        UniqueUsers = ($Events | Select-Object -ExpandProperty UserName -Unique).Count
        TopAttackerIPs = @()
        TopTargetUsers = @()
        HourlyDistribution = @{}
        DailyDistribution = @{}
    }
    
    # Top attacker IPs
    $ipCounts = $Events | Where-Object { $_.EventType -eq "Failed" } | Group-Object SourceIP | Sort-Object Count -Descending | Select-Object -First 10
    foreach ($ip in $ipCounts) {
        $geoInfo = Get-IPGeolocation -IPAddress $ip.Name
        $analysis.TopAttackerIPs += [PSCustomObject]@{
            IPAddress = $ip.Name
            FailedAttempts = $ip.Count
            Country = if ($geoInfo) { $geoInfo.Country } else { "Unknown" }
            City = if ($geoInfo) { $geoInfo.City } else { "Unknown" }
            ISP = if ($geoInfo) { $geoInfo.ISP } else { "Unknown" }
        }
    }
    
    # Top target users
    $userCounts = $Events | Where-Object { $_.EventType -eq "Failed" } | Group-Object UserName | Sort-Object Count -Descending | Select-Object -First 10
    foreach ($user in $userCounts) {
        $analysis.TopTargetUsers += [PSCustomObject]@{
            UserName = $user.Name
            FailedAttempts = $user.Count
        }
    }
    
    # Hourly distribution
    for ($hour = 0; $hour -lt 24; $hour++) {
        $count = ($Events | Where-Object { $_.TimeCreated.Hour -eq $hour }).Count
        $analysis.HourlyDistribution[$hour] = $count
    }
    
    # Daily distribution
    $Events | ForEach-Object {
        $day = $_.TimeCreated.ToString("yyyy-MM-dd")
        if ($analysis.DailyDistribution.ContainsKey($day)) {
            $analysis.DailyDistribution[$day]++
        } else {
            $analysis.DailyDistribution[$day] = 1
        }
    }
    
    return $analysis
}

# Function to display statistics
function Show-Statistics {
    param([object]$Analysis)
    
    Write-Host "`n=== RDP Security Analysis ===" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    
    Write-Host "`nOverall Statistics:" -ForegroundColor Yellow
    Write-Host "Total RDP Events: $($Analysis.TotalEvents)"
    Write-Host "Failed Attempts: $($Analysis.FailedAttempts)" -ForegroundColor Red
    Write-Host "Successful Logins: $($Analysis.SuccessfulLogins)" -ForegroundColor Green
    Write-Host "Unique Source IPs: $($Analysis.UniqueIPs)"
    Write-Host "Unique Target Users: $($Analysis.UniqueUsers)"
    
    if ($Analysis.TopAttackerIPs.Count -gt 0) {
        Write-Host "`nTop Attacking IP Addresses:" -ForegroundColor Yellow
        $Analysis.TopAttackerIPs | Format-Table IPAddress, FailedAttempts, Country, City, ISP -AutoSize
    }
    
    if ($Analysis.TopTargetUsers.Count -gt 0) {
        Write-Host "`nMost Targeted Users:" -ForegroundColor Yellow
        $Analysis.TopTargetUsers | Format-Table UserName, FailedAttempts -AutoSize
    }
    
    Write-Host "`nHourly Attack Distribution:" -ForegroundColor Yellow
    for ($hour = 0; $hour -lt 24; $hour++) {
        $count = $Analysis.HourlyDistribution[$hour]
        $bar = "█" * [Math]::Min($count / 10, 50)
        Write-Host ("{0:D2}:00 [{1,3}] {2}" -f $hour, $count, $bar)
    }
}

# Function to generate HTML report
function New-HTMLReport {
    param([object]$Analysis, [array]$Events, [string]$OutputPath)
    
    $reportFile = Join-Path $OutputPath "RDP_Security_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>RDP Security Analysis Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #2c3e50; color: white; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .critical { background-color: #ffebee; border-left: 5px solid #f44336; }
        .warning { background-color: #fff3e0; border-left: 5px solid #ff9800; }
        .info { background-color: #e8f5e8; border-left: 5px solid #4caf50; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .chart { width: 100%; height: 300px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>RDP Security Analysis Report</h1>
        <p>Generated on: $(Get-Date)</p>
        <p>Server: $env:COMPUTERNAME</p>
        <p>Analysis Period: Last $DaysBack days</p>
        <p style="font-size: 14px; opacity: 0.8; margin-top: 15px;">
            <strong>RDP Defender</strong> v1.0 | 
            <a href="https://github.com/vtstv/WinRDPDefender" target="_blank" style="color: #ecf0f1;">GitHub Repository</a>
        </p>
    </div>
    
    <div class="section info">
        <h2>Executive Summary</h2>
        <ul>
            <li><strong>Total RDP Events:</strong> $($Analysis.TotalEvents)</li>
            <li><strong>Failed Attempts:</strong> $($Analysis.FailedAttempts)</li>
            <li><strong>Successful Logins:</strong> $($Analysis.SuccessfulLogins)</li>
            <li><strong>Unique Attacking IPs:</strong> $($Analysis.UniqueIPs)</li>
            <li><strong>Targeted Users:</strong> $($Analysis.UniqueUsers)</li>
        </ul>
    </div>
    
    <div class="section $(if ($Analysis.FailedAttempts -gt 100) { 'critical' } elseif ($Analysis.FailedAttempts -gt 10) { 'warning' } else { 'info' })">
        <h2>Threat Level Assessment</h2>
        <p>
"@

    if ($Analysis.FailedAttempts -eq 0) {
        $html += "            <strong>LOW RISK:</strong> No failed RDP attempts detected."
    } elseif ($Analysis.FailedAttempts -le 10) {
        $html += "            <strong>LOW RISK:</strong> Minimal failed RDP attempts detected. Continue monitoring."
    } elseif ($Analysis.FailedAttempts -le 100) {
        $html += "            <strong>MEDIUM RISK:</strong> Moderate number of failed RDP attempts. Consider strengthening security measures."
    } else {
        $html += "            <strong>HIGH RISK:</strong> High number of failed RDP attempts detected. Immediate action recommended."
    }

    $html += @"
        </p>
    </div>
    
    <div class="section">
        <h2>Top Attacking IP Addresses</h2>
        <table>
            <tr><th>IP Address</th><th>Failed Attempts</th><th>Country</th><th>City</th><th>ISP</th></tr>
"@

    foreach ($ip in $Analysis.TopAttackerIPs) {
        $html += "            <tr><td>$($ip.IPAddress)</td><td>$($ip.FailedAttempts)</td><td>$($ip.Country)</td><td>$($ip.City)</td><td>$($ip.ISP)</td></tr>`n"
    }

    $html += @"
        </table>
    </div>
    
    <div class="section">
        <h2>Most Targeted Users</h2>
        <table>
            <tr><th>Username</th><th>Failed Attempts</th></tr>
"@

    foreach ($user in $Analysis.TopTargetUsers) {
        $html += "            <tr><td>$($user.UserName)</td><td>$($user.FailedAttempts)</td></tr>`n"
    }

    $html += @"
        </table>
    </div>
    
    <div class="section">
        <h2>Recent Events (Last 50)</h2>
        <table>
            <tr><th>Time</th><th>Type</th><th>Source IP</th><th>Username</th><th>Domain</th></tr>
"@

    $recentEvents = $Events | Select-Object -First 50
    foreach ($logEvent in $recentEvents) {
        $eventClass = if ($logEvent.EventType -eq "Failed") { "style='color: red;'" } else { "style='color: green;'" }
        $html += "            <tr $eventClass><td>$($logEvent.TimeCreated)</td><td>$($logEvent.EventType)</td><td>$($logEvent.SourceIP)</td><td>$($logEvent.UserName)</td><td>$($logEvent.Domain)</td></tr>`n"
    }

    $html += @"
        </table>
    </div>
    
    <div class="section">
        <h2>Recommendations</h2>
        <ul>
            <li>Implement IP-based blocking for repeated failed attempts</li>
            <li>Use strong passwords and consider multi-factor authentication</li>
            <li>Change default RDP port from 3389 to a custom port</li>
            <li>Implement network-level authentication (NLA)</li>
            <li>Use VPN for remote access when possible</li>
            <li>Regularly review and update user access permissions</li>
            <li>Enable detailed audit logging for security events</li>
        </ul>
    </div>
    
    <div class="section" style="text-align: center; font-size: 12px; color: #666; margin-top: 40px;">
        <hr style="border: none; border-top: 1px solid #ddd; margin: 20px 0;">
        <p><strong>RDP Defender</strong> - Windows Server 2025 Remote Desktop Protection System</p>
        <p>Copyright (c) 2025 Murr | Repository: <a href="https://github.com/vtstv/WinRDPDefender" target="_blank">https://github.com/vtstv/WinRDPDefender</a></p>
        <p>Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Report Period: $($Events.Count) events analyzed</p>
    </div>
</body>
</html>
"@

    $html | Out-File -FilePath $reportFile -Encoding UTF8
    Write-Host "HTML report generated: $reportFile" -ForegroundColor Green
    return $reportFile
}

# Main execution
Write-Host "RDP Attack Monitor - Starting Analysis..." -ForegroundColor Cyan

# Get RDP events
$events = Get-RDPEvents -Days $DaysBack

if ($events.Count -eq 0) {
    Write-Host "No RDP events found in the specified time period." -ForegroundColor Yellow
    exit 0
}

# Analyze events
$analysis = Get-AttackAnalysis -Events $events

# Show statistics if requested
if ($ShowStats -or (!$GenerateReport -and !$ExportCSV)) {
    Show-Statistics -Analysis $analysis
}

# Generate HTML report if requested
if ($GenerateReport) {
    $reportFile = New-HTMLReport -Analysis $analysis -Events $events -OutputPath $ReportPath
    Write-Host "Opening report in default browser..." -ForegroundColor Green
    Start-Process $reportFile
}

# Export to CSV if requested
if ($ExportCSV) {
    $csvFile = Join-Path $ReportPath "RDP_Events_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $events | Export-Csv -Path $csvFile -NoTypeInformation
    Write-Host "Events exported to CSV: $csvFile" -ForegroundColor Green
}

Write-Host "`nAnalysis completed. Check logs in: $LogPath" -ForegroundColor Green