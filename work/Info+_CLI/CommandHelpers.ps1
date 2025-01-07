$global:executables = @{
    "Keyboard" = "\\server\tools\#Keyboard Test.exe"
    "Battery"  = "\\server\tools\Tools\batteryinfoview\BatteryInfoView.exe"
}
function Start-ExecutableBackground {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Executables
    )
    
    $KeyboardDisplay= "Keyboard" # Hardcoded - Value is not been saved $DisplayName or $FilePath when tryCatch need futher debugging

    $BatteryDisplay= "Battery" # Hardcoded - Value is not been saved $DisplayName or $FilePath when tryCatch need futher debugging

    $KeyboardFilePath = $Executables[$KeyboardDisplay]
    $BatteryFilePath = $Executables[$BatteryDisplay]

    # Run each executable in its own runspace
    $scriptBlock = {
        param ($KeyboardDisplay, $KeyboardFilePath)

        # Add the required .NET assemblies and the function within the runspace
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        # Function to show a custom message box, hardcoded in here because when creating new instance of new threads it does not have access to the external function, need debug to find a way  
        function Show-CustomMessageBox {
            param (
                [string]$Message,
                [string]$Title = "Notification",
                [ValidateSet("Information", "Warning", "Error", "Critical")]
                [string]$Type = "Information",
                [ValidateSet("OK", "YesNo", "YesNoCancel", "RetryCancel", "AbortRetryIgnore")]
                [string]$ButtonLayout = "YesNo",
                [string]$CustomIconPath = "$PSScriptRoot\images\icons\icon2.ico" # Path to your default icon
            )
        
            # Add required .NET assembly for Windows Forms
            Add-Type -AssemblyName System.Windows.Forms
            Add-Type -AssemblyName System.Drawing
        
            # Create the form
            $form = New-Object System.Windows.Forms.Form
            $form.Text = $Title
            $form.StartPosition = "CenterScreen"
            $form.Width = 270
            $form.Height = 150
            $form.FormBorderStyle = "FixedDialog"
            $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30) # Dark background
            $form.MaximizeBox = $false
            $form.MinimizeBox = $false
            $form.ShowInTaskbar = $true
            $form.Tag = $null # Use the Tag property to store the response
        
            # Set the custom icon
            if (Test-Path $CustomIconPath) {
                $form.Icon = New-Object System.Drawing.Icon($CustomIconPath)
            } else {
                Write-Host "Custom icon not found at $CustomIconPath. Using default icon." -ForegroundColor Yellow
            }
        
            # Create the message label
            $label = New-Object System.Windows.Forms.Label
            $label.Text = $Message
            $label.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
            $label.ForeColor = [System.Drawing.Color]::White
            $label.TextAlign = "MiddleCenter"
            $label.Dock = "Top"
            $label.Height = 50
            $form.Controls.Add($label)
        
            # Create a FlowLayoutPanel to center buttons
            $buttonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
            $buttonPanel.FlowDirection = "LeftToRight"
            $buttonPanel.WrapContents = $false
            $buttonPanel.Anchor = "Bottom"
            $buttonPanel.Dock = "Bottom"
            $buttonPanel.Padding = New-Object System.Windows.Forms.Padding(10)
            $buttonPanel.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
            $buttonPanel.AutoSize = $true
            $buttonPanel.AutoSizeMode = "GrowAndShrink"
            $form.Controls.Add($buttonPanel)
        
            # Helper function to create buttons
            function CreateButton($text, $width, $height, $clickAction) {
                $button = New-Object System.Windows.Forms.Button
                $button.Text = $text
                $button.Font = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Regular)
                $button.BackColor = [System.Drawing.Color]::White
                $button.ForeColor = [System.Drawing.Color]::Black
                $button.Width = $width
                $button.Height = $height
                $button.Margin = New-Object System.Windows.Forms.Padding(5) # Adds default spacing between buttons
                $button.Add_Click($clickAction)
                return $button
            }
        
            # Add buttons based on the ButtonLayout parameter
            switch ($ButtonLayout) {
                "OK" {
                    $okButton = CreateButton "OK" 80 30 { $form.Tag = "OK"; $form.Close() }
                    $okButton.Margin = New-Object System.Windows.Forms.Padding(80, 0, 10, 0) 
                    $buttonPanel.Controls.Add($okButton)
                }
                "YesNo" {
                    $yesButton = CreateButton "Yes" 80 30 { $form.Tag = "Yes"; $form.Close() }
                    $yesButton.Margin = New-Object System.Windows.Forms.Padding(10, 0, 50, 0) 
                    $noButton = CreateButton "No" 80 30 { $form.Tag = "No"; $form.Close() }
                    $noButton.Margin = New-Object System.Windows.Forms.Padding(10, 0, 50, 0) 
                    $buttonPanel.Controls.Add($yesButton)
                    $buttonPanel.Controls.Add($noButton)
                }
                "YesNoCancel" {
                    $yesButton = CreateButton "Yes" 70 30 { $form.Tag = "Yes"; $form.Close() }
                    $noButton = CreateButton "No" 70 30 { $form.Tag = "No"; $form.Close() }
                    $cancelButton = CreateButton "Cancel" 70 30 { $form.Tag = "Cancel"; $form.Close() }
                    $buttonPanel.Controls.Add($yesButton)
                    $buttonPanel.Controls.Add($noButton)
                    $buttonPanel.Controls.Add($cancelButton)
                }
            }
        
            # Center content dynamically on resize
            $form.Add_SizeChanged({
                $label.Width = $form.ClientSize.Width
                $buttonPanel.Width = $form.ClientSize.Width
                $buttonPanel.Left = ($form.ClientSize.Width - $buttonPanel.Width) / 2
            })
        
            # Show the form and return the user's response
            $form.ShowDialog() | Out-Null
            return $form.Tag
        }


        try {
            if (Test-Path $KeyboardFilePath) {
                # Show confirmation message box
                $response = Show-CustomMessageBox -Message "Do you want to launch Keyboard $KeyboardFilePath?" `
                                                    -Title "Confirmation" `
                                                    -ButtonLayout "YesNo"

                if ($response -eq "Yes") {
                    Start-Process -FilePath $KeyboardFilePath
                    Write-Host "Launching: $KeyboardDisplay from $KeyboardFilePath"
                } elseif ($response -eq "No") {
                    Write-Host "User chose not to launch: $KeyboardDisplay"
                } else {
                    Write-Host "Unexpected response or dialog closed."
                }
            } else {
                Show-CustomMessageBox -Message "File not found: $KeyboardFilePath" `
                                        -Title "Error" `
                                        -ButtonLayout "OK"
            }
        } catch {
            Show-CustomMessageBox -Message "Error launching ${DisplayName}: $_" `
                                    -Title "Critical Error" `
                                    -ButtonLayout "OK"
        }
    }
    # Start the runspace for each executable
    $runspace = [powershell]::Create()
    $runspace.AddScript($scriptBlock).AddArgument($DisplayName).AddArgument($KeyboardFilePath)

    # Set up the asynchronous invocation
    $asyncResult = $runspace.BeginInvoke() | Out-Null  # Suppress any output

    # Use a job to monitor and clean up the runspace
    Start-Job -ScriptBlock {
        param ($runspace, $asyncResult)

        try {
            # Wait for the runspace to complete
            $null = $runspace.EndInvoke($asyncResult)  # Suppress any return value
        } finally {
            # Clean up the runspace
            $runspace.Dispose()
            Write-Host "Cleaned up runspace for $($runspace.InstanceId)" -ForegroundColor Green
        }
    } -ArgumentList $runspace, $asyncResult | Out-Null  # Suppress job output
   



        $scriptBlockBattery = {
        param ($BatteryDisplay, $BatteryFilePath)

        # Add the required .NET assemblies and the function within the runspace
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        # Function to show a custom message box, hardcoded in here because when creating new instance of new threads it does not have access to the external function, need debug to find a way  
        function Show-CustomMessageBox {
            param (
                [string]$Message,
                [string]$Title = "Notification",
                [ValidateSet("Information", "Warning", "Error", "Critical")]
                [string]$Type = "Information",
                [ValidateSet("OK", "YesNo", "YesNoCancel", "RetryCancel", "AbortRetryIgnore")]
                [string]$ButtonLayout = "YesNo",
                [string]$CustomIconPath = "$PSScriptRoot\images\icons\icon2.ico" # Path to your default icon
            )
        
            # Add required .NET assembly for Windows Forms
            Add-Type -AssemblyName System.Windows.Forms
            Add-Type -AssemblyName System.Drawing
        
            # Create the form
            $form = New-Object System.Windows.Forms.Form
            $form.Text = $Title
            $form.StartPosition = "CenterScreen"
            $form.Width = 270
            $form.Height = 150
            $form.FormBorderStyle = "FixedDialog"
            $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30) # Dark background
            $form.MaximizeBox = $false
            $form.MinimizeBox = $false
            $form.ShowInTaskbar = $true
            $form.Tag = $null # Use the Tag property to store the response
        
            # Set the custom icon
            if (Test-Path $CustomIconPath) {
                $form.Icon = New-Object System.Drawing.Icon($CustomIconPath)
            } else {
                Write-Host "Custom icon not found at $CustomIconPath. Using default icon." -ForegroundColor Yellow
            }
        
            # Create the message label
            $label = New-Object System.Windows.Forms.Label
            $label.Text = $Message
            $label.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
            $label.ForeColor = [System.Drawing.Color]::White
            $label.TextAlign = "MiddleCenter"
            $label.Dock = "Top"
            $label.Height = 50
            $form.Controls.Add($label)
        
            # Create a FlowLayoutPanel to center buttons
            $buttonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
            $buttonPanel.FlowDirection = "LeftToRight"
            $buttonPanel.WrapContents = $false
            $buttonPanel.Anchor = "Bottom"
            $buttonPanel.Dock = "Bottom"
            $buttonPanel.Padding = New-Object System.Windows.Forms.Padding(10)
            $buttonPanel.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
            $buttonPanel.AutoSize = $true
            $buttonPanel.AutoSizeMode = "GrowAndShrink"
            $form.Controls.Add($buttonPanel)
        
            # Helper function to create buttons
            function CreateButton($text, $width, $height, $clickAction) {
                $button = New-Object System.Windows.Forms.Button
                $button.Text = $text
                $button.Font = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Regular)
                $button.BackColor = [System.Drawing.Color]::White
                $button.ForeColor = [System.Drawing.Color]::Black
                $button.Width = $width
                $button.Height = $height
                $button.Margin = New-Object System.Windows.Forms.Padding(5) # Adds default spacing between buttons
                $button.Add_Click($clickAction)
                return $button
            }
        
            # Add buttons based on the ButtonLayout parameter
            switch ($ButtonLayout) {
                "OK" {
                    $okButton = CreateButton "OK" 80 30 { $form.Tag = "OK"; $form.Close() }
                    $okButton.Margin = New-Object System.Windows.Forms.Padding(80, 0, 10, 0) 
                    $buttonPanel.Controls.Add($okButton)
                }
                "YesNo" {
                    $yesButton = CreateButton "Yes" 80 30 { $form.Tag = "Yes"; $form.Close() }
                    $yesButton.Margin = New-Object System.Windows.Forms.Padding(10, 0, 50, 0) 
                    $noButton = CreateButton "No" 80 30 { $form.Tag = "No"; $form.Close() }
                    $noButton.Margin = New-Object System.Windows.Forms.Padding(10, 0, 50, 0) 
                    $buttonPanel.Controls.Add($yesButton)
                    $buttonPanel.Controls.Add($noButton)
                }
                "YesNoCancel" {
                    $yesButton = CreateButton "Yes" 70 30 { $form.Tag = "Yes"; $form.Close() }
                    $noButton = CreateButton "No" 70 30 { $form.Tag = "No"; $form.Close() }
                    $cancelButton = CreateButton "Cancel" 70 30 { $form.Tag = "Cancel"; $form.Close() }
                    $buttonPanel.Controls.Add($yesButton)
                    $buttonPanel.Controls.Add($noButton)
                    $buttonPanel.Controls.Add($cancelButton)
                }
            }
        
            # Center content dynamically on resize
            $form.Add_SizeChanged({
                $label.Width = $form.ClientSize.Width
                $buttonPanel.Width = $form.ClientSize.Width
                $buttonPanel.Left = ($form.ClientSize.Width - $buttonPanel.Width) / 2
            })
        
            # Show the form and return the user's response
            $form.ShowDialog() | Out-Null
            return $form.Tag
        }


        try {
            if (Test-Path $BatteryFilePath) {
                # Show confirmation message box
                
                Start-Process -FilePath $BatteryFilePath
                Write-Host "Launching: $BatteryDisplay from $BatteryFilePath"
            }
        } catch {
            Show-CustomMessageBox -Message "Error launching ${BatteryDisplay}: $_" `
                                    -Title "Critical Error" `
                                    -ButtonLayout "OK"
        }
    }
    # Start the runspace for each executable
    $runspace = [powershell]::Create()
    $runspace.AddScript($scriptBlockBattery).AddArgument($BatteryDisplay).AddArgument($BatteryFilePath)

    # Set up the asynchronous invocation
    $asyncResult = $runspace.BeginInvoke() | Out-Null  # Suppress any output

    # Use a job to monitor and clean up the runspace
    Start-Job -ScriptBlock {
        param ($runspace, $asyncResult)

        try {
            # Wait for the runspace to complete
            $null = $runspace.EndInvoke($asyncResult)  # Suppress any return value
        } finally {
            # Clean up the runspace
            $runspace.Dispose()
            Write-Host "Cleaned up runspace for $($runspace.InstanceId)" -ForegroundColor Green
        }
    } -ArgumentList $runspace, $asyncResult | Out-Null  # Suppress job output
}
function Start-Files {
    Start-ExecutableBackground -Executables $global:executables
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
                    $response = Show-CustomMessageBox -Message "Are you sure you want to disable Bitlocker?" `
                        -Title "Confirmation" `
                        -ButtonLayout "YesNo"

                    if ($response -ne "Yes") {
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
