@echo off
:: RDP Defender Universal Uninstaller
:: Interactive menu for uninstallation with various options

:: Check for admin privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    goto :menu
) else (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:menu
cls
echo.
echo ========================================
echo   RDP Defender Uninstaller
echo ========================================
echo.
echo Select uninstallation option:
echo.
echo 1. Complete removal (everything)
echo 2. Remove but keep logs
echo 3. Remove but keep reports
echo 4. Remove but keep logs and reports
echo 5. Quick removal (no confirmations)
echo 6. Dry run (preview what would be removed)
echo 7. Cancel
echo.
set /p choice="Enter your choice (1-7): "

if "%choice%"=="1" goto :complete
if "%choice%"=="2" goto :keeplogs
if "%choice%"=="3" goto :keepreports
if "%choice%"=="4" goto :keepboth
if "%choice%"=="5" goto :quick
if "%choice%"=="6" goto :dryrun
if "%choice%"=="7" goto :cancel
echo.
echo Invalid choice. Please enter 1-7.
timeout /t 2 >nul
goto :menu

:complete
cls
echo.
echo ========================================
echo   Complete Removal
echo ========================================
echo.
echo This will remove ALL RDP Defender components:
echo   - All files and directories
echo   - Firewall rules
echo   - Scheduled tasks
echo   - Desktop shortcuts
echo   - Logs and reports
echo.
set /p confirm="Are you sure? (y/N): "
if /i not "%confirm%"=="y" goto :menu
echo.
echo Running complete uninstallation...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-RDPDefender.ps1" -Force
goto :done

:keeplogs
cls
echo.
echo ========================================
echo   Remove but Keep Logs
echo ========================================
echo.
echo This will remove RDP Defender but preserve logs.
echo Logs will be backed up to: %TEMP%
echo.
set /p confirm="Continue? (y/N): "
if /i not "%confirm%"=="y" goto :menu
echo.
echo Running uninstallation with log preservation...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-RDPDefender.ps1" -KeepLogs
goto :done

:keepreports
cls
echo.
echo ========================================
echo   Remove but Keep Reports
echo ========================================
echo.
echo This will remove RDP Defender but preserve reports.
echo Reports will be backed up to: %TEMP%
echo.
set /p confirm="Continue? (y/N): "
if /i not "%confirm%"=="y" goto :menu
echo.
echo Running uninstallation with report preservation...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-RDPDefender.ps1" -KeepReports
goto :done

:keepboth
cls
echo.
echo ========================================
echo   Remove but Keep Logs and Reports
echo ========================================
echo.
echo This will remove RDP Defender but preserve logs and reports.
echo Data will be backed up to: %TEMP%
echo.
set /p confirm="Continue? (y/N): "
if /i not "%confirm%"=="y" goto :menu
echo.
echo Running uninstallation with data preservation...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-RDPDefender.ps1" -KeepLogs -KeepReports
goto :done

:quick
cls
echo.
echo ========================================
echo   Quick Removal (No Confirmations)
echo ========================================
echo.
echo WARNING: This will immediately remove ALL components
echo without any further confirmations!
echo.
set /p confirm="Are you ABSOLUTELY sure? (y/N): "
if /i not "%confirm%"=="y" goto :menu
echo.
echo Running quick uninstallation...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Quick-Uninstall.ps1"
goto :done

:dryrun
cls
echo.
echo ========================================
echo   Dry Run (Preview Mode)
echo ========================================
echo.
echo This will show what would be removed without
echo making any actual changes.
echo.
pause
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-RDPDefender.ps1" -DryRun
goto :done

:cancel
cls
echo.
echo Uninstallation cancelled.
echo.
timeout /t 2 >nul
exit /b

:done
echo.
if %errorLevel% == 0 (
    echo.
    echo ========================================
    echo   Uninstallation Completed Successfully
    echo ========================================
    echo.
) else (
    echo.
    echo ========================================
    echo   Uninstallation Failed
    echo ========================================
    echo.
    echo Error code: %errorLevel%
    echo Check the logs for details.
    echo.
)
echo Press any key to exit...
pause >nul
exit /b
