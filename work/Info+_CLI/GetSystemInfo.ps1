
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
            Write-Host "No volumes found or no volumes with drive letters."
            return @([PSCustomObject]@{ DriveLetter = "None"; DiskName = "No Disk Found"; TotalSizeGB = "0 GB"; UsedSizeGB = "0 GB" })
        }

        Write-Host "Volumes retrieved: $($volumes.Count)" -NoNewline

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
function Open-ThisComputer {
    try {
        Start-Process -FilePath "explorer.exe" -ArgumentList "shell:MyComputerFolder"
    } catch {
        Write-Host "Failed to open 'This Computer': $_" -ForegroundColor Red
    }
}

function Get-TotalSticksRam {

    try {
        # Primary method: Get-CimInstance
        $totalMemory = [math]::round((Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue).TotalPhysicalMemory / 1GB, 2)

        $memoryModules = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction SilentlyContinue
        $totalSlots = (Get-CimInstance -ClassName Win32_PhysicalMemoryArray -ErrorAction SilentlyContinue).MemoryDevices
        $usedSlots = $memoryModules.Count

        $onboardMemory = $memoryModules | Where-Object { $_.FormFactor -eq 12 } # FormFactor 12 indicates onboard memory
        $onboardMemorySize = if ($onboardMemory) {
            [math]::round(($onboardMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB, 2)
        } else {
            0
        }

        $slotDetails = $memoryModules | ForEach-Object {
            [PSCustomObject]@{
                Slot          = $_.DeviceLocator
                Size          = if ($_.Capacity) { "$([math]::round($_.Capacity / 1GB, 2)) GB" } else { "Unknown" }
                Architecture  = Get-MemoryTypeName -MemoryType $_.SMBIOSMemoryType
                Speed         = if ($_.Speed) { "$($_.Speed) MHz" } else { "Unknown" }
            }
        }

        # Fallback: Use WMI if CIM fails
        if (-not $memoryModules -or $memoryModules.Count -eq 0) {
            Write-Warning "Primary method failed. Falling back to WMI..."
            $memoryModules = Get-WmiObject -Class Win32_PhysicalMemory -ErrorAction SilentlyContinue
            $slotDetails = $memoryModules | ForEach-Object {
                [PSCustomObject]@{
                    Slot          = $_.DeviceLocator
                    Size          = if ($_.Capacity) { "$([math]::round($_.Capacity / 1GB, 2)) GB" } else { "Unknown" }
                    Architecture  = Get-MemoryTypeName -MemoryType $_.SMBIOSMemoryType
                    Speed         = if ($_.Speed) { "$($_.Speed) MHz" } else { "Unknown" }
                }
            }
        }

        # Ensure fallback values for missing data
        if (-not $totalMemory -or $totalMemory -eq 0) {
            Write-Warning "Unable to retrieve total memory using primary method. Using fallback..."
            $totalMemory = [math]::round(($memoryModules | Measure-Object -Property Capacity -Sum).Sum / 1GB, 2)
        }
        if (-not $totalSlots -or $totalSlots -eq 0) {
            $totalSlots = $memoryModules.Count
        }
        if (-not $usedSlots -or $usedSlots -eq 0) {
            $usedSlots = $memoryModules.Count
        }

        # Return structured result
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
        return [PSCustomObject]@{
            TotalMemory     = "Error"
            TotalSlots      = "Error"
            UsedSlots       = "Error"
            OnboardMemory   = "Error"
            OnboardSize     = "Error"
            SlotDetails     = @([PSCustomObject]@{ Slot = "Error"; Size = "Error"; Architecture = "Error"; Speed = "Error" })
        }
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
        # Use slmgr.vbs to retrieve the partial product key, can't get the full key need more debugging
        $slmgrOutput = cscript.exe $env:SystemRoot\System32\slmgr.vbs /dlv 2>&1 | Out-String
        $partialKeyPattern = "Partial Product Key:\s*([A-Z0-9]{5})"

        # Parse the partial product key
        $installedKey = if ($slmgrOutput -match $partialKeyPattern) {
            "XXXXX-XXXXX-XXXXX-XXXXX-$($matches[1])"
        } else {
            "Not Found"
        }

        $oemKey = Get-OEMKey

        # Assign colors for display
        $installedKeyColor = if ($installedKey -ne "Not Found") { "Yellow" } else { "Red" }
        $oemKeyColor = if ($oemKey -eq "Not Found") { "Yellow" } elseif ($oemKey -eq "Error") { "Red" } else { "Green" }

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
            try {
                function Get-CameraAndOpenApp {
                    try {
                        Write-Host "Checking for camera devices..." -ForegroundColor Yellow
                        
                        $cameraDevices = @()

                        # List of common camera-related terms and brands
                        $cameraKeywords = @(
                            # Generic terms
                            "Camera", "Webcam", "Imaging Device", "Integrated Camera", "USB Camera", "UVC Camera",
                            
                            # Popular brands
                            "LifeCam", "Kiyo", "EasyCamera", "CrystalEye", "RealSense",
                            
                            # Specific models
                            "C920", "BRIO", "StreamCam", "Kiyo Pro", "C615", "C505", "BRIO 4K", "WebCam HD", "FC"
                            
                            # Emerging brands and devices
                            "Facecam", "Poly Studio", 
                            
                            # Specific HIDs and device types
                            "USB Video Device",
                            
                            # Device-specific terms (unique identifiers seen in HID)
                            "Device 0x046D", "Device 0x0C45", "Device 0x04F2", "Device 0x1BCF", "Device 0x2232"
                        )
                        function Test-Keyword { # Allow substring matching
                            param (
                                [string]$PropertyValue
                            )
                            return $cameraKeywords | Where-Object { $PropertyValue -match $_ }
                        }
                        
                        # 1st check using Win32_PnPEntity
                        $cameraDevices += Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object {
                            Test-Keyword -PropertyValue $_.Name -or $_.PNPClass -eq "Image"
                        }
                        
                        # 2nd check using Win32_USBHub (for USB-connected cameras)
                        $cameraDevices += Get-CimInstance -ClassName Win32_USBHub -ErrorAction SilentlyContinue | Where-Object {
                            Test-Keyword -PropertyValue $_.Name
                        }
                        
                        # 3rd check using MSFT_PhysicalCamera (specific to integrated cameras)
                        $cameraDevices += Get-CimInstance -Namespace "Root\CIMv2\DeviceMap" -ClassName MSFT_PhysicalCamera -ErrorAction SilentlyContinue | Where-Object {
                            Test-Keyword -PropertyValue $_.Name
                        }
                        
                        # 4th check for Windows Imaging Device interface
                        $cameraDevices += Get-WmiObject -Namespace "Root\CIMv2" -Query "SELECT * FROM Win32_PnPEntity WHERE Service = 'usbvideo'" -ErrorAction SilentlyContinue | Where-Object {
                            Test-Keyword -PropertyValue $_.Description
                        }
                        
                        # 5th check using DeviceSetupManager (DSMs)
                        $cameraDevices += Get-CimInstance -ClassName MSFT_DeviceSetupManager -Namespace "Root\StandardCimv2" -ErrorAction SilentlyContinue | Where-Object {
                            Test-Keyword -PropertyValue $_.Name
                        }
                        
                        # 6th check using WPD (Windows Portable Devices)
                        $cameraDevices += Get-CimInstance -ClassName Win32_PortableDevice -ErrorAction SilentlyContinue | Where-Object {
                            Test-Keyword -PropertyValue $_.Description
                        }
                        
                        # 7th check using SetupAPI (Query hardware device interface)
                        $cameraDevices += Get-WmiObject -Namespace "Root\CIMv2" -Query "SELECT * FROM Win32_PnPEntity WHERE Caption LIKE '%Camera%' OR Description LIKE '%Webcam%' OR Manufacturer LIKE '%Camera%'" -ErrorAction SilentlyContinue | Where-Object {
                            Test-Keyword -PropertyValue $_.Name
                        }
                        
                        # 8th check using DirectShow filters
                        try {
                            Add-Type -AssemblyName System.Device
                            $directShowDevices = [System.Device.Location.GeoCoordinateWatcher]::new()
                            if ($directShowDevices) {
                                $cameraDevices += $directShowDevices | Where-Object {
                                    Test-Keyword -PropertyValue $_.DisplayName
                                }
                            }
                        } catch {
                            Write-Debug "DirectShow method failed: $_" # This method may not work on all systems
                        }
                        
                        # Remove duplicates and ensure valid results
                        $cameraDevices = $cameraDevices | Where-Object { $_ -ne $null } | Select-Object -Unique
                        
                        # Output matched devices
                        if ($cameraDevices.Count -gt 0) {
                            Write-Host "Matched Devices:" -ForegroundColor Green
                            $cameraDevices | ForEach-Object { Write-Host "Name: $($_.Name)" }
                        } else {
                            Write-Host "No matching devices found." -ForegroundColor Yellow
                        }
                        if ($cameraDevices -and $cameraDevices.Count -gt 0) {
                            Write-Host "Camera device(s) found:" -ForegroundColor Green
                            $cameraDevices | ForEach-Object {
                                Write-Host "Name: $($_.Name)"
                            }
                            try {
                                Start-Process -FilePath "microsoft.windows.camera:"
                                return "Success"
                            } catch {
                                return "Failed"
                            }
                        } else {
                            return "NoCamera"
                        }
                    } catch {
                        return "Error" # Return error if any exception occurs - this will be caught in the main script
                    }
                }

                Get-CameraAndOpenApp
            } catch {
                return "ErrorScript"
            }
        }

        $job = Start-Job -ScriptBlock $scriptContent
        $jobResult = $null
        do {
            Start-Sleep -Milliseconds 500 # Wait for the job to complete
            $jobResult = Receive-Job -Job $job -ErrorAction SilentlyContinue
        } while (-not $jobResult -and $job.State -eq 'Running')

        switch ($jobResult) {
            "Success" {
                Write-Host "Camera app started successfully." -ForegroundColor Green
            }
            "NoCamera" {
                Write-Host "No camera detected on this machine." -ForegroundColor Yellow
            }
            "Failed" {
                Write-Host "Failed to open the Camera app." -ForegroundColor Red
            }
            "Error" {
                Write-Host "An error occurred while checking for camera or opening the app." -ForegroundColor Red
            }
            "ErrorScript" {
                Write-Host "An error occurred while openning script block." -ForegroundColor Red
            }
            default {
                Write-Host "Camera check encountered an unknown issue." -ForegroundColor Yellow
            }
        }

        # Clean up the job
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
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
        #@{ Name = "Disk Info"; Task = { Get-DiskInfo } },
        @{ Name = "System Product Keys"; Task = { Show-WindowsProductKeys } }
    )

    $totalTasks = $tasks.Count

    $systemInfo = [PSCustomObject]@{}

    Write-Host "`nIF STUCK PRESS [ENTER] <<<< " -ForegroundColor Red
    for ($i = 0; $i -lt $totalTasks; $i++) {
        $taskName = $tasks[$i].Name
        $task = $tasks[$i].Task

        Write-Host "Getting: $taskName Data... " -ForegroundColor Cyan -NoNewline

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