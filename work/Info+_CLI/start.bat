@echo off
:: Check if PowerShell is available
where powershell >nul 2>&1
if %errorlevel% neq 0 (
    echo PowerShell is not available on this system.
    pause
    exit /b
)
:: Get the directory of the current batch file
set scriptPath=%~dp0infoplus.ps1


:: Check if the PowerShell script exists
if not exist "%scriptPath%" (
    echo PowerShell script not found at %scriptPath%.
    pause
    exit /b
)

:: Run the PowerShell script in a new window and close it on exit
start /wait powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%scriptPath%"

:: Clean up any orphaned processes
powershell.exe -NoProfile -Command "Get-Process -Name powershell | Stop-Process -Force -ErrorAction SilentlyContinue"

:: Script completed
echo PowerShell script execution completed.
exit /b
