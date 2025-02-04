if($Local){
    $global:executables = @{    
        "Keyboard" = "C:\Users\Utilizador\NordLocker_338342\exc\scripts\various_scripts\multi_scripts_lib\work\Info+_CLI"
        "Battery"  = "C:\Users\Utilizador\Downloads\Adobe-GenP-3.4.2-CGP"
        "Disk"     = "C:\Users\Utilizador\Downloads\RAID_SATA"
    }

} else {
    $global:executables = @{    
        "Keyboard" = "\\server\tools\#Keyboard Test.exe"
        "Battery"  = "\\server\tools\Tools\batteryinfoview\BatteryInfoView.exe"
        "Disk"     = "\\server\tools\Tools\CrystalDisk\CrystalDiskInfo.exe"
    }    
}
function Start-ScriptBlockInRunspace {
    param (
        [scriptblock]$ScriptBlock,
        [array]$Arguments = @()
    )

    try {
        
        $runspace = [powershell]::Create()
        $null = $runspace.AddScript($ScriptBlock)

        if ($Arguments) {
            foreach ($arg in $Arguments) {
                $null = $runspace.AddArgument($arg)
            }
        }

        # Begin asynchronous execution , removes the need to wait for the runspace to complete, no CLI output is shown complement of $null
        $runspace.BeginInvoke() | Out-Null

    } catch {
        Write-Host "An error occurred while starting the runspace: $_" -ForegroundColor Red
    }
}


function Start-ExecutableBackground {    
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Executables
    )

    $KeyboardDisplay= "Keyboard" # Hardcoded - Value is not been saved $DisplayName or $FilePath when tryCatch need futher debugging

    $BatteryDisplay= "Battery" # Hardcoded - Value is not been saved $DisplayName or $FilePath when tryCatch need futher debugging

    $DiskDisplay= "Disk" # Hardcoded - Value is not been saved $DisplayName or $FilePath when tryCatch need futher debugging

    $KeyboardFilePath = $Executables[$KeyboardDisplay]
    $BatteryFilePath = $Executables[$BatteryDisplay]
    $DiskFilePath = $Executables[$DiskDisplay]
    # Run each executable in its own runspace
    $scriptBlockKeyboard = {
        param ($KeyboardDisplay, $KeyboardFilePath)
    
        # Load required .NET assemblies
        Add-Type -AssemblyName System.Windows.Forms
    
        # Function to show a MessageBox and ensure UI thread waits
        function Show-Confirmation {
            param (
                [string]$message,
                [string]$title
            )
            
            # Create a hidden form to enforce STA mode
            $form = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true; Visible = $false }
            
            # Show the MessageBox in a proper STA thread
            $response = [System.Windows.Forms.MessageBox]::Show($form, $message, $title, 
                [System.Windows.Forms.MessageBoxButtons]::YesNo, 
                [System.Windows.Forms.MessageBoxIcon]::Question)
            
            return $response
        }
    
        function Show-Info {
            param (
                [string]$message,
                [string]$title
            )
            $form = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true; Visible = $false }
            return [System.Windows.Forms.MessageBox]::Show($form, $message, $title, 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    
        function Show-Warning {
            param (
                [string]$message,
                [string]$title
            )
            $form = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true; Visible = $false }
            return [System.Windows.Forms.MessageBox]::Show($form, $message, $title, 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    
        try {
            if (Test-Path $KeyboardFilePath) {
                # Show confirmation MessageBox in the main thread
                $response = Show-Confirmation -message "Do you want to launch Keyboard?" -title "Confirmation"
    
                # Wait for user response
                if ($response -eq [System.Windows.Forms.DialogResult]::Yes) {
                    Start-Process -FilePath $KeyboardFilePath
                    Write-Host " Launching: $KeyboardDisplay from $KeyboardFilePath"
                } elseif ($response -eq [System.Windows.Forms.DialogResult]::No) {
                    Write-Host " User chose not to launch: $KeyboardDisplay"
                } else {
                    Write-Host " Unexpected response or dialog closed."
                }
            } else {
                Show-Info -message " File not found: $KeyboardFilePath" -title "Error"
            }
        } catch {
            Show-Warning -message " Error launching ${KeyboardDisplay}: $_" -title "Critical Error"
        }
    }
    
    

    $scriptBlockBattery = {
        param ($BatteryDisplay, $BatteryFilePath)

        # Add the required .NET assemblies and the function within the runspace
        Add-Type -AssemblyName System.Windows.Forms
        # Function to show a custom message box, hardcoded in here because when creating new instance of new threads it does not have access to the external function, need debug to find a way  
        function Show-Confirmation {
            param (
                [string]$message,
                [string]$title
            )
            
            return [System.Windows.Forms.MessageBox]::Show(
                $message,
                $title,
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
        }
        function Show-Info {
            param (
                [string]$message,
                [string]$title
            )
        
            return [System.Windows.Forms.MessageBox]::Show(
                $message,
                $title,
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }

        function Show-Warning {
            param (
                [string]$message,
                [string]$title
            )
        
            return [System.Windows.Forms.MessageBox]::Show(
                $message,
                $title,
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
        }


        try {
            if (Test-Path $BatteryFilePath) {
                # Show confirmation message box
                
                Start-Process -FilePath $BatteryFilePath
                Write-Host "Launching: $BatteryDisplay from $BatteryFilePath"
            } else {
                Show-Warning -message "File not found: $BatteryFilePath" `
                                        -title "Error" 
            }
        } catch {
            Show-Warning -message "Error launching ${BatteryDisplay}: $_" `
                                    -title "Critical Error" 
        }
    }

    $scriptBlockDisk = {
        param ($DiskDisplay, $DiskFilePath)

        # Add the required .NET assemblies and the function within the runspace
        Add-Type -AssemblyName System.Windows.Forms
        # Function to show a custom message box, hardcoded in here because when creating new instance of new threads it does not have access to the external function, need debug to find a way  
        function Show-Confirmation {
            param (
                [string]$message,
                [string]$title
            )
            
            return [System.Windows.Forms.MessageBox]::Show(
                $message,
                $title,
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
        }
        function Show-Info {
            param (
                [string]$message,
                [string]$title
            )
        
            return [System.Windows.Forms.MessageBox]::Show(
                $message,
                $title,
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }

        function Show-Warning {
            param (
                [string]$message,
                [string]$title
            )
        
            return [System.Windows.Forms.MessageBox]::Show(
                $message,
                $title,
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
        }


        try {
            if (Test-Path $DiskFilePath) {
                # Show confirmation message box
                
                Start-Process -FilePath $DiskFilePath
                Write-Host "Launching: $DiskDisplay from $DiskFilePath"
            } else {
                Show-Warning -message "File not found: $DiskFilePath" `
                                        -title "Error" 
            }
        } catch {
            Show-Warning -message "Error launching ${DiskDisplay}: $_" `
                                    -title "Critical Error" 
        }
    }

    # Start the keyboard script block
    Start-ScriptBlockInRunspace -ScriptBlock $scriptBlockKeyboard -Arguments @($KeyboardDisplay, $KeyboardFilePath)

    # Start the battery script block
    Start-ScriptBlockInRunspace -ScriptBlock $scriptBlockBattery -Arguments @($BatteryDisplay, $BatteryFilePath)

    # Start the disk script block
    Start-ScriptBlockInRunspace -ScriptBlock $scriptBlockDisk -Arguments @($DiskDisplay, $DiskFilePath)
}
function Start-Files {
    Start-ExecutableBackground -Executables $global:executables
    if(-not $Debug){
        Clear-Host
    }
}
function Get-EdgePath {
    # Try to find msedge.exe in the system's PATH
    $edgePath = (Get-Command "msedge.exe" -ErrorAction SilentlyContinue).Source

    # If not found, attempt default installation paths
    if (-not $edgePath) {
        $defaultPaths = @(
            "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
            "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
        )
        foreach ($path in $defaultPaths) {
            if (Test-Path $path) {
                $edgePath = $path
                break
            }
        }
    }

    # Return the found path or null if not found
    return $edgePath
}

function Open-Executable {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    try {
        if ($global:executables.ContainsKey($Key)) {
            $filePath = $global:executables[$Key]

            if (Test-Path -Path $filePath) {
                Start-Process -FilePath $filePath
            } else {
                Write-Host "$Key executable not found at $filePath." -ForegroundColor Red
            }
        } else {
            Write-Host "Invalid key provided: $Key. Available keys are: $($global:executables.Keys -join ', ')." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "An error occurred while attempting to open ${Key}: $_" -ForegroundColor Red
    }
}

function Disable-BitLockerOnAllDrives {
    try {
        $passwordCachePath = "$env:USERPROFILE\Documents\BitLockerPasswords.txt"

        $bitlockerDrives = Get-BitLockerVolume | Where-Object { $_.ProtectionStatus -eq 1 }

        if (-not $bitlockerDrives) {
            Write-Host "No drives with BitLocker protection found." -ForegroundColor Yellow
            return
        }

        Write-Host "Starting BitLocker deactivation on all drives..." -ForegroundColor Green

        $totalDrives = $bitlockerDrives.Count
        $progressCount = 0

        foreach ($drive in $bitlockerDrives) {
            $progressCount++
            $percentComplete = [math]::Round(($progressCount / $totalDrives) * 100)

            Write-Progress -Activity "Disabling BitLocker" `
                           -Status "Processing drive: $($drive.MountPoint) ($progressCount of $totalDrives)" `
                           -PercentComplete $percentComplete

            Write-Host "Disabling BitLocker on drive $($drive.MountPoint)..." -ForegroundColor Cyan
            try {
                Disable-BitLocker -MountPoint $drive.MountPoint -ErrorAction Stop
            } catch {
                Write-Host "Failed to disable BitLocker on drive $($drive.MountPoint). Attempting manual decryption..." -ForegroundColor Yellow

                # Check if a cached password is available
                $cachedPassword = $null
                if (Test-Path $passwordCachePath) {
                    $cachedPasswords = Get-Content $passwordCachePath | ConvertFrom-Json -ErrorAction SilentlyContinue
                    $cachedPassword = $cachedPasswords | Where-Object { $_.MountPoint -eq $drive.MountPoint } | Select-Object -ExpandProperty Password -ErrorAction SilentlyContinue
                }

                if (-not $cachedPassword) {
                    # Prompt for the password if not cached
                    Write-Host "No cached password found for drive $($drive.MountPoint)." -ForegroundColor Yellow
                    $securePassword = Read-Host "Enter the password for drive $($drive.MountPoint)" -AsSecureString
                    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))

                    # Save the password to the cache file
                    $newEntry = @{ MountPoint = $drive.MountPoint; Password = $plainPassword }
                    $cachedPasswords += $newEntry
                    $cachedPasswords | ConvertTo-Json | Set-Content $passwordCachePath -Encoding UTF8
                    Write-Host "Password saved successfully for drive $($drive.MountPoint)." -ForegroundColor Green

                    # Prompt for confirmation to continue
                    $response = Show-Confirmation -message "Are you sure you want to disable Bitlocker?" `
                        -title "Confirmation"

                    if ($response -ne [System.Windows.Forms.DialogResult]::Yes) {
                        Write-Host "Operation cancelled by the user for drive $($drive.MountPoint)." -ForegroundColor Red
                        return
                    }
                } else {
                    $plainPassword = $cachedPassword
                }

                # Attempt to unlock the drive
                try {
                    Unlock-BitLocker -MountPoint $drive.MountPoint -Password (ConvertTo-SecureString $plainPassword -AsPlainText -Force)
                    Write-Host "Drive $($drive.MountPoint) unlocked successfully." -ForegroundColor Green

                    # Start decryption manually
                    Resume-BitLocker -MountPoint $drive.MountPoint
                    Write-Host "Decryption started for drive $($drive.MountPoint)." -ForegroundColor Green
                } catch {
                    Write-Host "Unable to unlock or decrypt drive $($drive.MountPoint): $_" -ForegroundColor Red
                }
            }
        }

        Write-Host "Waiting for decryption to complete..." -ForegroundColor Yellow

        while ($bitlockerDrives | Where-Object { $_.EncryptionPercentage -lt 100 }) {
            $bitlockerDrives = Get-BitLockerVolume | Where-Object { $_.ProtectionStatus -eq 0 -and $_.EncryptionPercentage -lt 100 }
            
            foreach ($drive in $bitlockerDrives) {
                $percentComplete = $drive.EncryptionPercentage
                Write-Progress -Activity "Decrypting Drives" `
                               -Status "Decrypting drive: $($drive.MountPoint) ($percentComplete% complete)" `
                               -PercentComplete $percentComplete
            }

            Start-Sleep -Seconds 5
        }

        # Clear progress bar
        Write-Progress -Activity "Decrypting Drives" -Completed

        Write-Host "BitLocker deactivation completed on all drives." -ForegroundColor Green
    } catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
    }
}


$WindowsGenericKeys = @(
    # Windows 11 RTM Generic Keys
    @{ Edition = "Windows 11 Home"; Key = "YTMG3-N6DKC-DKB77-7M9GH-8HVX7" },
    @{ Edition = "Windows 11 Home N"; Key = "4CPRK-NM3K3-X6XXQ-RXX86-WXCHW" },
    @{ Edition = "Windows 11 Home Single Language"; Key = "BT79Q-G7N6G-PGBYW-4YWX6-6F4BT" },
    @{ Edition = "Windows 11 Home Country Specific"; Key = "N2434-X9D7W-8PF6X-8DV9T-8TYMD" },
    @{ Edition = "Windows 11 Pro"; Key = "VK7JG-NPHTM-C97JM-9MPGT-3V66T" },
    @{ Edition = "Windows 11 Pro N"; Key = "2B87N-8KFHP-DKV6R-Y2C8J-PKCKT" },
    @{ Edition = "Windows 11 Pro for Workstations"; Key = "DXG7C-N36C4-C4HTG-X4T3X-2YV77" },
    @{ Edition = "Windows 11 Pro for Workstations N"; Key = "WYPNQ-8C467-V2W6J-TX4WX-WT2RQ" },
    @{ Edition = "Windows 11 Pro Education"; Key = "8PTT6-RNW4C-6V7J2-C2D3X-MHBPB" },
    @{ Edition = "Windows 11 Pro Education N"; Key = "GJTYN-HDMQY-FRR76-HVGC7-QPF8P" },
    @{ Edition = "Windows 11 Education"; Key = "YNMGQ-8RYV3-4PGQ3-C8XTP-7CFBY" },
    @{ Edition = "Windows 11 Education N"; Key = "84NGF-MHBT6-FXBX8-QWJK7-DRR8H" },
    @{ Edition = "Windows 11 Enterprise"; Key = "XGVPP-NMH47-7TTHJ-W3FW7-8HV2C" },
    @{ Edition = "Windows 11 Enterprise N"; Key = "WGGHN-J84D6-QYCPR-T7PJ7-X766F" },
    @{ Edition = "Windows 11 Enterprise G"; Key = "FW7NV-4T673-HF4VX-9X4MM-B4H4T" },
    @{ Edition = "Windows 11 Enterprise LTSC 2019"; Key = "M7XTQ-FN8P6-TTKYV-9D4CC-J462D" },
    @{ Edition = "Windows 11 Enterprise N LTSC 2019"; Key = "92NFX-8DJQP-P6BBQ-THF9C-7CG2H" },
    
    # Windows 11 KMS Client Product Keys
    @{ Edition = "Windows 11 Home"; Key = "TX9XD-98N7V-6WMQ6-BX7FG-H8Q99" },
    @{ Edition = "Windows 11 Home N"; Key = "3KHY7-WNT83-DGQKR-F7HPR-844BM" },
    @{ Edition = "Windows 11 Home Single Language"; Key = "7HNRX-D7KGG-3K4RQ-4WPJ4-YTDFH" },
    @{ Edition = "Windows 11 Home Country Specific"; Key = "PVMJN-6DFY6-9CCP6-7BKTT-D3WVR" },
    @{ Edition = "Windows 11 Pro"; Key = "W269N-WFGWX-YVC9B-4J6C9-T83GX" },
    @{ Edition = "Windows 11 Pro N"; Key = "MH37W-N47XK-V7XM9-C7227-GCQG9" },
    @{ Edition = "Windows 11 Pro for Workstations"; Key = "NRG8B-VKK3Q-CXVCJ-9G2XF-6Q84J" },
    @{ Edition = "Windows 11 Pro for Workstations N"; Key = "9FNHH-K3HBT-3W4TD-6383H-6XYWF" },
    @{ Edition = "Windows 11 Pro Education"; Key = "6TP4R-GNPTD-KYYHQ-7B7DP-J447Y" },
    @{ Edition = "Windows 11 Pro Education N"; Key = "YVWGF-BXNMC-HTQYQ-CPQ99-66QFC" },
    @{ Edition = "Windows 11 Education"; Key = "NW6C2-QMPVW-D7KKK-3GKT6-VCFB2" },
    @{ Edition = "Windows 11 Education N"; Key = "2WH4N-8QGBV-H22JP-CT43Q-MDWWJ" },
    @{ Edition = "Windows 11 Enterprise"; Key = "NPPR9-FWDCX-D2C8J-H872K-2YT43" },
    @{ Edition = "Windows 11 Enterprise N"; Key = "DPH2V-TTNVB-4X9Q3-TJR4H-KHJW4" },
    @{ Edition = "Windows 11 Enterprise G"; Key = "YYVX9-NTFWV-6MDM3-9PT4T-4M68B" },
    @{ Edition = "Windows 11 Enterprise LTSC 2019"; Key = "M7XTQ-FN8P6-TTKYV-9D4CC-J462D" },

    # Windows 10 KMS Client Product Keys
    @{ Edition = "Windows 10 Home"; Key = "TX9XD-98N7V-6WMQ6-BX7FG-H8Q99" },
    @{ Edition = "Windows 10 Home N"; Key = "3KHY7-WNT83-DGQKR-F7HPR-844BM" },
    @{ Edition = "Windows 10 Pro"; Key = "W269N-WFGWX-YVC9B-4J6C9-T83GX" },
    @{ Edition = "Windows 10 Pro N"; Key = "MH37W-N47XK-V7XM9-C7227-GCQG9" },
    @{ Edition = "Windows 10 Pro for Workstations"; Key = "NRG8B-VKK3Q-CXVCJ-9G2XF-6Q84J" },
    @{ Edition = "Windows 10 Enterprise LTSC 2019"; Key = "M7XTQ-FN8P6-TTKYV-9D4CC-J462D" },
    @{ Edition = "Windows 10 Enterprise N LTSC 2019"; Key = "92NFX-8DJQP-P6BBQ-THF9C-7CG2H" },

    # Windows 8.x Generic Keys
    @{ Edition = "Windows 8.1 Pro"; Key = "GCRJD-8NW9H-F2CDX-CCM8D-9D6T9" },
    @{ Edition = "Windows 8.1 Pro N"; Key = "HMCNV-VVBFX-7HMBH-CTY9B-B4FXY" },
    @{ Edition = "Windows 8 Pro"; Key = "NG4HW-VH26C-733KW-K6F98-J8CK4" },
    @{ Edition = "Windows 8 Pro N"; Key = "XCVCF-2NXM9-723PB-MHCB7-2RYQQ" },

    # Windows Server KMS Client Product Keys
    @{ Edition = "Windows Server 2022 Datacenter"; Key = "WX4NM-KYWYW-QJJR4-XV3QB-6VM33" },
    @{ Edition = "Windows Server 2019 Datacenter"; Key = "WMDGN-G9PQG-XVVXX-R3X43-63DFG" },
    @{ Edition = "Windows Server 2016 Datacenter"; Key = "CB7KF-BWN84-R7R2Y-793K2-8XDDG" }
)