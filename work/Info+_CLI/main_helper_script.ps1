$global:SystemInfoData = $null
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsFormsIntegration
Add-Type -AssemblyName System.Windows.Forms
$host.UI.RawUI.WindowTitle = "Info+"
if ($PSScriptRoot) {
    . "$PSScriptRoot\CustomMessageBox.ps1"
    . "$PSScriptRoot\DriversTest.ps1"
    . "$PSScriptRoot\AudioTest.ps1"
    . "$PSScriptRoot\CommandHelpers.ps1"
    . "$PSScriptRoot\GetSystemInfo.ps1"
    . "$PSScriptRoot\TweaksSystem.ps1"
    . "$PSScriptRoot\InstallDependencies.ps1"
} else {
    . "./CustomMessageBox.ps1"
    . "./DriversTest.ps1"
    . "./AudioTest.ps1"
    . "./CommandHelpers.ps1"
    . "./GetSystemInfo.ps1"
    . "./TweaksSystem.ps1"
    . "./InstallDependencies.ps1"
}



# Running the activation script
function Start-ActivationScript {
    Start-Command -Command "irm https://get.activated.win | iex"
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
    Clear-Host
    $global:SystemInfoData = Get-SystemInfo
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
    $data.BatteryInfo  | Format-Table -AutoSize
    Write-Host " "

    Write-Host "| Total Physical Memory      | $($data.MemoryInfo) GB            "
    Write-Host "| CPU                        |" -NoNewline; Write-Host " $($data.CPUInfo)" -ForegroundColor $data.CPUColor
    Write-Host "| GPU                        |" -NoNewline; Write-Host " $($data.GPUInfo)" -ForegroundColor $data.GPUColor
    Write-Host "| Windows Version            | $($data.WindowsStatus)           "
    Write-Host "| Activation Status          |" -NoNewline; Write-Host " $($data.ActivationStatus)" -ForegroundColor $data.ActivationColor
    
}
Start-Files
Show-YouTubeIframe
function KeyPressOption {
    param ([ConsoleKeyInfo]$Key)
    switch ($Key.KeyChar) {
        "1" { Show-SystemInfo }
        "2" { Show-DriverPage }
        "3" { Start-Files }
        "4" { Clear-SystemCache }
        "5" { Use-ConfigurePowerSettings }
        "6" { Start-ActivationScript }
        "7" { Start-MemoryDiagnosticWithTask }
        "0" { exit }
        default { return }
    }
}

while ($true) {
    Show-SystemInfo
    Write-Host "`nChoose an option - 8 to EXIT:" -ForegroundColor Yellow
    Write-Host "1. Refresh System Information"
    Write-Host "2. Drivers Links"
    Write-Host "3. Keyboard Test"
    Write-Host "4. Cache Clean"
    Write-Host "5. TWEAK - Display Not coming back when Suspended "
    Write-Host "6. Microsoft Activation Helper"
    Write-Host "7. Test Memory Windows - Restart Required"
    Write-Host "0. Exit"
    Write-Host " "
    do {
        $key = [System.Console]::ReadKey($true)
    } while (-not ($key.KeyChar -match '^[0-7]$'))

    KeyPressOption $key
}

