
<# if ($PSScriptRoot) {
    # Load dependent scripts from the current directory during development
    . "$PSScriptRoot\CommandHelpers.ps1"
}else {
    . "./CommandHelpers.ps1"
} #>

function Get-DiskInfo {
    try {
        # Initialize the result array
        $Disks = @()

        # Retrieve volumes and ensure they're valid
        $volumes = Get-Volume | Where-Object { $null -ne $_.DriveLetter }
        if (-not $volumes -or $volumes.Count -eq 0) {
            Write-Debug "No volumes found or no volumes with drive letters."
            return @([PSCustomObject]@{ DriveLetter = "None"; DiskName = "No Disk Found"; TotalSizeGB = "0 GB"; UsedSizeGB = "0 GB" })
        }

        Write-Debug "Volumes retrieved: $($volumes.Count)"

        # Process each volume
        foreach ($volume in $volumes) {
            $diskName = "Unknown"
            $totalSizeGB = if ($null -ne $volume.Size ) { [math]::round($volume.Size / 1GB, 2) } else { 0 }
            $usedSizeGB = if ($null -ne $volume.Size -and $null -ne $volume.SizeRemaining  ) { [math]::round(($volume.Size - $volume.SizeRemaining) / 1GB, 2) } else { 0 }

            try {
                # Retrieve partition and physical disk details
                $partition = Get-Partition -DriveLetter $volume.DriveLetter -ErrorAction SilentlyContinue
                if ($partition) {
                    $diskNumber = $partition.DiskNumber
                    $physicalDisk = Get-PhysicalDisk | Where-Object { $_.DeviceID -eq $diskNumber }
                    if ($physicalDisk) {
                        $diskName = $physicalDisk.FriendlyName
                    } else {
                        Write-Host "No matching physical disk found for DiskNumber=$diskNumber."
                    }
                } else {
                    Write-Host "No partition found for DriveLetter=$($volume.DriveLetter)."
                }
            } catch {
                Write-Host "Error retrieving disk details for DriveLetter=$($volume.DriveLetter): $_"
            }

            # Fallback: Attempt to retrieve disk data from Win32_LogicalDisk
            if ($diskName -eq "Unknown") {
                try {
                    $logicalDisk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID = '$($volume.DriveLetter):'"
                    if ($logicalDisk) {
                        $diskName = $logicalDisk.VolumeName
                        Write-Host "Fallback used Win32_LogicalDisk for DriveLetter=$($volume.DriveLetter): DiskName=$diskName."
                    }
                } catch {
                    Write-Host "Fallback retrieval using Win32_LogicalDisk failed for DriveLetter=$($volume.DriveLetter): $_"
                }
            }

            # Add the disk details to the result array
            $diskObject = [PSCustomObject]@{
                DriveLetter = $volume.DriveLetter
                DiskName    = $diskName
                TotalSizeGB = "$totalSizeGB GB"
                UsedSizeGB  = "$usedSizeGB GB"
            }
            $Disks += $diskObject
        }

        # Return results or a default object if no valid disks are found
        if ($Disks.Count -gt 0) {
            return $Disks
        } else {
            Write-Host "No valid disks found after processing volumes."
            return @([PSCustomObject]@{ DriveLetter = "None"; DiskName = "No Disk Found"; TotalSizeGB = "0 GB"; UsedSizeGB = "0 GB" })
        }
    } catch {
        Write-Host "An error occurred while retrieving disk information: $_"
        return @([PSCustomObject]@{ DriveLetter = "Error"; DiskName = "Error"; TotalSizeGB = "Error"; UsedSizeGB = "Error" })
    }
}


function Get-TotalSticksRam {
    try {
        # Retrieve total physical memory
        $totalMemory = [math]::round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)

        # Get information about memory slots
        $memoryModules = Get-CimInstance -ClassName Win32_PhysicalMemory
        $totalSlots = (Get-CimInstance -ClassName Win32_PhysicalMemoryArray).MemoryDevices
        $usedSlots = $memoryModules.Count

        # Check for onboard memory
        $onboardMemory = $memoryModules | Where-Object { $_.FormFactor -eq 12 } # FormFactor 12 indicates onboard memory
        $onboardMemorySize = if ($onboardMemory) {
            [math]::round(($onboardMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB, 2)
        } else {
            0
        }

        # Get details for each memory slot
        $slotDetails = $memoryModules | ForEach-Object {
            [PSCustomObject]@{
                Slot          = $_.DeviceLocator
                Size          = if ($_.Capacity) { "$([math]::round($_.Capacity / 1GB, 2)) GB" } else { "Unknown" }
                Architecture  = Get-MemoryTypeName -MemoryType $_.SMBIOSMemoryType
                Speed         = if ($_.Speed) { "$($_.Speed) MHz" } else { "Unknown" }
            }
        }

        # Return the result as a structured object
        return [PSCustomObject]@{
            TotalMemory     = "${totalMemory} GB"
            TotalSlots      = $totalSlots
            UsedSlots       = $usedSlots
            OnboardMemory   = if ($onboardMemory) { "Yes" } else { "No" }
            OnboardSize     = "${onboardMemorySize} GB"
            SlotDetails     = $slotDetails
        }
    } catch {
        Write-Error "An error occurred while retrieving memory information: $_"
        return @([PSCustomObject]@{
            TotalMemory     = "Error"
            TotalSlots      = "Error"
            UsedSlots       = "Error"
            OnboardMemory   = "Error"
            OnboardSize     = "Error"
            SlotDetails     = @([PSCustomObject]@{ Slot = "Error"; Size = "Error"; Architecture = "Error"; Speed = "Error";})
        })
    }
}



function Get-ProcessorInfo {
    try {
        # Fetch processor details using Get-WmiObject
        $processors = Get-WmiObject -Class Win32_Processor | ForEach-Object {
            [PSCustomObject]@{
                Name              = $_.Name.Trim()
                MaxClockSpeed     = "$($_.MaxClockSpeed) MHz"
                Cores             = $_.NumberOfCores
                LogicalProcessors = $_.NumberOfLogicalProcessors
                Socket            = $_.SocketDesignation
            }
        }

        # Determine the color based on the processor brand
        $cpuColor = if ($processors.Name -match "AMD") { "Red" } `
                    elseif ($processors.Name -match "Intel") { "Cyan" } `
                    else { "Blue" }

        return [PSCustomObject]@{
            Info  = $processors
            Color = if ([Enum]::IsDefined([System.ConsoleColor], $cpuColor)) { $cpuColor } else { "Gray" }
        }
    } catch {
        # Handle any errors gracefully
        return [PSCustomObject]@{
            Info  = "Error retrieving processor information"
            Color = "Red"
        }
    }
}

function Get-GPUInfo {
    try {

        $gpus = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue | ForEach-Object {

            $isDedicated = if ($_.AdapterRAM -and $_.AdapterRAM -gt 0) { 
                "Dedicated" 
            } elseif ($_.AdapterCompatibility -match "Intel|AMD") {
                if ($_.Description -match "UHD|Integrated|APU") { 
                    "Integrated" 
                } else { 
                    "Unknown" 
                }
            } else { 
                "Unknown" 
            }
            
            $gpuColor = if ($_.Caption -match "NVIDIA") { 
                "Green" 
            } elseif ($_.Caption -match "AMD") { 
                "Red" 
            } elseif ($_.Caption -match "Intel") { 
                "Cyan" 
            } else { 
                "Gray" 
            }

            [PSCustomObject]@{
                Name       = $_.Caption.Trim()
                Dedicated  = $isDedicated
                Color      = if ([Enum]::IsDefined([System.ConsoleColor], $gpuColor)) { $gpuColor } else { "Gray" }
            }
        }

        # Explicitly ensure $gpus is treated as an array
        $gpus = @($gpus)

        if ($gpus.Count -gt 0) {
            return [PSCustomObject]@{
                GPUs = $gpus
            }
        } else {
            Write-Host "No GPUs detected on this system."
            return [PSCustomObject]@{
                GPUs = @([PSCustomObject]@{ Name = "No GPU Found"; Dedicated = "N/A"; Color = "Gray" })
            }
        }
    } catch {
        return [PSCustomObject]@{
            GPUs = @([PSCustomObject]@{ Name = "Error Retrieving GPU Info"; Dedicated = "N/A"; Color = "Red" })
        }
    }
}

function Get-WindowsVersion {
    return (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
}
function Get-ActivationDetails {
    try {
        $slmgrOutput = cscript /nologo $env:SystemRoot\System32\slmgr.vbs /dli 2>&1 | Out-String

        $activationStatusPattern = "(License Status|Estado da Licen[çc]a|Estado da Ativa[çc][ãa]o):\s*(Licensed|Licenciado)"

        if ($slmgrOutput -match $activationStatusPattern) {
            $status = "Activated"
            $activationColor = "Green"
        } else {
            $status = "Not Activated"
            $activationColor = "Red"
        }

        if ($status -eq "Unknown") {
            Write-Host "Unexpected slmgr output for debug:" -ForegroundColor Yellow
            Write-Host $slmgrOutput
        }

        return [PSCustomObject]@{
            Status          = $status
            ActivationColor = if ([Enum]::IsDefined([System.ConsoleColor], $activationColor)) { $activationColor } else { "Gray" }
        }
    } catch {
        Write-Host "An error occurred while checking activation status: $_" -ForegroundColor Red
        return [PSCustomObject]@{
            Status          = "Unknown"
            ActivationColor = "Red"
        }
    }
}

function Show-WindowsProductKeys {
    try {
        # Function to decode the product key
        function Convert-Key {
            param ([byte[]]$DigitalProductId)
            $keyChars = "BCDFGHJKMPQRTVWXY2346789"
            $decodedKey = ""
            $key = [System.Collections.Generic.List[byte]]::new()
        
            # Initialize the key array from DigitalProductId
            for ($i = 52; $i -ge 52 - 15; $i--) { $key.Add($DigitalProductId[$i]) }
        
            # Decode the key
            for ($i = 0; $i -lt 25; $i++) {
                $current = 0
                for ($j = 14; $j -ge 0; $j--) {
                    $current = ($current * 256) + $key[$j]
                    $key[$j] = [math]::Floor($current / 24)
                    $current = $current % 24
                }
                $decodedKey = $keyChars[$current] + $decodedKey
            }
        
            if ($decodedKey.Length -ne 25) {
                throw "Decoded product key length is invalid: $($decodedKey.Length)"
            }
        
            # Insert dashes for readability (split into groups of 5 characters)
            return ($decodedKey -replace ".{5}", '$&-').TrimEnd('-')
        }

        # Retrieve the installed product key
        $digitalProductId = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).DigitalProductId
        $installedKey = if ($digitalProductId) { Convert-Key -DigitalProductId $digitalProductId } else { "Not Found" }

        # Fallback to WMI query only if necessary
        if ($installedKey -eq "Not Found") {
            try {
                $license = Get-CimInstance -Query "SELECT * FROM SoftwareLicensingProduct WHERE PartialProductKey IS NOT NULL AND LicenseStatus=1" -ErrorAction Stop
                if ($license -and $license.DigitalProductId) {
                    $installedKey = Convert-Key -DigitalProductId $license.DigitalProductId
                }
            } catch {
                $installedKey = "Not Found"
            }   
        }

        # Check if the installed key matches a generic key
        if ($WindowsGenericKeys) {
            $matchedKey = $WindowsGenericKeys | Where-Object { $_.Key -eq $installedKey }
            if ($matchedKey) {
                $installedKey += " (Generic key: $($matchedKey.Edition))"
            }
        }

        # Retrieve the OEM key
        $oemKey = Get-OEMKey
        # Assign colors for display
        $installedKeyColor = if ($installedKey -ne "Not Found") { "Yellow" } else { "Red" }
        $oemKeyColor = if ($oemKey -eq "Not Found") { "Yellow" } elseif ($oemKey -eq "Error") { "Red" } else { "Green" }

        # Validate colors
        $installedKeyColor = if ([Enum]::IsDefined([System.ConsoleColor], $installedKeyColor)) { $installedKeyColor } else { "Red" }
        $oemKeyColor = if ([Enum]::IsDefined([System.ConsoleColor], $oemKeyColor)) { $oemKeyColor } else { "Red" }

        # Return results as a PSCustomObject
        return [PSCustomObject]@{
            InstalledKey      = $installedKey
            InstalledKeyColor = $installedKeyColor
            OEMKey            = $oemKey
            OEMKeyColor       = $oemKeyColor
        }
    } catch {
        Write-Error "An error occurred: $_"
        return [PSCustomObject]@{
            InstalledKey      = "Error"
            InstalledKeyColor = "Red"
            OEMKey            = "Error"
            OEMKeyColor       = "Red"
        }
    }
}
function Get-OEMKey{
    try {
        $oemKey = $null

        # Primary method: Using SoftwareLicensingService class
        try {
            #Write-Host "Attempting to retrieve OEM key using SoftwareLicensingService."
            $oemKey = (Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction Stop).OA3xOriginalProductKey
        } catch {
            Write-Host "SoftwareLicensingService method failed: $_"
        }

        # Fallback 1: Using WMI query
        if (-not $oemKey -or $oemKey -eq "") {
            try {
                #Write-Host "Attempting to retrieve OEM key using WMI query."
                $oemKey = Get-WmiObject -Query "SELECT OA3xOriginalProductKey FROM SoftwareLicensingService" | Select-Object -ExpandProperty OA3xOriginalProductKey
            } catch {
                Write-Host "WMI query method failed: $_"
            }
        }

        # Fallback 2: Registry method
        if (-not $oemKey -or $oemKey -eq "") {
            try {
                #Write-Host "Attempting to retrieve OEM key from registry."
                $oemKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform" -Name "BackupProductKeyDefault" -ErrorAction Stop | Select-Object -ExpandProperty BackupProductKeyDefault
            } catch {
                Write-Host "Registry method failed: $_"
            }
        }

        # Fallback 3: Using slmgr.vbs
        if (-not $oemKey -or $oemKey -eq "") {
            try {
                #Write-Host "Attempting to retrieve OEM key using slmgr.vbs."
                $slmgrOutput = cscript /nologo $env:SystemRoot\System32\slmgr.vbs /dli | Out-String
                $oemKey = ($slmgrOutput -split "`n") -match "OA3xOriginalProductKey" | ForEach-Object { ($_ -split ":")[1].Trim() }
            } catch {
                Write-Host "slmgr.vbs method failed: $_"
            }
        }

        # Validate OEM key or return Not Found
        if (-not $oemKey -or $oemKey -eq "") {
            #Write-Host "OEM key retrieval failed. Returning 'Not Found'."
            return "Not Found"
        } else {
            #Write-Host "OEM key retrieved successfully: $oemKey"
            return $oemKey
        }
    } catch {
        #Write-Host "An unexpected error occurred while retrieving OEM key: $_"
        return "Error"
    }

}
function Start-CameraAppInBackground {
    try {
        # Define the script content as a script block
        $scriptContent = {
            function Get-CameraAndOpenApp {
                try {
                    Write-Host "Checking for camera devices..." -ForegroundColor Yellow
            
                    # Check for camera devices using multiple approaches
                    $cameraDevices = @()
            
                    # 1st check using Win32_PnPEntity
                    $cameraDevices += Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object {
                        $_.Name -match "Camera|Webcam|Imaging Device" -or $_.PNPClass -eq "Image"
                    }
            
                    # 2nd check using Win32_USBHub (for USB-connected cameras)
                    $cameraDevices += Get-CimInstance -ClassName Win32_USBHub -ErrorAction SilentlyContinue | Where-Object {
                        $_.Name -match "Camera|Webcam"
                    }
            
                    # 3rd check using MSFT_PhysicalCamera (specific to integrated cameras)
                    $cameraDevices += Get-CimInstance -Namespace "Root\CIMv2\DeviceMap" -ClassName MSFT_PhysicalCamera -ErrorAction SilentlyContinue | Where-Object {
                        $_.Name -match "Camera|Webcam"
                    }
            
                    # 4th check for Windows Imaging Device interface
                    $cameraDevices += Get-WmiObject -Namespace "Root\CIMv2" -Query "SELECT * FROM Win32_PnPEntity WHERE Service = 'usbvideo'" -ErrorAction SilentlyContinue
            
                    # Remove duplicates and ensure valid results
                    $cameraDevices = $cameraDevices | Where-Object { $_ -ne $null } | Select-Object -Unique
            
                    if ($cameraDevices -and $cameraDevices.Count -gt 0) {
                        Write-Host "Camera device(s) found:" -ForegroundColor Green
                        $cameraDevices | ForEach-Object {
                            Write-Host "Name: $($_.Name)"
                        }
            
                        # Attempt to open the default Camera app
                        try {
                            Start-Process -FilePath "microsoft.windows.camera:"
                            Write-Host "Opening the default Camera app..." -ForegroundColor Green
                        } catch {
                            Write-Host "Default Camera app launch failed. Attempting fallback options..." -ForegroundColor Yellow
            
                            # Fallbacks
                            if (-not (Open-CameraFallback)) {
                                Write-Host "All attempts to open the Camera app failed. Consider using an alternative application." -ForegroundColor Red
                            }
                        }
                    } else {
                        Write-Host "No camera devices detected on this machine. Camera app will not be opened." -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host "An error occurred while checking for camera drivers: $_" -ForegroundColor Red
                }
            }
            
            function Open-CameraFallback {
                try {
                    # Fallback 1: Use explorer with URI
                    Start-Process -FilePath "explorer.exe" -ArgumentList "microsoft.windows.camera:"
                    Write-Host "Fallback: Opened Camera app via explorer.exe." -ForegroundColor Green
                    return $true
                } catch {
                    Write-Host "Fallback 1 failed: Could not open Camera app via explorer." -ForegroundColor Red
                }
            
                try {
                    # Fallback 2: Launch directly from package path
                    $cameraPath = "C:\Windows\SystemApps\Microsoft.WindowsCamera_cw5n1h2txyewy\WindowsCamera.exe"
                    if (Test-Path $cameraPath) {
                        Start-Process -FilePath $cameraPath
                        Write-Host "Fallback: Opened Camera app directly from package path." -ForegroundColor Green
                        return $true
                    } else {
                        Write-Host "Fallback 2 failed: Camera app not found in the expected path." -ForegroundColor Red
                    }
                } catch {
                    Write-Host "Fallback 2 failed: Unable to launch Camera app from package path." -ForegroundColor Red
                }
            
                try {
                    # Fallback 3: Open shell AppsFolder
                    Start-Process -FilePath "shell:AppsFolder\Microsoft.WindowsCamera_cw5n1h2txyewy!App"
                    Write-Host "Fallback: Opened Camera app using shell:AppsFolder." -ForegroundColor Green
                    return $true
                } catch {
                    Write-Host "Fallback 3 failed: Could not open Camera app using shell:AppsFolder." -ForegroundColor Red
                }
                return $false
            }
            
        }
        Start-Job -ScriptBlock $scriptContent | Out-Null

        Write-Host "Camera check started successfully in the background." -ForegroundColor Green
   
        } catch {
            Write-Host "An error occurred while starting the Camera: $_" -ForegroundColor Red
        }
    }


function Get-SystemInfo {
    Write-Host " `nRefreshing System Information..." -ForegroundColor Yellow

    # Define tasks dynamically with a script block
    $tasks = @(
        @{ Name = "Memory Info"; Task = { Get-TotalSticksRam } },
        @{ Name = "Processor Info"; Task = { Get-ProcessorInfo } },
        @{ Name = "GPU Info"; Task = { Get-GPUInfo } },
        @{ Name = "Windows Version"; Task = { Get-WindowsVersion } },
        @{ Name = "Activation Details"; Task = { Get-ActivationDetails } },
        @{ Name = "System Product Keys"; Task = { Show-WindowsProductKeys } },
        @{ Name = "Disk Info"; Task = { Get-DiskInfo } }
    )

    $totalTasks = $tasks.Count
    $results = @()

    $systemInfo = [PSCustomObject]@{}

    Write-Host "`nIF STUCK PRESS [ENTER] <<<< " -ForegroundColor Red
    for ($i = 0; $i -lt $totalTasks; $i++) {
        $taskName = $tasks[$i].Name
        $task = $tasks[$i].Task

        Write-Host "Starting task: $taskName " -ForegroundColor Cyan -NoNewline

        try {
            $executionTime = Measure-Command {
                $result = & $task
                $systemInfo | Add-Member -MemberType NoteProperty -Name $taskName -Value $result
            }
            Write-Host "$($executionTime.TotalSeconds) seconds." -ForegroundColor Green
        } catch {
            Write-Host "`nTask '$taskName' encountered an error: $_" -ForegroundColor Red
            $systemInfo | Add-Member -MemberType NoteProperty -Name $taskName -Value "Error"
        }
    }

    Write-Progress -Activity "System Information Completed" -Completed

    return $systemInfo
}

<# # Fetch system information
$data = Get-SystemInfo

# Output the results in a loop
foreach ($key in $data.PSObject.Properties) {
    # Check if the value is a PSCustomObject or an IEnumerable
    if ($key.Value -is [PSCustomObject] -or $key.Value -is [System.Collections.IEnumerable]) {
        Write-Host "$($key.Name):"

        if ($key.Name -eq "Memory Info" -and $key.Value -is [PSCustomObject]) {
            # Memory Info with SlotDetails
            Write-Host "  Total Memory: $($key.Value.TotalMemory)"
            Write-Host "  Total Slots: $($key.Value.TotalSlots)"
            Write-Host "  Used Slots: $($key.Value.UsedSlots)"
            Write-Host "  Onboard Memory: $($key.Value.OnboardMemory)"
            Write-Host "  Onboard Size: $($key.Value.OnboardSize)"
            Write-Host "  Slot Details:"
            foreach ($slot in $key.Value.SlotDetails) {
                Write-Host "    Slot: $($slot.Slot) | Size: $($slot.Size) | Architecture: $($slot.Architecture) | Speed: $($slot.Speed)"
            }
        } elseif ($key.Name -eq "GPU Info" -and $key.Value -is [PSCustomObject]) {
            # GPU Info
            Write-Host "  GPUs:"
            foreach ($gpu in $key.Value.GPUs) {
                Write-Host "    Name: $($gpu.Name) | Dedicated: $($gpu.Dedicated) | Color: $($gpu.Color)"
            }
        } else {
            # Generic handling for other PSCustomObject or IEnumerable values
            foreach ($item in $key.Value) {
                if ($item -is [PSCustomObject]) {
                    foreach ($subKey in $item.PSObject.Properties) {
                        Write-Host "  $($subKey.Name): $($subKey.Value)"
                    }
                } else {
                    Write-Host "  $item"
                }
            }
        }
    } else {
        # Simple property output
        Write-Host "$($key.Name): $($key.Value)"
    }
 #>