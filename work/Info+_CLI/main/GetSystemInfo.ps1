function Get-MemoryTypeName {
    param ([int]$MemoryType)
    switch ($MemoryType) {
        0  { "Unknown" }
        1  { "Other" }
        2  { "DRAM" }
        3  { "Synchronous DRAM" }
        4  { "Cache DRAM" }
        5  { "EDO" }
        6  { "EDRAM" }
        7  { "VRAM" }
        8  { "SRAM" }
        9  { "RAM" }
        10 { "ROM" }
        11 { "Flash" }
        12 { "EEPROM" }
        13 { "FEPROM" }
        14 { "EPROM" }
        15 { "CDRAM" }
        16 { "3DRAM" }
        17 { "SDRAM" }
        18 { "SGRAM" }
        19 { "RDRAM" }
        20 { "DDR" }
        21 { "DDR2" }
        22 { "DDR2 FB-DIMM" }
        23 { "Reserved" }
        24 { "DDR3" }
        25 { "FBD2" }
        26 { "DDR4" }
        27 { "DDR5" }
        28 { "LPDDR" }
        29 { "LPDDR2" }
        30 { "LPDDR3" }
        31 { "LPDDR4" }
        32 { "Logical non-volatile device" }
        33 { "HBM" }        # High Bandwidth Memory
        34 { "HBM2" }       # High Bandwidth Memory 2
        35 { "DDR4E-SDRAM" }
        36 { "LPDDR4X" }
        37 { "LPDDR5" }
        38 { "LPDDR5X" }
        39 { "HBM3" }       # High Bandwidth Memory 3
        40 { "GDDR" }
        41 { "GDDR2" }
        42 { "GDDR3" }
        43 { "GDDR4" }
        44 { "GDDR5" }
        45 { "GDDR6" }
        46 { "GDDR6X" }     # NVIDIA proprietary memory standard
        default { "Unknown or Reserved" }
    }
}
function Get-TotalSticksRam {
    try {
        # Retrieve total physical memory (in GB) from Win32_ComputerSystem.
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
        $totalMemoryGB = if ($computerSystem.TotalPhysicalMemory) {
            [math]::round($computerSystem.TotalPhysicalMemory / 1GB, 2)
        } else {
            0
        }

        # Retrieve memory modules from Win32_PhysicalMemory.
        $memoryModules = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction SilentlyContinue

        # Retrieve physical memory array to get the total number of memory slots.
        $physicalMemoryArray = Get-CimInstance -ClassName Win32_PhysicalMemoryArray -ErrorAction SilentlyContinue
        $totalSlots = if ($physicalMemoryArray -and $physicalMemoryArray.MemoryDevices -gt 0) {
            $physicalMemoryArray.MemoryDevices
        }
        else {
            # If the physical array isn’t reporting correctly, assume only the modules present.
            $memoryModules.Count
        }
        $usedSlots = if ($memoryModules) { $memoryModules.Count } else { 0 }

        # Determine onboard memory.
        # (Often FormFactor=12 indicates onboard memory. Note that on some systems this may differ.)
        $onboardMemoryModules = $memoryModules | Where-Object { $_.FormFactor -eq 12 }
        $onboardMemorySizeGB = if ($onboardMemoryModules) {
            [math]::round( ($onboardMemoryModules | Measure-Object -Property Capacity -Sum).Sum / 1GB, 2)
        } else {
            0
        }

        # Build detailed info for each memory module.
        $slotDetails = $memoryModules | ForEach-Object {
            # Prefer SMBIOSMemoryType if available, otherwise use MemoryType.
            $memType = if (($_.SMBIOSMemoryType) -and ($_.SMBIOSMemoryType -ne 0)) {
                $_.SMBIOSMemoryType
            } else {
                $_.MemoryType
            }
            [PSCustomObject]@{
                Slot       = $_.DeviceLocator
                Size       = if ($_.Capacity) { "$([math]::round($_.Capacity / 1GB, 2)) GB" } else { "Unknown" }
                Type       = Get-MemoryTypeName -MemoryType $memType
                Speed      = if ($_.Speed) { "$($_.Speed) MHz" } else { "Unknown" }
                FormFactor = $_.FormFactor  # numeric value; you can map it to text if desired
            }
        }

        # Calculate available slots.
        $availableSlots = if ([int]$totalSlots -gt 0) { [int]$totalSlots - [int]$usedSlots } else { "Unknown" }

        # Return a structured object.
        return [PSCustomObject]@{
            TotalMemoryGB  = "$totalMemoryGB GB"
            TotalSlots     = $totalSlots
            UsedSlots      = $usedSlots
            AvailableSlots = $availableSlots
            OnboardMemory  = if ($onboardMemoryModules.Count -gt 0) { "Yes" } else { "No" }
            OnboardSizeGB  = "$onboardMemorySizeGB GB"
            SlotDetails    = $slotDetails
        }
    }
    catch {
        Write-Error "An error occurred while retrieving memory information: $_"
        return [PSCustomObject]@{
            TotalMemoryGB  = "Error"
            TotalSlots     = "Error"
            UsedSlots      = "Error"
            AvailableSlots = "Error"
            OnboardMemory  = "Error"
            OnboardSizeGB  = "Error"
            SlotDetails    = @([PSCustomObject]@{ Slot = "Error"; Size = "Error"; Type = "Error"; Speed = "Error"; FormFactor = "Error" })
        }
    }
}
function Get-ProcessorInfo {
    try {
        # Define a WMI query for only the necessary properties.
        $query = "SELECT Name, MaxClockSpeed, NumberOfCores, NumberOfLogicalProcessors, SocketDesignation FROM Win32_Processor"
        $searcher = New-Object System.Management.ManagementObjectSearcher($query)
        
        # Force the result to be an array using @( ... )
        $processors = @($searcher.Get() | ForEach-Object {
            [PSCustomObject]@{
                Name              = ($_.Properties["Name"].Value).Trim()
                MaxClockSpeed     = "$($_.Properties["MaxClockSpeed"].Value) MHz"
                Cores             = $_.Properties["NumberOfCores"].Value
                LogicalProcessors = $_.Properties["NumberOfLogicalProcessors"].Value
                Socket            = $_.Properties["SocketDesignation"].Value
            }
        })

        # Determine the display color based on the first processor's name.
        if ($processors.Count -gt 0) {
            $procName = $processors[0].Name
            $cpuColor = if ($procName -match "AMD") { "Red" }
                        elseif ($procName -match "Intel") { "Cyan" }
                        else { "Blue" }
        }
        else {
            $cpuColor = "Blue"
        }

        return [PSCustomObject]@{
            Info  = $processors
            Color = if ([Enum]::IsDefined([System.ConsoleColor], $cpuColor)) { $cpuColor } else { "Gray" }
        }
    }
    catch {
        return [PSCustomObject]@{
            Info  = "Error retrieving processor information"
            Color = "Red"
        }
    }
}




function Get-GPUInfo {
    try {
        # Primary check using Get-CimInstance
        $gpus = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue | ForEach-Object {
            # Determine if the GPU is dedicated or integrated
            $isDedicated = if ($_.VideoArchitecture -eq 5) { 
                "Dedicated" 
            } elseif ($_.VideoArchitecture -eq 2) { 
                "Integrated" 
            } elseif ($_.AdapterRAM -and $_.AdapterRAM -gt 2GB -and $_.AdapterCompatibility -match "NVIDIA|AMD") {
                "Dedicated" 
            } elseif ($_.AdapterCompatibility -match "Intel" -or $_.AdapterDACType -match "AMD") {
                if ($_.Description -match "UHD|Integrated|APU") {
                    "Integrated"
                } else {
                    "Unknown"
                }
            } else { 
                "Unknown" 
            }
            
            # Assign colors based on GPU type
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

        # Ensure $gpus is an array
        $gpus = @($gpus)

        if ($gpus.Count -gt 0) {
            return [PSCustomObject]@{
                GPUs = $gpus
            }
        } else {
            # Fallback to WMIC
            $wmicOutput = (wmic path Win32_VideoController get Caption,AdapterRAM /format:list) -split "`r?`n"
            $wmicGpus = $wmicOutput | Where-Object { $_ -match "Caption|AdapterRAM" } | ForEach-Object {
                if ($_ -match "Caption") {
                    $name = ($_ -split "=")[1].Trim()
                } elseif ($_ -match "AdapterRAM") {
                    $adapterRam = ($_ -split "=")[1].Trim()
                    $isDedicated = if ([int]$adapterRam -gt 2GB) { "Dedicated" } else { "Integrated" }
                }
                if ($name) {
                    [PSCustomObject]@{
                        Name       = $name
                        Dedicated  = $isDedicated
                        Color      = if ($name -match "NVIDIA") { "Green" } elseif ($name -match "AMD") { "Red" } else { "Cyan" }
                    }
                }
            }
            if ($wmicGpus) {
                return [PSCustomObject]@{
                    GPUs = @($wmicGpus)
                }
            } else {
                Write-Host "No GPUs detected on this system."
                return [PSCustomObject]@{
                    GPUs = @([PSCustomObject]@{ Name = "No GPU Found"; Dedicated = "N/A"; Color = "Gray" })
                }
            }
        }
    } catch {
        Write-Host "An error occurred while retrieving GPU information: $_" -ForegroundColor Red
        return [PSCustomObject]@{
            GPUs = @([PSCustomObject]@{ Name = "Error Retrieving GPU Info"; Dedicated = "N/A"; Color = "Red" })
        }
    }
}

function Get-WindowsVersion {
    return (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
}
function Get-ActivationStatus {
    try {
        # Run 'slmgr.vbs /xpr' to check activation status
        $activationOutput = (cscript //nologo C:\Windows\System32\slmgr.vbs /xpr) -join "`n"

        # Detect system language (LCID)
        $language = (Get-Culture).LCID

        # Define activation messages based on language
        $activationMessages = @{
            "1033" = "The machine is permanently activated"  # English (US)
            "2057" = "The machine is permanently activated"  # English (UK)
            "1046" = "O computador está ativado permanentemente"  # Portuguese (Brazil)
            "2070" = "O computador está permanentemente ativado"  # Portuguese (Portugal)
        }

        # Get the correct activation message (fallback to English if not found)
        $activationText = if ($activationMessages.ContainsKey($language)) { 
            $activationMessages[$language] 
        } else { 
            $activationMessages["1033"] 
        }

        # Check if the output contains the activation confirmation
        if ($activationOutput -match [regex]::Escape($activationText)) {
            return [PSCustomObject]@{
                Status          = "$unicodeEmojiCheckMark Activated"
                ActivationColor = "Green"
            }
        }
        else {
            return [PSCustomObject]@{
                Status          = "$unicodeEmojiCrossMark Not Activated"
                ActivationColor = "Red"
            }
        }
    }
    catch {
        Write-Error "An error occurred while checking activation status: $_"
        return [PSCustomObject]@{
            Status          = "$unicodeEmojiWarning Unknown"
            ActivationColor = "Red"
        }
    }
}

function Get-WindowsProductKeys {
    [CmdletBinding()]
    param()

    # Helper function to decode the DigitalProductId to a product key.
    function Convert-Key {
        param (
            [byte[]]$DigitalProductId
        )
        # Character set used for the product key
        $keyChars = "BCDFGHJKMPQRTVWXY2346789"
        $decodedKey = ""
        $key = New-Object System.Collections.Generic.List[byte]
        
        # For Windows 7 and later, the 15-byte key is stored starting at offset 52.
        for ($i = 52; $i -lt 52 + 15; $i++) {
            $key.Add($DigitalProductId[$i])
        }

        # Decode 25 characters from the 15-byte key.
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

        # Insert dashes every 5 characters for readability.
        return ($decodedKey -replace "(.{5})", '$1-').TrimEnd('-')
    }

    try {
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
        $regProps = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
        $digitalProductId = $regProps.DigitalProductId

        $installedKey = "Not Found"
        if ($digitalProductId) {
            $installedKey = Convert-Key -DigitalProductId $digitalProductId
        }

        # Fallback: query WMI if no key was found in the registry.
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

        # If a global variable $WindowsGenericKeys exists, check if the installed key is generic.
        if ($WindowsGenericKeys -and $installedKey -ne "Not Found") {
            $matchedKey = $WindowsGenericKeys | Where-Object { $_.Key -eq $installedKey } | Select-Object -First 1
            if ($matchedKey) {
                $installedKey = "$installedKey (Generic key: $($matchedKey.Edition))"
            }
        }

        # Retrieve the OEM key.
        $oemKey = Get-OEMKey

        $installedKeyColor = if ($installedKey -ne "Not Found") { "Yellow" } else { "Red" }
        
        $oemKeyColor = if ($oemKey -eq "Not Found") { "Yellow" } elseif ($oemKey -eq "Error") { "Red" } else { "Green" }

        # Validate the color names against System.ConsoleColor.
        $installedKeyColor = if ([Enum]::IsDefined([System.ConsoleColor], $installedKeyColor)) { $installedKeyColor } else { "Red" }
        $oemKeyColor = if ([Enum]::IsDefined([System.ConsoleColor], $oemKeyColor)) { $oemKeyColor } else { "Red" }
        
        return [PSCustomObject]@{
            InstalledKey = @{
                Value = $installedKey
                Color = $installedKeyColor
            }
            OEMKey = @{
                Value = $oemKey
                Color = $oemKeyColor
            }
        }
    } catch {
        Write-Error "An error occurred: $_"
        return [PSCustomObject]@{
            InstalledKey = @{
                Value = "Error"
                Color = "Red"
            }
            OEMKey = @{
                Value = "Error"
                Color = "Red"
            }
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
            return "$unicodeEmojiCrossMark Not Found"
        } else {
            #Write-Host "OEM key retrieved successfully: $oemKey"
            return $oemKey
        }
    } catch {
        #Write-Host "An unexpected error occurred while retrieving OEM key: $_"
        return "$unicodeEmojiWarning Error"
    }

}

function Start-CameraAppInBackground {
    try {
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

        Write-Host "Camera app process handled in the background " -ForegroundColor Yellow
        Start-ScriptBlockInRunspace -ScriptBlock $scriptContent
    } catch {
        Write-Host "An error occurred while starting the Camera: $_" -ForegroundColor Red
    }
}

function Get-SystemInfo {
    Write-Host " `n$unicodeEmojiCooling $unicodeEmojiCooling Refreshing System Information... $unicodeEmojiCooling $unicodeEmojiCooling" -ForegroundColor Yellow

    # Define tasks dynamically with a script block
    $tasks = @(
        @{ Name = "Memory Info"; Task = { Get-TotalSticksRam } },
        @{ Name = "Processor Info"; Task = { Get-ProcessorInfo } },
        @{ Name = "GPU Info"; Task = { Get-GPUInfo } },
        @{ Name = "Windows Version"; Task = { Get-WindowsVersion } },
        @{ Name = "Activation Details"; Task = { Get-ActivationStatus } },
        @{ Name = "System Product Keys"; Task = { Get-WindowsProductKeys } }
    )

    $totalTasks = $tasks.Count

    $systemInfo = [PSCustomObject]@{}

    Write-Host "`n$unicodeEmojiLock $unicodeEmojiLock PRESS[ENTER] $unicodeEmojiLock $unicodeEmojiLock<<<< " -ForegroundColor Red
    for ($i = 0; $i -lt $totalTasks; $i++) {
        $taskName = $tasks[$i].Name
        $task = $tasks[$i].Task
    
        Write-Host " $unicodeEmojiInformation : $taskName Data...       $unicodeEmojiHourglass " -ForegroundColor Cyan -NoNewline
    
        try {
            $executionTime = Measure-Command {
                $result = & $task
                $systemInfo | Add-Member -MemberType NoteProperty -Name $taskName -Value $result
            }
            Write-Host "`r$unicodeEmojiCheckMark $taskName completed in $($executionTime.TotalSeconds) seconds." -ForegroundColor Green
        } catch {
            Write-Host "`n$unicodeEmojiWarning Task '$taskName' encountered an error: $_" -ForegroundColor Red
            $systemInfo | Add-Member -MemberType NoteProperty -Name $taskName -Value "Error"
        }
    }

    Write-Progress -Activity "System Information Completed" -Completed

    return $systemInfo
}


