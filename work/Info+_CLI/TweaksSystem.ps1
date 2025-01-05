
function Clear-SystemCache {
    $confirmation = Show-CustomMessageBox -Message "Are you sure you want to clean the system cache?" -Title "Confirmation" -ButtonLayout "YesNo"

    if ($confirmation -eq "Yes") {
        Write-Host "`nCleaning System Cache..." -ForegroundColor Yellow

        # Clear Temp Files
        Write-Host "Clearing Temp Folder..." -ForegroundColor Orange
        Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue

        # Clear Windows Update Cache
        Write-Host "Stopping Windows Update Service..." -ForegroundColor Red
        Stop-Service -Name wuauserv -Force
        Write-Host "Clearing Windows Update Cache..." -ForegroundColor Orange
        Remove-Item "C:\Windows\SoftwareDistribution\*" -Recurse -Force
        Start-Service -Name wuauserv
        Write-Host "Restarting Windows Update Service..." -ForegroundColor Green

        # Clear Internet Explorer/Edge Cache
        Write-Host "Clearing Internet Explorer/Edge Cache..." -ForegroundColor Orange
        RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 255

        # Clear DNS Cache
        Write-Host "Clearing DNS Cache..." -ForegroundColor Orange
        Clear-DnsClientCache

        # Clear System Event Logs
        Write-Host "Clearing System Event Logs..." -ForegroundColor Orange
        wevtutil el | ForEach-Object { wevtutil cl $_ }

        # Clean Recycle Bin
        Write-Host "Emptying Recycle Bin..." -ForegroundColor Orange
        Clear-RecycleBin -Force

        # Clear Delivery Optimization Files
        Write-Host "Running Disk Cleanup..." -ForegroundColor Orange
        Start-Process "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait

        # Clear Windows Temp Files
        Write-Host "Clearing Windows Temp Folder..." -ForegroundColor Orange
        Remove-Item "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

        # Clean Default Downloads Folder
        Write-Host "Clearing Downloads Folder..." -ForegroundColor Orange
        Remove-Item "$env:USERPROFILE\Downloads\*" -Recurse -Force -ErrorAction SilentlyContinue

        Write-Host "`nSystem Cache Cleaned Successfully!" -ForegroundColor Green
    } else {
        Write-Host "Operation cancelled by user." -ForegroundColor Red
    }
}

# Function to configure power settings
function Use-ConfigurePowerSettings {
    Write-Host "Configuring Power Settings..." -ForegroundColor Yellow

    # Set sleep and screen off timers to 0
    powercfg /change standby-timeout-ac 0
    powercfg /change standby-timeout-dc 0
    powercfg /change monitor-timeout-ac 0
    powercfg /change monitor-timeout-dc 0
    Write-Host "Set sleep and screen-off timers to 0." -ForegroundColor Green

    # Disable fast startup
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f
    Write-Host "Fast Startup has been disabled." -ForegroundColor Green

    # Set screensaver to blank with a timer of 5 minutes
    reg add "HKCU\Control Panel\Desktop" /v SCRNSAVE.EXE /t REG_SZ /d "C:\Windows\System32\scrnsave.scr" /f
    reg add "HKCU\Control Panel\Desktop" /v ScreenSaveTimeOut /t REG_SZ /d 300 /f
    reg add "HKCU\Control Panel\Desktop" /v ScreenSaveActive /t REG_SZ /d 1 /f
    Write-Host "Screensaver set to blank with a timer of 5 minutes." -ForegroundColor Green

    Write-Host "Power settings configured successfully." -ForegroundColor Green
}
function Register-OEMKey {
    try {
        # Retrieve the OEM key
        $oemKey = (Get-CimInstance -ClassName SoftwareLicensingService).OA3xOriginalProductKey
        if (-not $oemKey) {
            Write-Host "OEM Key not found on this system." -ForegroundColor Red
            return
        }

        # Display the OEM Key
        Write-Host "OEM Key Found: $oemKey" -ForegroundColor Yellow

        # Reinstall the OEM key
        Write-Host "Reinstalling OEM key..." -ForegroundColor Cyan
        $installKeyCommand = "cscript.exe $env:SystemRoot\System32\slmgr.vbs /ipk $oemKey"
        Invoke-Expression $installKeyCommand

        # Activate the key
        Write-Host "Activating the OEM key..." -ForegroundColor Cyan
        $activateCommand = "cscript.exe $env:SystemRoot\System32\slmgr.vbs /ato"
        Invoke-Expression $activateCommand

        # Validate activation status
        Write-Host "Validating activation status..." -ForegroundColor Cyan
        $statusCommand = "cscript.exe $env:SystemRoot\System32\slmgr.vbs /dli"
        $activationStatus = Invoke-Expression $statusCommand

        # Display the activation status
        Write-Host "Activation Status:" -ForegroundColor Green
        Write-Host $activationStatus
    } catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
    }
}