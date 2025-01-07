$global:SystemInfoData = $null
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsFormsIntegration
Add-Type -AssemblyName System.Windows.Forms
$host.UI.RawUI.WindowTitle = "Info+" # Set the title of the console window
if ($PSScriptRoot) {
    # Load dependent scripts from the current directory during development
    . "$PSScriptRoot\CustomMessageBox.ps1"
    . "$PSScriptRoot\DriversTest.ps1"
    . "$PSScriptRoot\AudioTest.ps1"
    . "$PSScriptRoot\CommandHelpers.ps1"
    . "$PSScriptRoot\GetSystemInfo.ps1"
    . "$PSScriptRoot\TweaksSystem.ps1"
}else {
    . "./CustomMessageBox.ps1"
    . "./DriversTest.ps1"
    . "./AudioTest.ps1"
    . "./CommandHelpers.ps1"
    . "./GetSystemInfo.ps1"
    . "./TweaksSystem.ps1"
}

# Running memtest Windows Built in and create task to dispaly data after boot
function Start-MemoryDiagnosticWithTask {
    try {
        # Step 1: Start the Memory Diagnostic Tool
        Start-Process -FilePath "mdsched.exe"
        Write-Host "Memory Diagnostic Tool started successfully. The system will restart." -ForegroundColor Green
    } catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
    }
}


function Show-SystemInfo {    
    param (
    [string]$Command = "default"  # Accepts 'update' as a parameter
    )
    Clear-Host

    # If 'update' parameter is passed, update the global data
    if ($Command -eq "update") {
        Write-Host "Checking for updates to System Information..." -ForegroundColor Yellow
        $newData = Get-SystemInfo

        if ($global:SystemInfoData -and ($global:SystemInfoData | ConvertTo-Json -Depth 10) -eq ($newData | ConvertTo-Json -Depth 10)) {
            Write-Host "No changes detected in System Information." -ForegroundColor Cyan
        } else {
            Write-Host "Updating System Information..." -ForegroundColor Green
            $global:SystemInfoData = $newData
        }
    }
    Clear-Host

    # If the global variable is not initialized, fetch system info
    if (-not $global:SystemInfoData) {
        $global:SystemInfoData = Get-SystemInfo
    }
    Clear-Host
    # Explicitly reference $global:SystemInfoData
    $data = $global:SystemInfoData
    Write-Host "=========================================================" -ForegroundColor Green
    Write-Host "       2024 Developed with " -ForegroundColor White -NoNewline
    Write-Host ([char]0x2665) -ForegroundColor Red -NoNewline
    Write-Host " by" -NoNewline
    Write-Host " Vunf1" -ForegroundColor Green -NoNewline
    Write-Host " for " -NoNewline
    Write-Host "HardStock" -ForegroundColor Cyan    
    Write-Host "=========================================================" -ForegroundColor Green
    Write-Host "`nSystem Information:" -ForegroundColor Cyan

    $data.DiskInfo  | Format-Table -AutoSize
    Write-Host " "
    #$data.BatteryInfo  | Format-Table -AutoSize
    Write-Host " "

    Write-Host "| Total Physical Memory      | $($data.MemoryInfo) GB            "
    Write-Host "| CPU                        |" -NoNewline; Write-Host " $($data.CPUInfo)" -ForegroundColor $data.CPUColor
    Write-Host "| GPU                        |" -NoNewline; Write-Host " $($data.GPUInfo)" -ForegroundColor $data.GPUColor
    Write-Host "| Windows Version            | $($data.WindowsStatus)           "
    Write-Host "| Activation Status          |" -NoNewline; Write-Host " $($data.ActivationStatus)" -ForegroundColor $data.ActivationColor
    Write-Host " "
    
    $productKeys = $data.ProductKeys
    Write-Host "| Installed Product Key      |" -NoNewline
    Write-Host " $($productKeys.InstalledKey)" -ForegroundColor $productKeys.InstalledKeyColor

    Write-Host "| OEM Product Key            |" -NoNewline
    Write-Host " $($productKeys.OEMKey)" -ForegroundColor $productKeys.OEMKeyColor
    Write-Host " "

}
Clear-Host
Start-Files
Get-CameraAndOpenApp
Show-YouTubeIframe
Show-SystemInfo
# Main Menu
function Show-MainMenu {
    Write-Host "`nMain Menu - Choose an option (0 to EXIT):" -ForegroundColor Yellow
    Write-Host "1. System Information & Tweaks"
    Write-Host "2. Drivers and Tools"
    Write-Host "3. System Maintenance"
    Write-Host "0. Exit"
    Write-Host " "
}

function MainMenuOption {
    param ([ConsoleKeyInfo]$Key)
    switch ($Key.KeyChar) {
        "1" { Show-SystemInfoSubmenu }
        "2" { Show-DriversToolsSubmenu }
        "3" { Show-MaintenanceSubmenu }
        "0" { 
            Write-Host "`nExiting the program. Goodbye!" -ForegroundColor Red
            exit
        }
    }
}

# System Information & Tweaks Menu
function Show-SystemInfoMenu {
    Clear-Host
    Show-SystemInfo
    Write-Host "`nSystem Information & Tweaks - Choose an option:" -ForegroundColor Yellow
    Write-Host "1. Refresh System Information"
    Write-Host "2. TWEAK - Display Not coming back when Suspended"
    Write-Host "3. Microsoft Activation Helper"
    Write-Host "4. Register OEM Key"
    Write-Host "0. Back to Main Menu"
    Write-Host " "
}

function SystemInfoOption {
    param ([ConsoleKeyInfo]$Key)
    switch ($Key.KeyChar) {
        "1" {
            Write-Host "`nRefreshing System Information..." -ForegroundColor Green
            Show-SystemInfo -Command "update"
        }
        "2" {
            Write-Host "`nConfiguring Display Power Settings..." -ForegroundColor Green
            Use-ConfigurePowerSettings
        }
        "3" {
            Write-Host "`nStarting Activation Helper..." -ForegroundColor Green
            if (Get-Command Start-ActivationScript -ErrorAction SilentlyContinue) {
                Write-Host "Start-ActivationScript recognized."
            } else {
                Write-Host "Start-ActivationScript not recognized." -ForegroundColor Red
            }
            Start-ActivationScript
        }
        "4" {
            Write-Host "`nRegistering OEM Key..." -ForegroundColor Green
            Register-OEMKey
        }
        "0" {
            Clear-Host
            Show-SystemInfo
             return }
    }
}

function Show-SystemInfoSubmenu {
    while ($true) {
        Show-SystemInfoMenu
        $key = [System.Console]::ReadKey($true)
        if ($key.KeyChar -match '^[0-4]$') {
            SystemInfoOption $key
            if ($key.KeyChar -eq "0") { break }
        }
    }
}

# Drivers and Tools Menu
function Show-DriversToolsMenu {
    Clear-Host
    Show-SystemInfo
    Write-Host "`nDrivers and Tools - Choose an option:" -ForegroundColor Yellow
    Write-Host "1. Drivers Links"
    Write-Host "2. Keyboard Test"
    Write-Host "3. Battery Test"
    Write-Host "4. Audio Test"
    Write-Host "0. Back to Main Menu"
    Write-Host " "
}

function DriversToolsOption {
    param ([ConsoleKeyInfo]$Key)
    switch ($Key.KeyChar) {
        "1" {
            Write-Host "`nDisplaying Drivers Links..." -ForegroundColor Green
            Show-DriverPage
        }
        "2" {
            Write-Host "`nStarting Keyboard Test..." -ForegroundColor Green
            Open-Executable -Key "Keyboard"
        }
        "3" {
            Write-Host "`nStarting Battery Test..." -ForegroundColor Green
            Open-Executable -Key "Battery"
        }
        "4" {
            Write-Host "`nStarting Audio Test..." -ForegroundColor Green
            Show-YouTubeIframe
        }
        "0" { 
            Clear-Host
            Show-SystemInfo
            return }
    }
}

function Show-DriversToolsSubmenu {
    while ($true) {
        Show-DriversToolsMenu
        $key = [System.Console]::ReadKey($true)
        if ($key.KeyChar -match '^[0-4]$') {
            DriversToolsOption $key
            if ($key.KeyChar -eq "0") { break }
        }
    }
}

# System Maintenance Menu
function Show-MaintenanceMenu {
    Clear-Host
    Show-SystemInfo
    Write-Host "`nSystem Maintenance - Choose an option:" -ForegroundColor Yellow
    Write-Host "1. Cache Clean"
    Write-Host "2. Test Memory Windows - Restart Required"
    Write-Host "0. Back to Main Menu"
    Write-Host " "
}

function MaintenanceOption {
    param ([ConsoleKeyInfo]$Key)
    switch ($Key.KeyChar) {
        "1" {
            Write-Host "`nClearing Cache..." -ForegroundColor Green
            Clear-SystemCache
        }
        "2" {
            Write-Host "`nStarting Memory Diagnostic..." -ForegroundColor Green
            Start-MemoryDiagnosticWithTask
        }
        "0" { 
            Clear-Host
            Show-SystemInfo
            return }
    }
}

function Show-MaintenanceSubmenu {
    while ($true) {
        Show-MaintenanceMenu
        $key = [System.Console]::ReadKey($true)
        if ($key.KeyChar -match '^[0-2]$') {
            MaintenanceOption $key
            if ($key.KeyChar -eq "0") { break }
        }
    }
}


# Main Loop
while ($true) {
    Show-MainMenu
    $key = [System.Console]::ReadKey($true)
    if ($key.KeyChar -match '^[0-3]$') {
        MainMenuOption $key
    }
}
