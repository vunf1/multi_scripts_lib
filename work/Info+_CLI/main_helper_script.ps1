$global:SystemInfoData = $null

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

# Example: Running the activation script
function Run-ActivationScript {
    Write-Host "Running Activation Script in the background..." -ForegroundColor Yellow
    Run-Command -Command "irm https://get.activated.win | iex"
}

function Display-SystemInfo {
    Clear-Host
    if (-not $global:SystemInfoData) { Get-SystemInfo }

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
        "8" { exit }
        default { return }
    }
}

while ($true) {
    Display-SystemInfo

    Write-Host "`nChoose an option - 8 to EXIT:" -ForegroundColor Yellow
    Write-Host "1. Refresh System Information"
    Write-Host "2. Open Camera"
    Write-Host "3. Keyboard Test"
    Write-Host "4. Device Manager"
    Write-Host "5. Restart Windows Update and Clean Cache"
    Write-Host "6. Configure Display Settings - TWEAK"
    Write-Host "7. Microsoft Activation"
    Write-Host "8. Exit"

    do {
        $key = [System.Console]::ReadKey($true)
    } while (-not ($key.KeyChar -match '^[1-8]$'))

    KeyPressOption $key
}
