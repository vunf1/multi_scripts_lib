
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

        # Display the confirmation dialog
        $response = Show-CustomMessageBox -Message "Do you want to register the OEM Key?" `
            -Title "Confirmation" `
            -ButtonLayout "YesNo" 
        
        if ($response -ne "Yes") {
            Write-Host "Operation cancelled by user." -ForegroundColor Red
            return
        }
        $tasks = @(
            @{ 
                Name = "Gathering OEM Key"; 
                Task = { Write-Host "OEM Key Found: $oemKey" -ForegroundColor Yellow } 
            },
            @{ 
                Name = "Reinstalling OEM Key"; 
                Task = {
                    $installKeyCommand = "cscript.exe"
                    $arguments = "$env:SystemRoot\System32\slmgr.vbs /ipk $oemKey"
                    Start-Process -FilePath $installKeyCommand -ArgumentList $arguments -NoNewWindow -Wait
                } 
            },
            @{ 
                Name = "Activating OEM Key"; 
                Task = {
                    $activateCommand = "cscript.exe"
                    $arguments = "$env:SystemRoot\System32\slmgr.vbs /ato"
                    Start-Process -FilePath $activateCommand -ArgumentList $arguments -NoNewWindow -Wait
                } 
            },
            @{ 
                Name = "Validating Activation Status"; 
                Task = {
                    $statusCommand = "cscript.exe"
                    $arguments = "$env:SystemRoot\System32\slmgr.vbs /dli"
                    $process = Start-Process -FilePath $statusCommand -ArgumentList $arguments -NoNewWindow -Wait -PassThru
                    $output = $process.StandardOutput.ReadToEnd()
                    Write-Host "Activation Status:" -ForegroundColor Green
                    Write-Host $output
                } 
            }
        )
        

        $totalTasks = $tasks.Count
        $progressCount = 0

        # Process each task with progress updates
        foreach ($taskItem in $tasks) {
            $progressCount++
            $percentComplete = [math]::Round(($progressCount / $totalTasks) * 100)

            Write-Progress -Activity "Registering OEM Key >>>>>> " `
                           -Status "Processing: $($taskItem.Name) ($progressCount of $totalTasks)" `
                           -PercentComplete $percentComplete
            & $taskItem.Task
        }

        # Clear the progress bar
        Write-Progress -Activity "Registering OEM Key" -Completed

        Write-Host "OEM Key registration process completed." -ForegroundColor Green

    } catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
    }
}

function Start-ActivationScript {
    try {
        
        $scriptContent = Invoke-RestMethod -Uri "https://get.activated.win"

        $scriptBlock = [ScriptBlock]::Create($scriptContent)

        Write-Host "Executing Activation Script..." -ForegroundColor Green
        Invoke-Command -ScriptBlock $scriptBlock

        Write-Host "Activation Script executed successfully." -ForegroundColor Green
    } catch {
        Write-Host "An error occurred while fetching or executing the Activation Script: $_" -ForegroundColor Red
    }
}

