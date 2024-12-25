$global:SystemInfoData = $null# Import required assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsFormsIntegration
Add-Type -AssemblyName System.Windows.Forms

# Function to ensure Winget is installed
# Start-Job block to execute tasks in the background
Start-Job -ScriptBlock {
    # Function to ensure Winget is installed    
    function Start-Executable {
        param (
            [string]$FilePath,
            [string]$DisplayName
        )

        try {
            if (Test-Path $FilePath) {
                Start-Process "explorer.exe" -ArgumentList $FilePath
                Write-Host "Launched: $DisplayName" -ForegroundColor Green
            } else {
                Write-Host "File not found: $FilePath" -ForegroundColor Red
            }
        } catch {
            Write-Host "Error launching ${DisplayName}: $_" -ForegroundColor Red
        }
    }

    function Install-Winget {
        Write-Host "Checking for Winget..." -ForegroundColor Yellow
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Host "Winget is not installed. Installing..." -ForegroundColor Cyan
            try {
                $appInstallerUri = "https://aka.ms/getwinget"
                $tempInstaller = "$env:TEMP\AppInstaller.msixbundle"
                if (Test-Path $tempInstaller) { Remove-Item -Path $tempInstaller -Force }
                Invoke-WebRequest -Uri $appInstallerUri -OutFile $tempInstaller -UseBasicParsing
                Add-AppxPackage -Path $tempInstaller
                if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
                    Write-Host "Failed to install Winget." -ForegroundColor Red
                    return $false
                }
                Write-Host "Winget installed successfully." -ForegroundColor Green
            } catch {
                Write-Host "Error installing Winget: $_" -ForegroundColor Red
                return $false
            }
        } else {
            Write-Host "Winget is already installed." -ForegroundColor Green
        }
        return $true
    }

    function Install-WebView2Runtime {
        Write-Host "Checking for WebView2 Runtime..." -ForegroundColor Yellow
        try {
            $webView2Installed = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F1C0906E-33B9-48F6-95C9-78A0744C7E16}" -ErrorAction SilentlyContinue
            if ($webView2Installed) {
                Write-Host "WebView2 Runtime is already installed." -ForegroundColor Green
                return $true
            }
        } catch {
            Write-Host "Error checking WebView2 Runtime: $_" -ForegroundColor Cyan
        }
        try {
            winget install --id Microsoft.EdgeWebView2Runtime --silent --accept-package-agreements --accept-source-agreements
            Write-Host "WebView2 Runtime installed successfully." -ForegroundColor Green
        } catch {
            Write-Host "Error installing WebView2 Runtime: $_" -ForegroundColor Red
            return $false
        }
        return $true
    }

    # Task execution
    $executables = @{
        "Keyboard Test"      = "\\server\tools\#Keyboard Test.exe"
        "Battery Info View"  = "\\server\tools\Tools\batteryinfoview\BatteryInfoView.exe"
        "BlueScreen View"    = "\\server\tools\Tools\BlueScreen View\BlueScreenView.exe"
    }

    foreach ($name in $executables.Keys) {
        Start-Executable -FilePath $executables[$name] -DisplayName $name
    }

    # Open Camera
    Start-Process "microsoft.windows.camera:"

    # Open Device Manager
    Start-Process "devmgmt.msc"

    # Ensure Winget and WebView2 Runtime are installed
    try {
        if (-not (Install-Winget)) {
            Write-Host "Failed to ensure Winget installation." -ForegroundColor Red
        }

        if (-not (Install-WebView2Runtime)) {
            Write-Host "Failed to ensure WebView2 Runtime installation." -ForegroundColor Red
        }
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
    <link rel="icon" href="https://img.icons8.com/ios-filled/50/ffffff/speaker.png" type="image/png"> <!-- Update with your favicon URL -->
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
        iframe {
            width: 90vw; /* 90% of the viewport width */
            height: 90vh; /* 90% of the viewport height */
            border: none;
            border-radius: 8px;
            box-shadow: 0 4px 8px rgba(0, 0, 0, 0.5);
        }
    </style>
</head>
<body>
    <iframe
        src="https://www.youtube.com/embed/6TWJaFD6R2s?si=neAPfGrpkyS_5MTK&start=6&autoplay=1"
        allowfullscreen>
    </iframe>
    <footer>
        <p>Developed by <a href="https://github.com/vunf1" target="_blank">vunf1</a></p>
    </footer>
</body>
</html>
"@
    Set-Content -Path $tempHtmlPath -Value $htmlContent -Encoding UTF8
    #Set Edge window to top right and 1/4 of total display size
    try {
        # Launch Edge with the specified page
        $process = Start-Process "msedge.exe" -ArgumentList "--app=file:///$TempHtmlPath --inprivate" -PassThru
    
        # Wait for the process to start
        Start-Sleep -Seconds 2
    
        # Resize and reposition the Edge window using Windows API
        Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    
    public class WindowHelper {
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetWindowRect(IntPtr hWnd, ref RECT lpRect);
    
        [DllImport("user32.dll")]
        public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
    
        [StructLayout(LayoutKind.Sequential)]
        public struct RECT {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }
    
        public static RECT GetWindowRect(IntPtr hWnd) {
            RECT rect = new RECT();
            GetWindowRect(hWnd, ref rect);
            return rect;
        }
    }
"@
    
        # Get the process address for the Edge window
        $processHandle = (Get-Process -Id $process.Id).MainWindowHandle
    
        # Get screen dimensions
        $screenWidth = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
        $screenHeight = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height
    
        # Calculate window dimensions for 1/4 of the screen
        $windowWidth = [math]::Floor($screenWidth / 2)
        $windowHeight = [math]::Floor($screenHeight / 2)

        # Position the window to the top-right corner
        $posX = $screenWidth - $windowWidth
        $posY = 0
        # Move and resize the window to the top-left corner (or another position if desired)
        [WindowHelper]::MoveWindow($processHandle, $posX, $posY, $windowWidth, $windowHeight, $true)
    
        # Wait for Edge process to exit
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
        # Fetch activation status
        $ActivationRaw = cscript /nologo $env:SystemRoot\System32\slmgr.vbs /dli | Select-String -Pattern "(License Status|Estado da Licen[çc]a|Estado da Ativa[çc][ãa]o):.+"
        $ActivationStatus = if ($ActivationRaw) {
            $ActivationRaw -replace "(License Status|Estado da Licen[çc]a|Estado da Ativa[çc][ãa]o): "
        } else {
            throw "Primary method failed"
        }
    
        # Fetch license type
        $LicenseTypeRaw = cscript /nologo $env:SystemRoot\System32\slmgr.vbs /dli | Select-String -Pattern "(Retail|OEM|Volume|Subscription|Evaluation|Academic|NFR|Upgrade|COEM|Pre-release|Enterprise|Insider|Education|Trial|MSDN|Insider|Provisória|Subscrip[çc][ãa]o|Avalia[çc][ãa]o|Acad[êe]mica|Ensino|Não Para Revenda)"
        $LicenseType = $LicenseTypeRaw.Matches.Value -join ", "
    
        # Determine subtypes
        $LicenseSubtypeMapping = @{
            "Volume"        = @{
                "Patterns"  = "(KMS|MAK|AAD-based|AD-based|Baseada em AAD|Baseada em AD)"
                "Subtypes"  = @{
                    "KMS|Gest[ãa]o de Chaves (KMS)" = "KMS"
                    "MAK|Chave de Ativação Múltipla (MAK)" = "MAK"
                    "AAD-based|Baseada em AAD" = "AAD-based"
                    "AD-based|Baseada em AD" = "Active Directory-based"
                }
                "Default"   = "Unknown Volume Type"
            }
            "Retail|Venda a Varejo" = @{
                "Patterns"  = "(Upgrade|Atualiza[çc][ãa]o)"
                "Subtypes"  = @{
                    "Upgrade|Atualiza[çc][ãa]o" = "Upgrade"
                }
                "Default"   = "Standard"
            }
            "OEM" = @{
                "Patterns"  = "(COEM|OEM Comercial)"
                "Subtypes"  = @{
                    "COEM|OEM Comercial" = "Commercial OEM"
                }
                "Default"   = "Standard OEM"
            }
            "Subscription|Subscrip[çc][ãa]o" = @{
                "Patterns"  = "(Microsoft 365|Visual Studio|Outro)"
                "Subtypes"  = @{
                    "Microsoft 365" = "Microsoft 365"
                    "Visual Studio" = "Visual Studio Subscription"
                }
                "Default"   = "Other Subscription"
            }
            "Evaluation|Avalia[çc][ãa]o" = @{
                "Patterns"  = "(Trial|Provis[óo]ria)"
                "Subtypes"  = @{
                    "Trial|Provis[óo]ria" = "Trial"
                }
                "Default"   = "Standard Evaluation"
            }
            "Academic|Acad[êe]mica|Education|Ensino" = @{
                "Default"   = "Education or Academic"
            }
            "Enterprise" = @{
                "Patterns"  = "(Agreement|Acordo)"
                "Subtypes"  = @{
                    "Agreement|Acordo" = "Enterprise Agreement"
                }
                "Default"   = "Standard Enterprise"
            }
            "NFR|Não Para Revenda" = @{
                "Default"   = "Not For Resale"
            }
            "Pre-release|Insider" = @{
                "Default"   = "Insider/Pre-release"
            }
        }
        
        # Efficiently determine the subtype
        foreach ($type in $LicenseSubtypeMapping.Keys) {
            if ($LicenseType -match $type) {
                $config = $LicenseSubtypeMapping[$type]
                if ($config.Patterns) {
                    # Check for specific subtypes
                    $rawSubtype = cscript /nologo $env:SystemRoot\System32\slmgr.vbs /dli | Select-String -Pattern $config.Patterns
                    foreach ($pattern in $config.Subtypes.Keys) {
                        if ($rawSubtype -match $pattern) {
                            $LicenseType += " ($($config.Subtypes[$pattern]))"
                            break
                        }
                    }
                }
                # Add default subtype if no match
                if ($LicenseType -notmatch "\(") {
                    $LicenseType += " ($($config.Default))"
                }
            }
        }
    
        # Combine activation status and license type
        $LicenseDetails = "$ActivationStatus - $LicenseType"
    
    } catch {
        try {
            # Fallback: CIM method
            $ActivationAlt = (Get-CimInstance -ClassName SoftwareLicensingProduct | Where-Object { $null -ne $_.PartialProductKey -and $_.LicenseStatus -eq 1 }).Name
            if ($ActivationAlt) {
                $LicenseDetails = "Licensed (via CIM) - $ActivationAlt"
            } else {
                throw "CIM method failed"
            }
        } catch {
            try {
                # Fallback: Registry method
                $ActivationRegistry = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" | Select-Object -ExpandProperty DigitalProductId
                if ($ActivationRegistry) {
                    $LicenseDetails = "Licensed (via Registry)"
                } else {
                    $LicenseDetails = "Unknown"
                }
            } catch {
                $LicenseDetails = "Unknown"
            }
        }
    }

    $ActivationColor = if ($ActivationStatus -match "Licensed|Licenciado") { "Green" } else { "Red" }
    $CPUColor = if ($CPUInfo -match "AMD") { "Red" } else { "Blue" }
    $GPUColor = if ($GPUInfo -match "NVIDIA") { "Green" } elseif ($GPUInfo -match "AMD") { "Red" } else { "Blue" }

    $Disks = Get-Volume | Where-Object {$null -ne $_.DriveLetter } | 
        Select-Object DriveLetter, @{Label='Total Size (GB)'; Expression={[math]::round($_.Size/1GB,2)}}, 
                      @{Label='Free Space (GB)'; Expression={[math]::round($_.SizeRemaining/1GB,2)}}

    $global:SystemInfoData = [PSCustomObject]@{
        MemoryInfo = [math]::round($MemoryInfo,2)
        CPUInfo = $CPUInfo
        GPUInfo = $GPUInfo
        WindowsStatus = $WindowsStatus
        ActivationStatus = "$LicenseDetails"
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
    if ($confirmation -match '^(Y|y|Yes|Sim|S|s)$') {
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
function Start-Command {
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
function Start-ActivationScript {
    Write-Host "Running Activation Script in the background..." -ForegroundColor Yellow
    Run-Command -Command "irm https://get.activated.win | iex"
}
# Running memtest Windows Built in and create task to dispaly data after boot
function Start-MemoryDiagnosticWithTask {
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
        Register-ScheduledTask -Action $taskAction -Trigger $taskTrigger -TaskName $taskName -Settings $taskSettings -Description "Fetches memory diagnostic results after reboot and displays them in PowerShell."
        Write-Host "Scheduled task '$taskName' has been created successfully." -ForegroundColor Green

        Write-Host "The PC will restart to run the Memory Diagnostic Tool. After the reboot, results will be fetched and displayed automatically." -ForegroundColor Yellow
    } catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
    }
}

function Show-SystemInfo {
    Clear-Host
    if (-not $global:SystemInfoData) { 
        Get-SystemInfo 
    }

    # Explicitly reference $global:SystemInfoData
    $data = $global:SystemInfoData
    Write-Host "=========================================================" -ForegroundColor Green
    Write-Host "       Developed with ♥ by " -NoNewline; Write-Host "Vunf1" -ForegroundColor Green  -NoNewline; Write-Host " for " -NoNewline; Write-Host "HardStock" -ForegroundColor Cyan
    Write-Host "=========================================================" -ForegroundColor Green
    Write-Host "`nSystem Information:" -ForegroundColor Cyan
    $data.Disks | Format-Table -AutoSize

    Write-Host "+----------------------------+-----------------------------+"
    Write-Host "| Total Physical Memory      | $($data.MemoryInfo) GB            "
    Write-Host "| CPU                        |" -NoNewline; Write-Host " $($data.CPUInfo)" -ForegroundColor $data.CPUColor
    Write-Host "| GPU                        |" -NoNewline; Write-Host " $($data.GPUInfo)" -ForegroundColor $data.GPUColor
    Write-Host "| Windows Version            | $($data.WindowsStatus)           "
    Write-Host "| Activation Status          |" -NoNewline; Write-Host " $($data.ActivationStatus)" -ForegroundColor $data.ActivationColor
    Write-Host "+----------------------------+-----------------------------+"
}

function KeyPressOption {
    param ([ConsoleKeyInfo]$Key)
    switch ($Key.KeyChar) {
        "1" { Get-SystemInfo; Show-SystemInfo }
        "2" { Start-Process "microsoft.windows.camera:" }
        "3" { Start-Process "msedge" -ArgumentList "-inprivate https://en.key-test.ru/" }
        "4" { Start-Process "devmgmt.msc" }
        "5" { Restart-WindowsUpdateAndCleanCache }
        "6" { Use-ConfigurePowerSettings }
        "7" { Start-ActivationScript }
        "8" { Start-MemoryDiagnosticWithTask }
        "0" { exit }
        default { return }
    }
}

while ($true) {
    Show-SystemInfo
    Write-Host "`nChoose an option - 8 to EXIT:" -ForegroundColor Yellow
    Write-Host "1. Refresh System Information"
    Write-Host "2. Open Camera"
    Write-Host "3. Keyboard Test - Online"
    Write-Host "4. Device Manager - Check Unknown Devices"
    Write-Host "5. Restart Windows Update and Clean Cache"
    Write-Host "6. TWEAK - Display Not coming back after Suspend "
    Write-Host "7. Microsoft Activation"
    Write-Host "8. Test Memory Windows - Restart Required"
    Write-Host "0. Exit"
    Write-Host " "
    do {
        $key = [System.Console]::ReadKey($true)
    } while (-not ($key.KeyChar -match '^[0-8]$'))

    KeyPressOption $key
}
# Get-WinEvent -LogName System | Where-Object { $_.ProviderName -eq "Microsoft-Windows-MemoryDiagnostics-Results" } | Select-Object TimeCreated, Message
