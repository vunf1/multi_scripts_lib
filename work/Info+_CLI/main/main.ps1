
$global:SystemInfoData = $null

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
    if(-not $Debug){
        Clear-Host
    }
    Write-Host "=========================================================" -ForegroundColor Green

    Write-Host "       Developed with " -ForegroundColor White -NoNewline
    Write-Host ([char]0x2665) -ForegroundColor Red -NoNewline 
    Write-Host " by " -ForegroundColor White -NoNewline
    Write-Host "Vunf1" -ForegroundColor Green -NoNewline
    Write-Host " for " -ForegroundColor White -NoNewline
    Write-Host "HardStock" -ForegroundColor Cyan    
    
    Write-Host "=========================================================" -ForegroundColor Green
    Write-Host "`n"
    Write-Host "`n"
    Write-Host "`n"


    Write-Host "`n$unicodeEmojiMagnifyingGlass System Information:" -ForegroundColor Cyan
    Write-Host " -----------------------------------|------------------------------------------- " -ForegroundColor White
    Write-Host " | $unicodeEmojiLightBulb RAM Information               | $unicodeEmojiComputer Slot Information                      |" -ForegroundColor Cyan
    Write-Host " -----------------------------------|------------------------------------------- " -ForegroundColor White
    
    # Prepare RAM Info Lines
    $ramInfoLines = @(
        ("| Total Memory         {0,-12}" -f $data.'Memory Info'.TotalMemoryGB),
        ("| Total Slots          {0,-12}" -f $data.'Memory Info'.TotalSlots),
        ("| Used Slots           {0,-12}" -f $data.'Memory Info'.UsedSlots),
        ("| Available Slots      {0,-12}" -f $data.'Memory Info'.AvailableSlots),
        ("| Onboard Memory       {0,-12}" -f $data.'Memory Info'.OnboardMemory),
        ("| Onboard Mem Size     {0,-12}" -f $data.'Memory Info'.OnboardSizeGB)
    )
    
    # Prepare Slot Details Lines
    $slotDetailsLines = $data.'Memory Info'.SlotDetails | ForEach-Object {
        "| {0,-10} {1,-10} {2,-12} {3,-12}" -f $_.Slot, $_.Size, $_.Type, $_.Speed
    }
    
    # Ensure Both Sections Have Equal Lines by appending blank lines as needed.
    $maxLines = [math]::Max($ramInfoLines.Count, $slotDetailsLines.Count)
    
    if ($ramInfoLines.Count -lt $maxLines) {
        $ramInfoLines += (1..($maxLines - $ramInfoLines.Count) | ForEach-Object { "                              " })
    }
    
    if ($slotDetailsLines.Count -lt $maxLines) {
        $slotDetailsLines += (1..($maxLines - $slotDetailsLines.Count) | ForEach-Object { "                                             " })
    }
    
    # Combine and Output the Table
    for ($i = 0; $i -lt $maxLines; $i++) {
        Write-Host "$($ramInfoLines[$i]) $($slotDetailsLines[$i])"
    }
    
    Write-Host "|-----------------------------------|-------------------------------------------"
    # CPU Info Display
    if ($data.'Processor Info'.Info) {
        $cpuArray = @($data.'Processor Info'.Info)
        $cpuColor = if ($data.'Processor Info'.Color -and [Enum]::IsDefined([System.ConsoleColor], $data.'Processor Info'.Color)) {
                        $data.'Processor Info'.Color 
                    } else {
                        "Gray"
                    }

        $first = $true
        foreach ($cpu in $cpuArray) {
            if ($first) {
                # Write header and the first CPU entry.
                Write-Host "$unicodeEmojiCPU CPU                        " -NoNewline
                Write-Host " $($cpu.Name) $($cpu.MaxClockSpeed) $($cpu.Cores) $($cpu.LogicalProcessors) $($cpu.Socket)" -ForegroundColor $cpuColor
                $first = $false
            }
            else {
                # Align additional CPU entries.
                Write-Host "                              " -NoNewline
                Write-Host " $($cpu.Name) $($cpu.MaxClockSpeed) $($cpu.Cores) $($cpu.LogicalProcessors) $($cpu.Socket)" -ForegroundColor $cpuColor
            }
        }
    }
    else {
        Write-Host "$unicodeEmojiCPU CPU                        No CPU information available" -ForegroundColor Red
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
                Write-Host "$unicodeEmojiChip GPU                        " -NoNewline; Write-Host " $($gpu.Name) ($($gpu.Dedicated))" -ForegroundColor $gpuColor
                $first = $false
            } else {
                # Indent additional GPU entries to align with the first one
                Write-Host "                              $($gpu.Name) ($($gpu.Dedicated))" -ForegroundColor $gpuColor
            }
        }
    } else {
        Write-Host "$unicodeEmojiChip GPU                        No GPU information available" -ForegroundColor Red
    }

    # Windows Version
    Write-Host "$unicodeEmojiBug Windows Version             $($data.'Windows Version')"

    # Activation Status
    if ($data.'Activation Details') {
        $activationArray = @($data.'Activation Details')
        $first = $true
        foreach ($act in $activationArray) {
            $actColor = if ($act.ActivationColor -and [Enum]::IsDefined([System.ConsoleColor], $act.ActivationColor)) { 
                $act.ActivationColor 
            } else { "Gray" }
            
            if ($first) {
                Write-Host "$unicodeEmojiNetwork Activation Status         " -NoNewline
                Write-Host "  $($act.Status)" -ForegroundColor $actColor
                $first = $false
            }
            else {
                Write-Host "                                  " -NoNewline
                Write-Host " $($act.Status)" -ForegroundColor $actColor
            }
        }
    }
    else {
        Write-Host "$unicodeEmojiNetwork Activation Status         No Activation information available" -ForegroundColor Red
    }
    # Product Keys
    $productKeys = $data.'System Product Keys'

    # Installed Product Key
    if ($productKeys.InstalledKey -and $productKeys.InstalledKey.Value) {
        $installedKeyColor = if ($productKeys.InstalledKey.Color -and [Enum]::IsDefined([System.ConsoleColor], $productKeys.InstalledKey.Color)) { 
            $productKeys.InstalledKey.Color 
        } else { "Gray" }

        Write-Host "$unicodeEmojiStorage Installed Product Key      " -NoNewline
        Write-Host " $($productKeys.InstalledKey.Value)" -ForegroundColor $installedKeyColor
    } else {
        Write-Host "$unicodeEmojiStorage Installed Product Key      Not Found" -ForegroundColor Red
    }

    # OEM Product Key
    if ($productKeys.OEMKey -and $productKeys.OEMKey.Value) {
        $oemKeyColor = if ($productKeys.OEMKey.Color -and [Enum]::IsDefined([System.ConsoleColor], $productKeys.OEMKey.Color)) { 
            $productKeys.OEMKey.Color 
        } else { "Gray" }

        Write-Host "$unicodeEmojiStorage OEM Product Key            " -NoNewline
        Write-Host " $($productKeys.OEMKey.Value)" -ForegroundColor $oemKeyColor
    } else {
        Write-Host "$unicodeEmojiStorage OEM Product Key            Not Found" -ForegroundColor Red
    }

}

if(-not $Debug){
    Clear-Host
}

Start-Files
Start-CameraAppInBackground
Show-YouTubeIframe
Show-SystemInfo
# Main Menu
function Show-MainMenu {
    Write-Host "`nMain Menu - Choose an option (0 to EXIT):" -ForegroundColor Yellow
    Write-Host "$unicodeEmojiFullwidthOne - System Information & Tweaks (1)"
    Write-Host "$unicodeEmojiFullwidthTwo - Drivers and Tests (2)"
    Write-Host "$unicodeEmojiFullwidthThree - System Maintenance (3)"
    Write-Host "$unicodeEmojiFullwidthZero - Exit (0)"
    Write-Host " "
}


function MainMenuOption {
    param ([ConsoleKeyInfo]$Key)
    switch ($Key.KeyChar) {
        "1" { Show-SystemInfoSubmenu }
        "2" { Show-DriversToolsSubmenu }
        "3" { Show-MaintenanceSubmenu }
        "0" { 
            Write-Host "`n $unicodeEmojiFan  Exiting the program. Goodbye! $unicodeEmojiFan" -ForegroundColor Red
            $global:exitProgram = $true
            if(-not $Local){
                [System.Environment]::Exit(0) # Forcefully terminate the current console

            }
        }
    }
}

# System Information & Tweaks Menu
function Show-SystemInfoMenu {
    if(-not $Debug){
        Clear-Host
    }
    Show-SystemInfo
    Write-Host "`nSystem Information & Tweaks - Choose an option:" -ForegroundColor Yellow
    Write-Host "1 - Refresh System Information"
    Write-Host "2 - TWEAK - Display Not coming back when Suspended"
    Write-Host "3 - Microsoft Activation Helper"
    Write-Host "4 - Register OEM Key"
    Write-Host "5 - Disable/Unlock Bitlocker (Documents)"
    Write-Host "0 - Back to Main Menu"
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
            Start-ActivationScript
        }
        "4" {
            Write-Host "`nRegistering OEM Key..." -ForegroundColor Green
            Register-OEMKey
            Start-Sleep -Seconds 2
            Show-SystemInfo -Command "update"
        }
        "5" {
            Write-Host "`nDisabling/Unlocking Bitlocker..." -ForegroundColor Green
            Disable-BitLockerOnAllDrives
        }
        "0" {
            if(-not $Debug){
                Clear-Host
            }
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
        } while (-not ($key.KeyChar -match '^[0-5]$'))  # Only accept valid input

        SystemInfoOption $key
        if ($key.KeyChar -eq "0") { break }
    }
}


# Drivers and Tools Menu
function Show-DriversToolsMenu {
    if(-not $Debug){
        Clear-Host
    }
    Show-SystemInfo
    Write-Host "`nDrivers and Tools - Choose an option:" -ForegroundColor Yellow
    Write-Host "1 - Drivers Links"
    Write-Host "2 - Keyboard Test"
    Write-Host "3 - Battery Test"
    Write-Host "4 - Audio Test"
    Write-Host "5 - Stuck Pixel"
    Write-Host "6 - Dead Pixel"
    Write-Host "0 - Back to Main Menu"
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
        "5" {
            Write-Host "`nStarting Stuck Pixel..." -ForegroundColor Green
            Test-StuckPixel
        }
        "6" {
            Write-Host "`nStarting Dead Pixel..." -ForegroundColor Green
            Test-DeadPixel
        }
        "0" { 
            if(-not $Debug){
                Clear-Host
            }
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
        } while (-not ($key.KeyChar -match '^[0-6]$'))

        DriversToolsOption $key
        if ($key.KeyChar -eq "0") { break }
    }
}


# System Maintenance Menu
function Show-MaintenanceMenu {
    if(-not $Debug){
        Clear-Host
    }
    Show-SystemInfo
    Write-Host "`nSystem Maintenance - Choose an option:" -ForegroundColor Yellow
    Write-Host "1 - Cache Clean"
    Write-Host "2 - Test Memory Windows - Restart Required"
    Write-Host "0 - Back to Main Menu"
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
            if(-not $Debug){
                Clear-Host
            }
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
$global:exitProgram = $false # Global flag to exit the program - set to true to exit - make sure program exit correctly
while (-not $global:exitProgram) {
    Show-MainMenu
    # Flush input buffer by reading all available characters
    while ([System.Console]::KeyAvailable) {
        [System.Console]::ReadKey($true) | Out-Null
    }
    do {
        $key = [System.Console]::ReadKey($true)
    } while (-not ($key.KeyChar -match '^[0-3]$'))  # Only accept valid input

    MainMenuOption $key
}