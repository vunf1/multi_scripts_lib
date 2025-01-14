$global:SystemInfoData = $null
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsFormsIntegration
Add-Type -AssemblyName System.Windows.Forms
$host.UI.RawUI.WindowTitle = "Info+"
#$host.UI.RawUI.BufferSize = New-Object -TypeName System.Management.Automation.Host.Size(1, 10)
$host.UI.RawUI.BackgroundColor = "Black"
<# if ($PSScriptRoot) {
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
} #>

function Start-MemoryDiagnosticWithTask {
    try {
        Start-Process -FilePath "mdsched.exe"
        Write-Host "Memory Diagnostic Tool started successfully. The system will restart." -ForegroundColor Green
    } catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
    }
}


function Show-SystemInfo {    
    param (
        [string]$Command = "default" 
    )

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

    # Fetch SystemInfo if not initialized
    if (-not $global:SystemInfoData) {
        $global:SystemInfoData = Get-SystemInfo
    }
    $data = $global:SystemInfoData
    Clear-Host

    Write-Host "=========================================================" -ForegroundColor Green
    Write-Host "       Developed with " -ForegroundColor White -NoNewline; Write-Host ([char]0x2665) -ForegroundColor Red -NoNewline
    Write-Host " by" -NoNewline; Write-Host " Vunf1" -ForegroundColor Green -NoNewline; Write-Host " for " -NoNewline; Write-Host "HardStock" -ForegroundColor Cyan    
    Write-Host "=========================================================" -ForegroundColor Green
    Write-Host "`nSystem Information:" -ForegroundColor Cyan

    # Disk Info as a Table
    if ($data.'Disk Info' -and $data.'Disk Info'.Count -gt 0) {
        $data.'Disk Info' | Format-Table `
            @{ Label = "Drive"; Expression = { $_.DriveLetter } }, `
            @{ Label = "Disk Name"; Expression = { $_.DiskName } }, `
            @{ Label = "Total Size (GB)"; Expression = { $_.TotalSizeGB } }, `
            @{ Label = "Used Size (GB)"; Expression = { $_.UsedSizeGB } } -AutoSize
    } else {
        Write-Host "No Disk Information Available" -ForegroundColor Red
    }
    
    Write-Host " ------------------------------------|------------------------------------------- "
    Write-Host "| RAM Information                    | Slot Information                          |"
    Write-Host " ------------------------------------|------------------------------------------- "
    
    # Prepare RAM Info Lines
    $ramInfoLines = @(
        ("| Total Memory         {0,-12} " -f $data.'Memory Info'.TotalMemory),
        ("| Total Slots          {0,-12} " -f $data.'Memory Info'.TotalSlots),
        ("| Used Slots           {0,-12} " -f $data.'Memory Info'.UsedSlots),
        ("| Onboard Memory       {0,-12} " -f $data.'Memory Info'.OnboardMemory),
        ("| Onb Mem Size         {0,-12} " -f $data.'Memory Info'.OnboardSize)
    )
    
    # Prepare Slot Details Lines
    $slotDetailsLines = $data.'Memory Info'.SlotDetails | ForEach-Object {
        "| {0,-10} {1,-8} {2,-8} {3,-12} " -f $_.Slot, $_.Size, $_.Architecture, $_.Speed
    }
    
    # Ensure Both Sections Have Equal Lines
    $maxLines = [math]::Max($ramInfoLines.Count, $slotDetailsLines.Count)
    $ramInfoLines += ("|                            |" * ($maxLines - $ramInfoLines.Count))
    $slotDetailsLines += ("|                                           |" * ($maxLines - $slotDetailsLines.Count))
    
    # Combine and Output the Table
    for ($i = 0; $i -lt $maxLines; $i++) {
        Write-Host "$($ramInfoLines[$i]) $($slotDetailsLines[$i])"
    }
    
    Write-Host "|------------------------------------|-------------------------------------------"

    # CPU Info
    if ($data.'Processor Info'.Info -is [PSCustomObject]) {
        $cpuColor = if ($data.'Processor Info'.Color -and [Enum]::IsDefined([System.ConsoleColor], $data.'Processor Info'.Color)) { 
            $data.'Processor Info'.Color 
        } else { "Gray" }

        # Iterate over each processor and display its details
        $first = $true
        foreach ($cpu in $data.'Processor Info'.Info) {
            if ($first) {
                # Write the first CPU entry after the "| CPU                        |"
                Write-Host "| CPU                        " -NoNewline
                Write-Host " $($cpu.Name) $($cpu.MaxClockSpeed) $($cpu.Cores) $($cpu.LogicalProcessors) $($cpu.Socket)" -ForegroundColor $cpuColor
                $first = $false
            } else {
                # Align additional CPU entries
                Write-Host "                              $($cpu.Name) $($cpu.MaxClockSpeed) $($cpu.Cores) $($cpu.LogicalProcessors)  $($cpu.Socket)" -ForegroundColor $cpuColor
            }
        }
    } else {
        Write-Host "| CPU                        No CPU information available" -ForegroundColor Red
    }

    # GPU Info Display
    if ($data.'GPU Info'.GPUs -and $data.'GPU Info'.GPUs.Count -gt 0) {
        $first = $true
        foreach ($gpu in $data.'GPU Info'.GPUs) {
            $gpuColor = if ($gpu.Color -and [Enum]::IsDefined([System.ConsoleColor], $gpu.Color)) { 
                $gpu.Color 
            } else { "Gray" }

            if ($first) {
                # Write the first GPU entry after the "| GPU                        |"
                Write-Host "| GPU                        " -NoNewline; Write-Host " $($gpu.Name) ($($gpu.Dedicated))" -ForegroundColor $gpuColor
                $first = $false
            } else {
                # Indent additional GPU entries to align with the first one
                Write-Host "                              $($gpu.Name) ($($gpu.Dedicated))" -ForegroundColor $gpuColor
            }
        }
    } else {
        Write-Host "| GPU                        No GPU information available" -ForegroundColor Red
    }





    # Windows Version
    Write-Host "| Windows Version             $($data.'Windows Version')"

    # Activation Status
    $activationColor = if ($data.'Activation Details'.ActivationColor -and [Enum]::IsDefined([System.ConsoleColor], $data.'Activation Details'.ActivationColor)) { 
        $data.'Activation Details'.ActivationColor 
    } else { "Gray" }
    Write-Host "| Activation Status          " -NoNewline
    Write-Host " $($data.'Activation Details'.Status)" -ForegroundColor $activationColor

    # Product Keys
    $productKeys = $data.'System Product Keys'
    $installedKeyColor = if ($productKeys.InstalledKeyColor -and [Enum]::IsDefined([System.ConsoleColor], $productKeys.InstalledKeyColor)) { 
        $productKeys.InstalledKeyColor 
    } else { "Gray" }
    Write-Host "| Installed Product Key      " -NoNewline
    Write-Host " $($productKeys.InstalledKey)" -ForegroundColor $installedKeyColor

    $oemKeyColor = if ($productKeys.OEMKeyColor -and [Enum]::IsDefined([System.ConsoleColor], $productKeys.OEMKeyColor)) { 
        $productKeys.OEMKeyColor 
    } else { "Gray" }
    Write-Host "| OEM Product Key            " -NoNewline
    Write-Host " $($productKeys.OEMKey)" -ForegroundColor $oemKeyColor

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
        
        # Flush input buffer by reading all available characters
        while ([System.Console]::KeyAvailable) {
            [System.Console]::ReadKey($true) | Out-Null
        }

        do {
            $key = [System.Console]::ReadKey($true)
        } while (-not ($key.KeyChar -match '^[0-4]$'))  # Only accept valid input

        SystemInfoOption $key
        if ($key.KeyChar -eq "0") { break }
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
        
        while ([System.Console]::KeyAvailable) {
            [System.Console]::ReadKey($true) | Out-Null
        }

        do {
            $key = [System.Console]::ReadKey($true)
        } while (-not ($key.KeyChar -match '^[0-4]$'))

        DriversToolsOption $key
        if ($key.KeyChar -eq "0") { break }
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
        
        while ([System.Console]::KeyAvailable) {
            [System.Console]::ReadKey($true) | Out-Null
        }

        do {
            $key = [System.Console]::ReadKey($true)
        } while (-not ($key.KeyChar -match '^[0-2]$'))

        MaintenanceOption $key
        if ($key.KeyChar -eq "0") { break }
    }
}

# Main Loop
while ($true) {
    Show-MainMenu

    # Flush input buffer by reading all available characters
    while ([System.Console]::KeyAvailable) {
        [System.Console]::ReadKey($true) | Out-Null
    }

    # Read valid input
    do {
        $key = [System.Console]::ReadKey($true)
    } while (-not ($key.KeyChar -match '^[0-3]$'))

    MainMenuOption $key
}