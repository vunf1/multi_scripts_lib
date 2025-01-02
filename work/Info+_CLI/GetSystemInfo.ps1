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
                        $smartData = Get-WmiObject -Namespace "root\WMI" -Class "MSStorageDriver_FailurePredictStatus" |
                            Where-Object { $_.InstanceName -match $diskNumber }

                        if ($smartData -and $smartData.PredictFailure -eq $false) {
                            # If PredictFailure is false, assume 100% health
                            $healthPercentage = "100%"
                        } elseif ($smartData -and $smartData.PredictFailure -eq $true) {
                            # If PredictFailure is true, mark as failing
                            $healthPercentage = "10%"
                            $diskHealth = "Failing"
                        } else {
                            $healthPercentage = "Unknown%"
                        }
                    } else {
                        # Default for HDD: Assuming manual degradation over time
                        $healthPercentage = "100%"
                    }
                } else {
                    # Fallback to SMART attributes if Get-PhysicalDisk fails
                    $smartData = Get-WmiObject -Namespace "root\WMI" -Class "MSStorageDriver_FailurePredictData" |
                        Where-Object { $_.InstanceName -match $diskNumber }
                    if ($smartData) {
                        # SMART attributes interpretation for a dynamic percentage
                        $currentValue = $smartData.VendorSpecific[3]  # Example attribute
                        $thresholdValue = $smartData.VendorSpecific[5]

                        if ($null -ne $currentValue -and $null -ne $thresholdValue -and $thresholdValue -ne 0) {
                            $healthPercentage = [math]::round(($currentValue / $thresholdValue) * 100, 2)
                            $diskHealth = if ($healthPercentage -ge 70) { "Healthy" } elseif ($healthPercentage -ge 40) { "Warning" } else { "Failing" }
                        } else {
                            $diskHealth = "Unknown (Invalid SMART Data)"
                            $healthPercentage = "Unknown%"
                        }
                    } else {
                        $diskHealth = "Unknown (No SMART Data)"
                        $healthPercentage = "Unknown%"
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

function Get-SystemPowerInfo {
    try {
        # Check for power supply details
        $powerSupplies = Get-CimInstance -ClassName Win32_PowerSupply -ErrorAction SilentlyContinue

        if ($powerSupplies -and $powerSupplies.Count -gt 0) {
            $powerInfo = $powerSupplies | ForEach-Object {
                [PSCustomObject]@{
                    Name       = $_.Name
                    Status     = $_.Status
                    Wattage    = if ($null -ne $_.RatedCapacity) { "$($_.RatedCapacity) W" } else { "Unknown" }
                    PowerState = "Connected"
                }
            }
            return $powerInfo
        } else {
            # No external power supply detected
            Get-BatteryInfo
        }
    } catch {        
        Get-BatteryInfo
    }
}

function Get-BatteryInfo {
    try {
        # Attempt to fetch battery info using Win32_Battery
        $batteries = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue

        # Fallback to Win32_PortableBattery if Win32_Battery returns nothing
        if (-not $batteries -or $batteries.Count -eq 0) {
            $batteries = Get-CimInstance -ClassName Win32_PortableBattery -ErrorAction SilentlyContinue
        }

        # Additional failsafe: Try WMI directly
        if (-not $batteries -or $batteries.Count -eq 0) {
            $batteries = Get-WmiObject -Query "SELECT * FROM Win32_Battery" -ErrorAction SilentlyContinue
        }

        # Final failsafe: Check for power settings via the PowerShell API
        if (-not $batteries -or $batteries.Count -eq 0) {
            $batteryStatus = powercfg /batteryreport > $null 2>&1
            $reportPath = "$env:USERPROFILE\battery-report.html"
            if (Test-Path $reportPath) {
                return "Battery information could not be retrieved via standard methods, but a report was generated: $reportPath"
            }
        }

        # If we still have no results, return a descriptive error
        if (-not $batteries -or $batteries.Count -eq 0) {
            return "No batteries detected or accessible on this machine, even after multiple attempts."
        }

        # Map battery information to a formatted output
        $batteryInfo = $batteries | ForEach-Object {
            try {
                [PSCustomObject]@{
                    Name                   = $_.Name
                    Status                 = $_.Status
                    "Charge Remaining (%)" = if ($null -ne $_.EstimatedChargeRemaining) { "$($_.EstimatedChargeRemaining)%" } else { "N/A" }
                    "Run Time (min)"       = if ($null -ne $_.EstimatedRunTime) { $_.EstimatedRunTime } else { "N/A" }
                    Chemistry              = switch ($_.Chemistry) {
                        1 { 'Other' }
                        2 { 'Unknown' }
                        3 { 'Lead Acid' }
                        4 { 'Nickel Cadmium' }
                        5 { 'Nickel Metal Hydride' }
                        6 { 'Lithium-ion' }
                        7 { 'Zinc Air' }
                        8 { 'Lithium Polymer' }
                        Default { 'Not Specified' }
                    }
                    "Health (%)"           = Measure-BatteryHealth -Battery $_
                }
            } catch {
                # If data retrieval fails for a battery, return default values
                [PSCustomObject]@{
                    Name                   = "Unknown"
                    Status                 = "Data Unavailable"
                    "Charge Remaining (%)" = "N/A"
                    "Run Time (min)"       = "N/A"
                    Chemistry              = "N/A"
                    "Health (%)"           = "Unknown"
                }
            }
        }

        # Output the battery information
        return $batteryInfo
    } catch {
        # Handle errors during retrieval
        return "An error occurred while retrieving battery information: $($_.Exception.Message)"
    }
}

function Measure-BatteryHealth {
    param (
        [Parameter(Mandatory = $true)]
        $Battery
    )

    try {
        if ($Battery.DesignCapacity -and $Battery.FullChargeCapacity -and
            $Battery.DesignCapacity -gt 0 -and $Battery.FullChargeCapacity -gt 0) {
            return [math]::round(($Battery.FullChargeCapacity / $Battery.DesignCapacity) * 100, 2) + "%"
        } else {
            return "Unknown"
        }
    } catch {
        return "Unknown"
    }
}

# Main function to check power information
function Check-SystemPower {
    $powerSupplyInfo = Get-SystemPowerInfo

    if ($powerSupplyInfo -is [string]) {
        # If no power supply detected, check for batteries
        Write-Host $powerSupplyInfo
        $batteryInfo = Get-BatteryInfo
        Write-Output $batteryInfo
    } else {
        # Display power supply information
        Write-Output $powerSupplyInfo
    }
}

# Example usage:
Check-SystemPower


# Define helper functions for specific tasks
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
        } else {
            throw "Primary method failed"
        }
    
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

function Get-SystemInfo {
    # Display a message to indicate the start of information gathering
    Write-Host "`nRefreshing System Information..." -ForegroundColor Yellow

    # Define the tasks to gather system information
    $tasks = @(
        { return Get-TotalSticksRam },
        { return Get-ProcessorInfo },
        { return Get-GPUInfo },
        { return Get-WindowsVersion },
        { return Get-ActivationDetails },
        #{ return Get-SystemPowerInfo },
        { return Get-DiskInfo }
    )

    # Collect the results by invoking each task
    $results = $tasks | ForEach-Object { &$_ }
    # Map results to respective variables
    $MemoryInfo, $CPUInfo, $GPUInfo, $WindowsStatus, $ActivationStatus, $BatteryInfo, $DiskInfo = $results

    # Determine colors for CPU, GPU, and activation status
    $ActivationColor = if ($ActivationStatus -match "Licensed|Licenciado") { 
        "Green" 
    } else { 
        "Red" 
    }
    
    $CPUColor = if ($CPUInfo -match "AMD") { 
        "Red" 
    } elseif ($CPUInfo -match "Intel") { 
        "Cyan" 
    } else { 
        "Blue" # Default fallback for unexpected CPUInfo
    }
    
    $GPUColor = if ($GPUInfo -match "NVIDIA") { 
        "Green" 
    } elseif ($GPUInfo -match "AMD") { 
        "Red" 
    } elseif ($GPUInfo -match "Intel") { 
        "Cyan" 
    } else { 
        "Gray" # Default fallback for unexpected GPUInfo
    }
    Clear-Host

    # Create a PSCustomObject to return the system information
    return [PSCustomObject]@{
        MemoryInfo         = $MemoryInfo
        CPUInfo            = $CPUInfo
        GPUInfo            = $GPUInfo
        DiskInfo           = $DiskInfo
        BatteryInfo        = $BatteryInfo
        WindowsStatus      = $WindowsStatus
        ActivationStatus   = $ActivationStatus
        ActivationColor    = $ActivationColor
        CPUColor           = $CPUColor
        GPUColor           = $GPUColor
    }
}
