# Script to Disable or Show All Touchscreen-Related HID Devices
# Run this script as Administrator

# Menu-based script
function Show-Menu {
    Clear-Host
    Write-Output "====================================="
    Write-Output " Touchscreen HID Management Script "
    Write-Output "====================================="
    Write-Output "1. Show all touchscreen-related HID devices"
    Write-Output "2. Disable all touchscreen-related HID devices"
    Write-Output "3. Disable a specific touchscreen-related HID device"
    Write-Output "4. Exit"
    Write-Output "====================================="
}

# Function to find and optionally disable touchscreen-related HID devices
function Handle-Touchscreen {
    param (
        [switch]$ShowOnly,
        [string]$SpecificDevice
    )

    # Get all HID devices
    $devices = Get-PnpDevice -Class "HIDClass"

    # Filter devices related to touchscreen functionality
    $touchDevices = $devices | Where-Object {
        $_.FriendlyName -match "(?i)(touch|screen|digitizer|panel)"
    }

    if ($SpecificDevice) {
        # Find and disable a specific device
        $device = $touchDevices | Where-Object { $_.FriendlyName -eq $SpecificDevice }
        if ($device) {
            Write-Output "Disabling: $($device.FriendlyName)"
            Disable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false
            Write-Output "Device $SpecificDevice has been disabled."
        } else {
            Write-Output "No device found with the name $SpecificDevice."
        }
        return
    }

    if ($touchDevices) {
        foreach ($device in $touchDevices) {
            if ($ShowOnly) {
                Write-Output "Found: $($device.FriendlyName)"
            } else {
                Write-Output "Disabling: $($device.FriendlyName)"
                Disable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false
            }
        }

        if ($ShowOnly) {
            Write-Output "All matching devices have been listed."
        } else {
            Write-Output "All touchscreen-related devices have been disabled."
        }
    } else {
        Write-Output "No touchscreen-related devices found."
    }
}

# Main script loop
while ($true) {
    Show-Menu
    $choice = Read-Host "Enter your choice (1-4)"

    switch ($choice) {
        "1" {
            Write-Output "Listing all touchscreen-related HID devices..."
            Handle-Touchscreen -ShowOnly
            Pause
        }
        "2" {
            Write-Output "Disabling all touchscreen-related HID devices..."
            Handle-Touchscreen
            Pause
        }
        "3" {
            Write-Output "Listing all touchscreen-related HID devices..."
            Handle-Touchscreen -ShowOnly
            $specificDevice = Read-Host "Enter the exact name of the device to disable"
            Handle-Touchscreen -SpecificDevice $specificDevice
            Pause
        }
        "4" {
            Write-Output "Exiting script. Goodbye!"
            break
        }
        default {
            Write-Output "Invalid choice. Please select 1, 2, 3, or 4."
            Pause
        }
    }
}
