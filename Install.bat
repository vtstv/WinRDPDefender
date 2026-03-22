@echo off
:: RDP Defender Installation Launcher
:: This batch file bypasses execution policy and requests admin privileges

:: Check for admin privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Running with administrator privileges...
    goto :run
) else (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:run
:: Run the installation script with execution policy bypass
echo.
echo ========================================
echo  RDP Defender Installation
echo ========================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-RDPDefender.ps1" %*
echo.
if %errorLevel% == 0 (
    echo Installation completed successfully!
) else (
    echo Installation failed with error code: %errorLevel%
)
echo.
pause
