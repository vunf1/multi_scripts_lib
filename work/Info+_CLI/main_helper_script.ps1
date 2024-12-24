$global:SystemInfoData = $null# Import required assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsFormsIntegration
Add-Type -AssemblyName System.Windows.Forms

# Function to ensure Winget is installed
function Ensure-Winget {
    Write-Host "Checking for Winget (Windows Package Manager)..." -ForegroundColor Yellow

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "Winget is not installed. Attempting to install Winget..." -ForegroundColor Cyan

        try {
            $appInstallerUri = "https://aka.ms/getwinget"
            $tempInstaller = "$env:TEMP\AppInstaller.msixbundle"

            Write-Host "Downloading Winget installer..." -ForegroundColor Cyan
            Invoke-WebRequest -Uri $appInstallerUri -OutFile $tempInstaller -UseBasicParsing

            Write-Host "Installing Winget..." -ForegroundColor Yellow
            Add-AppxPackage -Path $tempInstaller

            if (Get-Command winget -ErrorAction SilentlyContinue) {
                Write-Host "Winget installed successfully." -ForegroundColor Green
            } else {
                Write-Host "Failed to install Winget. Please install it manually." -ForegroundColor Red
                return $false
            }
        } catch {
            Write-Host "Failed to install Winget. Error: $_" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "Winget is already installed." -ForegroundColor Green
    }

    return $true
}

# Function to ensure WebView2 Runtime is installed
function Ensure-WebView2Runtime {
    Write-Host "Checking for WebView2 Runtime..." -ForegroundColor Yellow

    try {
        $webView2Installed = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients" -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -eq "{F1C0906E-33B9-48F6-95C9-78A0744C7E16}" }

        if ($webView2Installed) {
            Write-Host "WebView2 Runtime is already installed." -ForegroundColor Green
            return
        }
    } catch {
        Write-Host "WebView2 Runtime not found. Attempting installation via Winget..." -ForegroundColor Cyan
    }

    try {
        winget install --id Microsoft.EdgeWebView2Runtime --silent --accept-package-agreements --accept-source-agreements
        Write-Host "WebView2 Runtime installation completed successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to install WebView2 Runtime via Winget. Error: $_" -ForegroundColor Red
    }
}

# Start-Job block to execute tasks in the background
Start-Job -ScriptBlock {
    # Open the server file using the function logic
    $serverFilePath = "\\server\tools\#Keyboard Test.exe"
    try {
        if (Test-Path $serverFilePath) {
            Start-Process "explorer.exe" -ArgumentList $serverFilePath
        } else {
            [System.Windows.Forms.MessageBox]::Show("The directory does not exist: $serverFilePath", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to open the directory: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }

    # Open Camera
    Start-Process "microsoft.windows.camera:"

    # Open Device Manager
    Start-Process "devmgmt.msc"

    # Ensure Winget and WebView2 Runtime are installed
    try {
        Ensure-Winget
        Ensure-WebView2Runtime
    } catch {
        Write-Host "An error occurred during the setup process. Continuing with other tasks..." -ForegroundColor Red
    }

    # Create and display the YouTube iframe
    $tempHtmlPath = "$env:TEMP\YouTubeAudioTest.html"
    $htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Audio Test</title>
    <style>
        body {
            margin: 0;
            font-family: Arial, sans-serif;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            height: 100vh;
            background-color: #121212;
            color: #FFFFFF;
        }
        h1 {
            margin-bottom: 20px;
            font-size: 24px;
            text-align: center;
        }
        iframe {
            border: none;
            border-radius: 8px;
            box-shadow: 0 4px 8px rgba(0, 0, 0, 0.5);
        }
        footer {
            margin-top: 20px;
            font-size: 14px;
            color: #AAAAAA;
        }
        footer a {
            color: #1E90FF;
            text-decoration: none;
        }
        footer a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <h1>Welcome to the Stereo Audio Test</h1>
    <iframe 
        width="560" 
        height="315" 
        src="https://www.youtube.com/embed/6TWJaFD6R2s?si=neAPfGrpkyS_5MTK&start=6&autoplay=1" 
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" 
        allowfullscreen>
    </iframe>
    <footer>
        <p>Developed by <a href="https://github.com/vunf1" target="_blank">vunf1</a></p>
    </footer>
</body>
</html>
"@
    Set-Content -Path $tempHtmlPath -Value $htmlContent -Encoding UTF8

    try {
        $process = Start-Process "msedge.exe" -ArgumentList "--app=file:///$TempHtmlPath --inprivate" -PassThru
        $process.WaitForExit()
        # Delay cleanup to ensure Edge fully releases the file
        Start-Sleep -Seconds 5
        Remove-Item -Path $tempHtmlPath -Force
    } catch {
        Write-Host "Error during iframe execution: $_" -ForegroundColor Red
    }
}

function Get-SystemInfo {
    Write-Host "`nRefreshing System Information..." -ForegroundColor Yellow

    # Collect System Information in parallel using PowerShell's ForEach-Object -Parallel safely
    $SystemInfoTasks = @(
        { return (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB },
        { return Get-CimInstance -ClassName Win32_Processor | ForEach-Object { "$( $_.Name.Trim() ) $($_.MaxClockSpeed) MHz Cores $($_.NumberOfCores) $($_.NumberOfLogicalProcessors) Socket $($_.SocketDesignation)" } },
        { return Get-CimInstance -ClassName Win32_VideoController | ForEach-Object { $_.Caption.Trim() } },
        { return (Get-CimInstance -ClassName Win32_OperatingSystem).Caption }
    )

    $results = @()
    foreach ($task in $SystemInfoTasks) {
        $results += & $task
    }

    $MemoryInfo, $CPUInfo, $GPUInfo, $WindowsStatus = $results

    try {
        $ActivationRaw = cscript /nologo $env:SystemRoot\System32\slmgr.vbs /dli | Select-String -Pattern "(License Status|Estado da Licen[çc]a):.+"
        $ActivationStatus = if ($ActivationRaw) {
            $ActivationRaw -replace "(License Status|Estado da Licen[çc]a): "
        } else {
            throw "Primary method failed"
        }
    } catch {
        try {
            $ActivationAlt = (Get-CimInstance -ClassName SoftwareLicensingProduct | Where-Object { $_.PartialProductKey -ne $null -and $_.LicenseStatus -eq 1 }).Name
            if ($ActivationAlt) {
                $ActivationStatus = "Licensed (via CIM)"
            } else {
                throw "CIM method failed"
            }
        } catch {
            try {
                $ActivationRegistry = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" | Select-Object -ExpandProperty DigitalProductId
                if ($ActivationRegistry) {
                    $ActivationStatus = "Licensed (via Registry)"
                } else {
                    $ActivationStatus = "Unknown"
                }
            } catch {
                $ActivationStatus = "Unknown"
            }
        }
    }

    $ActivationColor = if ($ActivationStatus -match "Licensed") { "Green" } else { "Red" }
    $CPUColor = if ($CPUInfo -match "AMD") { "Red" } else { "Blue" }
    $GPUColor = if ($GPUInfo -match "NVIDIA") { "Green" } elseif ($GPUInfo -match "AMD") { "Red" } else { "Blue" }

    $Disks = Get-Volume | Where-Object { $_.DriveLetter -ne $null } | 
        Select-Object DriveLetter, @{Label='Total Size (GB)'; Expression={[math]::round($_.Size/1GB,2)}}, 
                      @{Label='Free Space (GB)'; Expression={[math]::round($_.SizeRemaining/1GB,2)}}

    $global:SystemInfoData = [PSCustomObject]@{
        MemoryInfo = [math]::round($MemoryInfo,2)
        CPUInfo = $CPUInfo
        GPUInfo = $GPUInfo
        WindowsStatus = $WindowsStatus
        ActivationStatus = $ActivationStatus
        ActivationColor = $ActivationColor
        CPUColor = $CPUColor
        GPUColor = $GPUColor
        Disks = $Disks
    }
    Clear-Host
}

function Clear-SystemCache {
    Write-Host "`nAre you sure you want to clean the system cache? (Y/Yes/Sim/S)" -ForegroundColor Yellow
    $confirmation = Read-Host ">>>>>"
    if ($confirmation -match '^(Y|y|Yes|Sim|S)$') {
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

    # Set the active power plan to 'High Performance'
    <# $highPerformancePlan = (powercfg /l | Select-String -Pattern "High performance").Line.Split()[3]
    if ($highPerformancePlan) {
        powercfg /s $highPerformancePlan
        Write-Host "Set power plan to High Performance." -ForegroundColor Green
    } else {
        Write-Host "High Performance power plan not found." -ForegroundColor Red
    } #>

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

# Function to run a specified command
function Run-Command {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    try {
        Start-Job -ScriptBlock {
            Invoke-Expression -Command $using:Command
        } | Out-Null
    } catch {
        Write-Host "Failed to run the command: $_" -ForegroundColor Red
    }
}

# Running the activation script
function Run-ActivationScript {
    Write-Host "Running Activation Script in the background..." -ForegroundColor Yellow
    Run-Command -Command "irm https://get.activated.win | iex"
}
# Running memtest Windows Built in and create task to dispaly data after boot
function Run-MemoryDiagnosticWithTask {
    Write-Host "Launching Windows Memory Diagnostic Tool and setting up a scheduled task..." -ForegroundColor Yellow

    try {
        # Step 1: Start the Memory Diagnostic Tool
        Start-Process -FilePath "mdsched.exe"
        Write-Host "Memory Diagnostic Tool started successfully. The system will restart." -ForegroundColor Green

        # Step 2: Define a scheduled task to run after the restart
        $taskName = "FetchMemoryTestResults"
        $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -WindowStyle Hidden -Command `"Get-WinEvent -LogName System | Where-Object { $_.ProviderName -eq 'Microsoft-Windows-MemoryDiagnostics-Results' } | Select-Object TimeCreated, Message | Out-Host; Unregister-ScheduledTask -TaskName '$taskName' -Confirm:$false`""
        $taskTrigger = New-ScheduledTaskTrigger -AtStartup
        $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

        # Step 3: Register the scheduled task
        Register-ScheduledTask -Action $taskAction -Trigger $taskTrigger -TaskName $taskName -Description "Fetches memory diagnostic results after reboot and displays them in PowerShell."
        Write-Host "Scheduled task '$taskName' has been created successfully." -ForegroundColor Green

        Write-Host "The PC will restart to run the Memory Diagnostic Tool. After the reboot, results will be fetched and displayed automatically." -ForegroundColor Yellow
    } catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
    }
}

function Display-SystemInfo {
    Clear-Host
    if (-not $global:SystemInfoData) { Get-SystemInfo }


    Write-Host "=========================================================" -ForegroundColor Green
    Write-Host "       Developed with ♥ by " -NoNewline; Write-Host "Vunf1" -ForegroundColor Green  -NoNewline; Write-Host " for " -NoNewline; Write-Host "HardStock" -ForegroundColor Cyan
    Write-Host "=========================================================" -ForegroundColor Green
    Write-Host "`nSystem Information:" -ForegroundColor Cyan
    $global:SystemInfoData.Disks | Format-Table -AutoSize

    Write-Host "+----------------------------+-----------------------------+"
    Write-Host "| Total Physical Memory      | $($global:SystemInfoData.MemoryInfo) GB            "
    Write-Host "| CPU                        |" -NoNewline; Write-Host " $($global:SystemInfoData.CPUInfo)" -ForegroundColor $global:SystemInfoData.CPUColor
    Write-Host "| GPU                        |" -NoNewline; Write-Host " $($global:SystemInfoData.GPUInfo)" -ForegroundColor $global:SystemInfoData.GPUColor
    Write-Host "| Windows Version            | $($global:SystemInfoData.WindowsStatus)           "
    Write-Host "| Activation Status          |" -NoNewline; Write-Host " $($global:SystemInfoData.ActivationStatus)" -ForegroundColor $global:SystemInfoData.ActivationColor
    Write-Host "+----------------------------+-----------------------------+"
}

function KeyPressOption {
    param ([ConsoleKeyInfo]$Key)
    switch ($Key.KeyChar) {
        "1" { Get-SystemInfo; Display-SystemInfo }
        "2" { Start-Process "microsoft.windows.camera:" }
        "3" { Start-Process "msedge" -ArgumentList "-inprivate https://en.key-test.ru/" }
        "4" { Start-Process "devmgmt.msc" }
        "5" { Restart-WindowsUpdateAndCleanCache }
        "6" { Use-ConfigurePowerSettings }
        "7" { Run-ActivationScript }
        "8" { Run-MemoryDiagnosticWithTask }
        "9" { exit }
        default { return }
    }
}

while ($true) {
    Display-SystemInfo
    Write-Host "`nChoose an option - 8 to EXIT:" -ForegroundColor Yellow
    Write-Host "1. Refresh System Information"
    Write-Host "2. Open Camera"
    Write-Host "3. Keyboard Test - Online"
    Write-Host "4. Device Manager - Check Unknown Devices"
    Write-Host "5. Restart Windows Update and Clean Cache"
    Write-Host "6. Configure Display Not coming back after Suspend - TWEAK"
    Write-Host "7. Microsoft Activation"
    Write-Host "8. Test Memory Windows - Restart Required"
    Write-Host "9. Exit"
    Write-Host " "
    do {
        $key = [System.Console]::ReadKey($true)
    } while (-not ($key.KeyChar -match '^[1-9]$'))

    KeyPressOption $key
}
# Get-WinEvent -LogName System | Where-Object { $_.ProviderName -eq "Microsoft-Windows-MemoryDiagnostics-Results" } | Select-Object TimeCreated, Message
