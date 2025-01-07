function Get-DiskInfo {
    # Initialize an empty array to store disk objects
    $Disks = @()

    # Fetch volumes and iterate over them
    Get-Volume | Where-Object { $null -ne $_.DriveLetter } | ForEach-Object {
        $diskHealth = "Unknown"
        $healthPercentage = "Unknown%"
        $diskName = "Unknown"
        $diskObject = $null

        try {
            # Get the associated disk number using Get-Partition
            $partition = Get-Partition -DriveLetter $_.DriveLetter
            if ($partition) {
                $diskNumber = $partition.DiskNumber

                # Attempt to get disk health using Get-PhysicalDisk
                $physicalDisk = Get-PhysicalDisk | Where-Object { $_.DeviceID -eq $diskNumber }
                if ($physicalDisk) {
                    $diskHealth = $physicalDisk.HealthStatus
                    $diskName = $physicalDisk.FriendlyName

                    # Calculate health percentage for SSD or HDD dynamically
                    if ($physicalDisk.MediaType -eq "SSD") {
                        # Use SMART attributes for SSD if available

                        try {
                            # Use Get-CimInstance for SMART data
                            $smartData = Get-CimInstance -Namespace "root\WMI" -ClassName "MSStorageDriver_FailurePredictStatus" |
                                Where-Object { $_.InstanceName -match $diskNumber }
                        
                            if ($smartData -and $smartData.PredictFailure -eq $false) {$healthPercentage = "100%"} 
                            elseif ($smartData -and $smartData.PredictFailure -eq $true) {
                                $healthPercentage = "10%"
                                $diskHealth = "Failing"
                            } else {$healthPercentage = "Unknown%"}
                        } catch {
                            # Handle 'Access Denied' or other errors
                            Write-Host "Access denied when querying SMART data for disk $diskNumber. Using alternative logic." -ForegroundColor Yellow
                            $diskHealth = "Error: Unable to query SMART data"
                            $healthPercentage = "Unknown%"
                        }                       
                        
                    } else {
                        # Default for HDD: Assuming manual degradation over time
                        $healthPercentage = "HDD: Assuming manual degradation over time"
                    }
                } else {
                    try {
                        # Fallback to SMART attributes if Get-PhysicalDisk fails
                        $smartData = Get-CimInstance -Namespace "root\WMI" -ClassName "MSStorageDriver_FailurePredictData" |
                            Where-Object { $_.InstanceName -match $diskNumber }
                        if ($smartData) {
                            $currentValue = $smartData.VendorSpecific[3]
                            $thresholdValue = $smartData.VendorSpecific[5]
                    
                            if ($null -ne $currentValue -and $null -ne $thresholdValue -and $thresholdValue -ne 0) {
                                $healthPercentage = [math]::round(($currentValue / $thresholdValue) * 100, 2)
                                $diskHealth = if ($healthPercentage -ge 70) { "Healthy" } elseif ($healthPercentage -ge 40) { "Warning" } else { "Failing" }
                            } else {
                                $diskHealth = "Unknown (Invalid SMART Data)"
                                $healthPercentage = "Unknown%"
                            }
                        } else {
                            Write-Host "SMART data not available for disk $diskNumber." -ForegroundColor Yellow
                            $diskHealth = "Unknown (No SMART Data)"
                            $healthPercentage = "Unknown%"
                        }
                    } catch {
                        Write-Host "Error accessing SMART data for disk ${diskNumber}: $_" -ForegroundColor Red
                        $diskHealth = "Error"
                        $healthPercentage = "Error%"
                    }                  
                }
            } else {
                $diskHealth = "Unknown (No Partition Data)"
                $healthPercentage = "Unknown%"
            }
        } catch {
            Write-Host "Failed to retrieve health status for disk $_.DriveLetter: $_" -ForegroundColor Red
            $diskHealth = "Error"
            $healthPercentage = "Error%"
        }

        # Construct the disk object and add it to the array
        $diskObject = [PSCustomObject]@{
            DriveLetter      = $_.DriveLetter
            DiskName         = $diskName
            TotalSizeGB      = [math]::round($_.Size / 1GB, 2)
            FreeSpaceGB      = [math]::round($_.SizeRemaining / 1GB, 2)
            HealthStatus     = $diskHealth
            HealthPercentage = if ($healthPercentage -is [string]) { $healthPercentage } else { "$healthPercentage%" }
        }

        $Disks += $diskObject
    }
    # Return the array of disk information
    return $Disks
}

function Get-TotalSticksRam {
    return [math]::round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
}

function Get-ProcessorInfo {
    return Get-CimInstance -ClassName Win32_Processor | ForEach-Object { 
        "$( $_.Name.Trim() ) $($_.MaxClockSpeed) MHz Cores $($_.NumberOfCores) $($_.NumberOfLogicalProcessors) Socket $($_.SocketDesignation)" 
    }
}

function Get-GPUInfo {
    return Get-CimInstance -ClassName Win32_VideoController | ForEach-Object { $_.Caption.Trim() }
}

function Get-WindowsVersion {
    return (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
}

function Get-ActivationDetails {
    try {
        # Fetch activation status
        $ActivationRaw = cscript /nologo $env:SystemRoot\System32\slmgr.vbs /dli | Select-String -Pattern "(License Status|Estado da Licen[çc]a|Estado da Ativa[çc][ãa]o):.+"
        $ActivationStatus = if ($ActivationRaw) {
            $ActivationRaw -replace "(License Status|Estado da Licen[çc]a|Estado da Ativa[çc][ãa]o): "
        } else {throw "Primary method failed"}
    
        # Fetch license type
        $LicenseTypeRaw = cscript /nologo $env:SystemRoot\System32\slmgr.vbs /dli | Select-String -Pattern "(Retail|OEM|Volume|Subscription|Evaluation|Academic|NFR|Upgrade|COEM|Pre-release|Enterprise|Insider|Education|Trial|MSDN|Insider|Provisória|Subscrip[çc][ãa]o|Avalia[çc][ãa]o|Acad[êe]mica|Ensino|Não Para Revenda)"
        $LicenseType = $LicenseTypeRaw.Matches.Value -join ", "
    
        # Determine subtypes
        $LicenseSubtypeMapping = @{
            "Volume"        = @{
                "Patterns"  = "(KMS|MAK|AAD-based|AD-based|Baseada em AAD|Baseada em AD)"
                "Subtypes"  = @{
                    "KMS|Gest[ãa]o de Chaves (KMS)" = "KMS"
                    "MAK|Chave de Ativação Múltipla (MAK)" = "MAK"
                    "AAD-based|Baseada em AAD" = "AAD-based"
                    "AD-based|Baseada em AD" = "Active Directory-based"
                }
                "Default"   = "Unknown Volume Type"
            }
            "Retail|Venda a Varejo" = @{
                "Patterns"  = "(Upgrade|Atualiza[çc][ãa]o)"
                "Subtypes"  = @{
                    "Upgrade|Atualiza[çc][ãa]o" = "Upgrade"
                }
                "Default"   = "Standard"
            }
            "OEM" = @{
                "Patterns"  = "(COEM|OEM Comercial)"
                "Subtypes"  = @{
                    "COEM|OEM Comercial" = "Commercial OEM"
                }
                "Default"   = "Standard OEM"
            }
            "Subscription|Subscrip[çc][ãa]o" = @{
                "Patterns"  = "(Microsoft 365|Visual Studio|Outro)"
                "Subtypes"  = @{
                    "Microsoft 365" = "Microsoft 365"
                    "Visual Studio" = "Visual Studio Subscription"
                }
                "Default"   = "Other Subscription"
            }
            "Evaluation|Avalia[çc][ãa]o" = @{
                "Patterns"  = "(Trial|Provis[óo]ria)"
                "Subtypes"  = @{
                    "Trial|Provis[óo]ria" = "Trial"
                }
                "Default"   = "Standard Evaluation"
            }
            "Academic|Acad[êe]mica|Education|Ensino" = @{
                "Default"   = "Education or Academic"
            }
            "Enterprise" = @{
                "Patterns"  = "(Agreement|Acordo)"
                "Subtypes"  = @{
                    "Agreement|Acordo" = "Enterprise Agreement"
                }
                "Default"   = "Standard Enterprise"
            }
            "NFR|Não Para Revenda" = @{
                "Default"   = "Not For Resale"
            }
            "Pre-release|Insider" = @{
                "Default"   = "Insider/Pre-release"
            }
        }
        
        # Efficiently determine the subtype
        foreach ($type in $LicenseSubtypeMapping.Keys) {
            if ($LicenseType -match $type) {
                $config = $LicenseSubtypeMapping[$type]
                if ($config.Patterns) {
                    # Check for specific subtypes
                    $rawSubtype = cscript /nologo $env:SystemRoot\System32\slmgr.vbs /dli | Select-String -Pattern $config.Patterns
                    foreach ($pattern in $config.Subtypes.Keys) {
                        if ($rawSubtype -match $pattern) {
                            $LicenseType += " ($($config.Subtypes[$pattern]))"
                            break
                        }
                    }
                }
                # Add default subtype if no match
                if ($LicenseType -notmatch "\(") {
                    $LicenseType += " ($($config.Default))"
                }
            }
        }
    
        # Combine activation status and license type
        $LicenseDetails = "$ActivationStatus - $LicenseType"
    
    } catch {
        try {
            # Fallback: CIM method
            $ActivationAlt = (Get-CimInstance -ClassName SoftwareLicensingProduct | Where-Object { $null -ne $_.PartialProductKey -and $_.LicenseStatus -eq 1 }).Name
            if ($ActivationAlt) {
                $LicenseDetails = "Licensed (via CIM) - $ActivationAlt"
            } else {
                throw "CIM method failed"
            }
        } catch {
            try {
                # Fallback: Registry method
                $ActivationRegistry = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" | Select-Object -ExpandProperty DigitalProductId
                if ($ActivationRegistry) {
                    $LicenseDetails = "Licensed (via Registry)"
                } else {
                    $LicenseDetails = "Unknown"
                }
            } catch {
                $LicenseDetails = "Unknown"
            }
        }
    }
    return $LicenseDetails
}
function Show-WindowsProductKeys {
    try {
        # Function to decode the product key
        function Convert-Key {
            param ([byte[]]$DigitalProductId)
            $keyChars = "BCDFGHJKMPQRTVWXY2346789"
            $decodedKey = ""
            $key = New-Object 'System.Collections.Generic.List[System.Byte]'

            # Initialize the key array from DigitalProductId
            for ($i = 52; $i -ge 52 - 15; $i--) {$key.Add($DigitalProductId[$i])}

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

            # Ensure the key is valid and contains 25 characters
            if ($decodedKey.Length -ne 25) {throw "Decoded product key length is invalid: $($decodedKey.Length)"}

            # Insert dashes for readability
            $decodedKey = $decodedKey.Substring(0, 5) + "-" +
                          $decodedKey.Substring(5, 5) + "-" +
                          $decodedKey.Substring(10, 5) + "-" +
                          $decodedKey.Substring(15, 5) + "-" +
                          $decodedKey.Substring(20, 5)
            return $decodedKey
        }

        # Attempt to retrieve installed product key
        $digitalProductId = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).DigitalProductId
        $installedKey = $null

        if ($digitalProductId) {
            $installedKey = Convert-Key -DigitalProductId $digitalProductId
        } else {
            # Fallback methods
            $installedKey = "Not Found"
        }

        # Retrieve OEM key if available
        $oemKey = (Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction SilentlyContinue).OA3xOriginalProductKey

        # Determine color for keys
        $installedKeyColor = if ($installedKey -ne "Not Found") { "Yellow" } else { "Red" }
        $oemKeyColor = if ($oemKey -eq "Not Found") {"Yellow"} elseif ($oemKey -eq "Error") {"Red"} else {"Green"}

        # Ensure valid colors
        if (-not ([Enum]::IsDefined([System.ConsoleColor], $installedKeyColor))) {$installedKeyColor = "Gray"}
        if (-not ([Enum]::IsDefined([System.ConsoleColor], $oemKeyColor))) {$oemKeyColor = "Gray"}

        # Return the results with color metadata
        return [PSCustomObject]@{
            InstalledKey      = $installedKey
            InstalledKeyColor = $installedKeyColor
            OEMKey            = if ($oemKey) { $oemKey } else { "Not Found" }
            OEMKeyColor       = $oemKeyColor
        }
    } catch {
        Write-Error $_.Exception.Message
        # Return error details with color metadata
        return [PSCustomObject]@{
            InstalledKey      = "Error"
            InstalledKeyColor = "Red"
            OEMKey            = "Error"
            OEMKeyColor       = "Red"
            ErrorMessage      = $_.Exception.Message
        }
    }
}

function Get-CameraAndOpenApp {
    try {
        # Check for camera devices using the Win32_PnPEntity class
        $cameraDevices = Get-CimInstance -ClassName Win32_PnPEntity | Where-Object {
            $_.Name -match "Camera|Webcam|Imaging Device" -or $_.PNPClass -eq "Image"
        }

        if ($cameraDevices -and $cameraDevices.Count -gt 0) {
            Write-Host "Camera driver found:" -ForegroundColor Green
            $cameraDevices | ForEach-Object {
                Write-Host "Name: $($_.Name)"
            }

            # Attempt to open the default camera app
            try {
                Start-Process -FilePath "microsoft.windows.camera:"
                Write-Host "Opening the default Camera app..." -ForegroundColor Green
            } catch {
                Write-Host "Default Camera app launch failed. Attempting fallback options..." -ForegroundColor Yellow
                
                # Fallback 1: Use explorer with URI
                try {
                    Start-Process -FilePath "explorer.exe" -ArgumentList "microsoft.windows.camera:"
                    Write-Host "Fallback: Opened Camera app via explorer.exe." -ForegroundColor Green
                } catch {
                    Write-Host "Fallback 1 failed: Could not open Camera app via explorer." -ForegroundColor Red
                    
                    # Fallback 2: Launch directly from package path
                    try {
                        $cameraPath = "C:\Windows\SystemApps\Microsoft.WindowsCamera_cw5n1h2txyewy\WindowsCamera.exe"
                        if (Test-Path $cameraPath) {
                            Start-Process -FilePath $cameraPath
                            Write-Host "Fallback: Opened Camera app directly from package path." -ForegroundColor Green
                        } else {
                            Write-Host "Fallback 2 failed: Camera app not found in the expected path." -ForegroundColor Red
                        }
                    } catch {
                        Write-Host "Fallback 2 failed: Unable to launch Camera app from package path." -ForegroundColor Red
                        
                        # Fallback 3: Open shell AppsFolder
                        try {
                            Start-Process -FilePath "shell:AppsFolder\Microsoft.WindowsCamera_cw5n1h2txyewy!App"
                            Write-Host "Fallback: Opened Camera app using shell:AppsFolder." -ForegroundColor Green
                        } catch {
                            Write-Host "Fallback 3 failed: Could not open Camera app using shell:AppsFolder." -ForegroundColor Red
                            
                            # Fallback 4: Suggest alternatives
                            Write-Host "Unable to open the Camera app. Consider using a third-party application or online tools like https://webcamtests.com." -ForegroundColor Red
                        }
                    }
                }
            }
        } else {
            Write-Host "No camera driver detected on this machine." -ForegroundColor Red
        }
    } catch {
        Write-Host "An error occurred while checking for camera drivers: $_" -ForegroundColor Red
    }
}

function Get-SystemInfo {
    Write-Host "`nRefreshing System Information..." -ForegroundColor Yellow    
    Write-Host "`n***** If stuck press ENTER *****" -ForegroundColor Red

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
    for ($i = 0; $i -lt $totalTasks; $i++) {
        $taskName = $tasks[$i].Name
        $task = $tasks[$i].Task

        $percentComplete = [math]::Round((($i + 1) / $totalTasks) * 100)
        Write-Progress -Activity "> System Information >>>>>>>>" `
                       -Status "Processing: $taskName ($($i + 1) of $totalTasks)" `
                       -PercentComplete $percentComplete
        $results += & $task
    }
    Write-Progress -Activity "System Information Completed" -Completed
    Clear-Host

    $MemoryInfo, $CPUInfo, $GPUInfo, $WindowsStatus, $ActivationStatus, $ProductKeys, $DiskInfo = $results

    $ActivationColor = if ($ActivationStatus -match "Licensed|Licenciado") { "Green" } else { "Red" }
    
    $CPUColor = if ($CPUInfo -match "AMD") { "Red" } elseif ($CPUInfo -match "Intel") { "Cyan" } else { "Blue" }
    
    $GPUColor = if ($GPUInfo -match "NVIDIA") { "Green" } elseif ($GPUInfo -match "AMD") { "Red" } elseif ($GPUInfo -match "Intel") { "Cyan" } else { "Gray" }

    # Create a PSCustomObject to return the system information
    return [PSCustomObject]@{
        MemoryInfo         = $MemoryInfo
        CPUInfo            = $CPUInfo
        GPUInfo            = $GPUInfo
        DiskInfo           = $DiskInfo
        ProductKeys        = $ProductKeys
        WindowsStatus      = $WindowsStatus
        ActivationStatus   = $ActivationStatus
        ActivationColor    = $ActivationColor
        CPUColor           = $CPUColor
        GPUColor           = $GPUColor
    }
}