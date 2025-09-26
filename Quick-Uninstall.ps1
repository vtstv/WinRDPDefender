# RDP Defender Quick Uninstaller
# Fast removal of all RDP Defender components without confirmation
#
# Copyright (c) 2025 Murr
# Repository: https://github.com/vtstv/WinRDPDefender
# Licensed under MIT License

param(
    [string]$InstallPath = "C:\WinRDPDefender"
)

Write-Host "RDP Defender Quick Uninstaller" -ForegroundColor Red
Write-Host "===============================" -ForegroundColor Red
Write-Host "WARNING: This will remove ALL RDP Defender components immediately!" -ForegroundColor Yellow

# Check administrator privileges
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Administrator privileges required!" -ForegroundColor Red
    exit 1
}

$removedCount = 0

# Remove desktop shortcuts
Write-Host "Removing desktop shortcuts..." -ForegroundColor Yellow
$desktopPath = [Environment]::GetFolderPath("Desktop")
$rdpDefenderFolderPath = Join-Path $desktopPath "RDP Defender"

# Remove RDP Defender folder and all shortcuts inside
if (Test-Path $rdpDefenderFolderPath) {
    try {
        $shortcuts = Get-ChildItem $rdpDefenderFolderPath -Filter "*.lnk" -ErrorAction SilentlyContinue
        $shortcutCount = $shortcuts.Count
        Remove-Item $rdpDefenderFolderPath -Recurse -Force -ErrorAction Stop
        Write-Host "Removed RDP Defender folder with $shortcutCount shortcuts" -ForegroundColor Green
    } catch {
        Write-Host "Failed to remove RDP Defender folder: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "RDP Defender folder not found on desktop" -ForegroundColor Yellow
}

# Legacy cleanup - remove old individual shortcuts if they exist
$legacyShortcuts = @(
    "RDP Defender - Show Stats.lnk",
    "RDP Defender - Generate Report.lnk", 
    "RDP Defender - Quick Status.lnk",
    "RDP Defender - Management Console.lnk",
    "RDP Defender - Change Port.lnk"
)

foreach ($shortcut in $legacyShortcuts) {
    $shortcutPath = Join-Path $desktopPath $shortcut
    if (Test-Path $shortcutPath) {
        try {
            Remove-Item $shortcutPath -Force -ErrorAction SilentlyContinue
            Write-Host "  ✓ Removed shortcut: $shortcut" -ForegroundColor Green
        } catch {
            Write-Host "  ✗ Failed to remove shortcut: $shortcut" -ForegroundColor Red
        }
    }
}

# Remove all firewall rules
Write-Host "Removing firewall rules..." -ForegroundColor Yellow
$rules = Get-NetFirewallRule -DisplayName "RDPDefender_Block_*" -ErrorAction SilentlyContinue
if ($rules) {
    foreach ($rule in $rules) {
        try {
            Remove-NetFirewallRule -DisplayName $rule.DisplayName -ErrorAction SilentlyContinue
            $removedCount++
            Write-Host "  ✓ Removed rule: $($rule.DisplayName)" -ForegroundColor Green
        } catch {
            Write-Host "  ✗ Failed to remove rule: $($rule.DisplayName)" -ForegroundColor Red
        }
    }
}

# Remove all scheduled tasks
Write-Host "Removing scheduled tasks..." -ForegroundColor Yellow
$tasks = Get-ScheduledTask -TaskName "RDPDefender_Unblock_*" -ErrorAction SilentlyContinue
if ($tasks) {
    foreach ($task in $tasks) {
        try {
            Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction SilentlyContinue
            $removedCount++
            Write-Host "  ✓ Removed task: $($task.TaskName)" -ForegroundColor Green
        } catch {
            Write-Host "  ✗ Failed to remove task: $($task.TaskName)" -ForegroundColor Red
        }
    }
}

# Remove installation directory
Write-Host "Removing installation directory..." -ForegroundColor Yellow
if (Test-Path $InstallPath) {
    try {
        Remove-Item $InstallPath -Recurse -Force -ErrorAction Stop
        $removedCount++
        Write-Host "  ✓ Removed directory: $InstallPath" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Failed to remove directory: $InstallPath" -ForegroundColor Red
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "  ℹ Directory not found: $InstallPath" -ForegroundColor Gray
}

# Clean temp files
Write-Host "Cleaning temporary files..." -ForegroundColor Yellow
$tempFiles = Get-ChildItem "$env:TEMP\RDPDefender_*" -ErrorAction SilentlyContinue
foreach ($file in $tempFiles) {
    try {
        Remove-Item $file.FullName -Force -Recurse -ErrorAction SilentlyContinue
        Write-Host "  ✓ Removed temp: $($file.Name)" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Failed to remove temp: $($file.Name)" -ForegroundColor Red
    }
}

# Final status
Write-Host "`nUninstallation Complete!" -ForegroundColor Green
Write-Host "Removed $removedCount components" -ForegroundColor Green

# Verify cleanup
$remainingRules = Get-NetFirewallRule -DisplayName "RDPDefender_Block_*" -ErrorAction SilentlyContinue
$remainingTasks = Get-ScheduledTask -TaskName "RDPDefender_Unblock_*" -ErrorAction SilentlyContinue
$remainingDir = Test-Path $InstallPath

if (($remainingRules | Measure-Object).Count -eq 0 -and 
    ($remainingTasks | Measure-Object).Count -eq 0 -and 
    -not $remainingDir) {
    Write-Host "✓ All RDP Defender components successfully removed!" -ForegroundColor Green
} else {
    Write-Host "⚠ Some components may still remain:" -ForegroundColor Yellow
    if ($remainingRules) { Write-Host "  - Firewall rules: $(($remainingRules | Measure-Object).Count)" -ForegroundColor Yellow }
    if ($remainingTasks) { Write-Host "  - Scheduled tasks: $(($remainingTasks | Measure-Object).Count)" -ForegroundColor Yellow }
    if ($remainingDir) { Write-Host "  - Installation directory still exists" -ForegroundColor Yellow }
}