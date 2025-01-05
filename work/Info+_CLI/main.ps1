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

function Show-DisplayMenu {
    Write-Host "`nChoose an option - 0 to EXIT:" -ForegroundColor Yellow
    Write-Host "1. Refresh System Information"
    Write-Host "2. Drivers Links"
    Write-Host "3. Keyboard Test"
    Write-Host "4. Cache Clean"
    Write-Host "5. TWEAK - Display Not coming back when Suspended"
    Write-Host "6. Microsoft Activation Helper"
    Write-Host "7. Test Memory Windows - Restart Required"
    Write-Host "8. Register OEM Key"
    Write-Host "0. Exit"
    Write-Host " "
}
Show-DisplayMenu
function KeyPressOption {
    param ([ConsoleKeyInfo]$Key)
    switch ($Key.KeyChar) {
        "1" { 
            Show-SystemInfo
            Show-DisplayMenu 
            Write-Host "`nOption 1 executed: System Information refreshed." -ForegroundColor Green
        }
        "2" { 
            Show-DriverPage 
            Write-Host "`nOption 2 executed: Drivers Links displayed." -ForegroundColor Green
        }
        "3" { 
            Start-Files 
            Write-Host "`nOption 3 executed: Keyboard Test started." -ForegroundColor Green
        }
        "4" { 
            Clear-SystemCache 
            Write-Host "`nOption 4 executed: Cache cleared." -ForegroundColor Green
        }
        "5" { 
            Use-ConfigurePowerSettings 
            Write-Host "`nOption 5 executed: Power settings configured." -ForegroundColor Green
        }
        "6" { 
            Start-ActivationScript 
            Write-Host "`nOption 6 executed: Activation script started." -ForegroundColor Green
        }
        "7" { 
            Start-MemoryDiagnosticWithTask 
            Write-Host "`nOption 7 executed: Memory diagnostic started. System may restart." -ForegroundColor Green
        }
        "8" {
            $response = Show-CustomMessageBox -Message "Do you want to register OEM Key?" `
            -Title "Confirmation" `
            -ButtonLayout "YesNo" 
            
            if ($response -eq "Yes") {
                Register-OEMKey
                Write-Host "`nOption 8 executed: Starting to Register OEM key to System." -ForegroundColor Green
            }else {
                Write-Host "Operation cancelled by user." -ForegroundColor Red
            }
        }
        "0" { 
            Write-Host "`nExiting the program. Goodbye!" -ForegroundColor Red
            exit 
        }
    }
}


# Loop to handle user input
while ($true) {
    $key = [System.Console]::ReadKey($true)

    if ($key.KeyChar -match '^[0-7]$') {
        KeyPressOption $key
        # Re-display the menu after handling the choice
    }
}