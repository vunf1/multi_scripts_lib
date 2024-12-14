# PowerShell Core Version

function Get-SystemInfo {
    Write-Host "`nRefreshing System Information..." -ForegroundColor Yellow
    $MemoryInfo = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB
    $CPUInfo = Get-CimInstance -ClassName Win32_Processor | ForEach-Object {
        "$($_.Name.Trim()) $($_.MaxClockSpeed) MHz Cores $($_.NumberOfCores) $($_.NumberOfLogicalProcessors) Socket $($_.SocketDesignation)"
    } 
       
    $GPUInfo = Get-CimInstance -ClassName Win32_VideoController | ForEach-Object {
        "$($_.Caption.Trim())"
    }
    
    $WindowsStatus = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
    $ActivationRaw = cscript /nologo $env:SystemRoot\System32\slmgr.vbs /dli | Select-String -Pattern "License Status:.+"
    $ActivationStatus = $ActivationRaw -replace "License Status: "

    $ActivationColor = if ($ActivationStatus -match "Licensed") { "Green" } else { "Red" }
    $CPUColor = if ($CPUInfo -match "AMD") { "Red" } else { "Blue" }
    $GPUColor = if ($GPUInfo -match "NVIDIA") { "Green" } elseif ($GPUInfo -match "AMD") { "Red" } else { "Blue" }

    $Disks = Get-Volume | Where-Object { $_.DriveLetter -ne $null } | 
        Select-Object DriveLetter, @{Label='Total Size (GB)'; Expression={[math]::round($_.Size/1GB,2)}}, 
                      @{Label='Free Space (GB)'; Expression={[math]::round($_.SizeRemaining/1GB,2)}}

    Clear-Host
    Write-Host "`nSystem Information:" -ForegroundColor Cyan
    $Disks | Format-Table -AutoSize

    Write-Host "+----------------------------+-----------------------------+"
    Write-Host "| Total Physical Memory      | $([math]::round($MemoryInfo,2)) GB            "
    Write-Host "| CPU                        |" -NoNewline; Write-Host " $CPUInfo" -ForegroundColor $CPUColor
    Write-Host "| GPU                        |" -NoNewline; Write-Host " $GPUInfo" -ForegroundColor $GPUColor
    Write-Host "| Windows Version            | $WindowsStatus           "
    Write-Host "| Activation Status          |" -NoNewline; Write-Host " $ActivationStatus" -ForegroundColor $ActivationColor
    Write-Host "+----------------------------+-----------------------------+"
}
function Open-Camera {
    Write-Host "`nOpening Camera..." -ForegroundColor Green
    Start-Process "microsoft.windows.camera:"
    Get-SystemInfo 
}

function Open-Edge {
    Write-Host "`nOpening Edge in Private Mode..." -ForegroundColor Green
    Start-Process "msedge" -ArgumentList "-inprivate https://en.key-test.ru/"
    Get-SystemInfo 
}

function Open-DeviceManager {
    Write-Host "`nOpening Device Manager..." -ForegroundColor Green
    Start-Process "devmgmt.msc"
    Get-SystemInfo 
}

function Restart-WindowsUpdateAndCleanCache {
    Write-Host "`nRestarting Windows Update and Cleaning Cache..." -ForegroundColor Green
    # Restart Windows Update Services
    Stop-Service -Name wuauserv -Force
    Start-Service -Name wuauserv
    Write-Host "Windows Update service restarted."

    # Clean Temporary Files
    $TempPath = "$env:Temp"
    Remove-Item -Path "$TempPath\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Temporary files cleaned."
    
    Get-SystemInfo
}
function Configure-PowerSettings {
    Write-Host "`nConfiguring Power Settings..." -ForegroundColor Green

    # Turn off Fast Startup
    Write-Host "Turning off Fast Startup..."
    PowerCfg -H off
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0
    Write-Host "Fast Startup turned off."

    # Set "Turn off display" and "Put the computer to sleep" to "Never"
    Write-Host "Configuring Power Plan Settings..."
    $ActiveScheme = (powercfg -getactivescheme).Trim() -replace ".*:\s*"
    
    powercfg -change -monitor-timeout-ac 0
    powercfg -change -monitor-timeout-dc 0
    powercfg -change -standby-timeout-ac 0
    powercfg -change -standby-timeout-dc 0
    Write-Host "Display and Sleep settings set to 'Never'."

    # Set the screen saver to Blank after 5 minutes
    Write-Host "Configuring Screen Saver..."
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "ScreenSaveActive" -Value "1"
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "ScreenSaveTimeOut" -Value "300"  # 300 seconds = 5 minutes
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "SCRNSAVE.EXE" -Value "C:\Windows\System32\scrnsave.scr"
    Write-Host "Screen saver set to 'Blank' after 5 minutes."
    
    Get-SystemInfo
}
function Run-ActivationScript {
    Write-Host "`nRunning Activation Script..." -ForegroundColor Green
    try {
        irm https://get.activated.win | iex
        Write-Host "Activation script executed successfully." -ForegroundColor Cyan
    } catch {
        Write-Host "An error occurred while executing the activation script: $_" -ForegroundColor Red
    }
    Get-SystemInfo
}

function KeyPressOption {
    param ([ConsoleKeyInfo]$Key)
    switch ($Key.KeyChar) {
        "1" { Get-SystemInfo }
        "2" { Open-Camera }
        "3" { Open-Edge }
        "4" { Open-DeviceManager }
        "5" { Restart-WindowsUpdateAndCleanCache }
        "6" { Configure-PowerSettings }
        "7" { Run-ActivationScript }
        "8" { exit }
        default { return }
    }
}

Get-SystemInfo

while ($true) {
    Write-Host "`nChoose an option - 8 to EXIT:" -ForegroundColor Yellow
    Write-Host "1. Refresh System Information"
    Write-Host "2. Open Camera"
    Write-Host "3. Keyboard Test"
    Write-Host "4. Device Manager"
    Write-Host "5. Restart Windows Update and Clean Cache"
    Write-Host "6. Configure Power Settings"
    Write-Host "7. Activation Script"
    Write-Host "8. Exit"

    do {
        $key = [System.Console]::ReadKey($true)
    } while (-not ($key.KeyChar -match '^[1-8]$'))
    
    KeyPressOption $key
}