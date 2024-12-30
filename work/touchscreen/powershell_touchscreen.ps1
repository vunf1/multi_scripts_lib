# Script to Disable All Touchscreen-Related HID Devices
# Run as Administrator

# Function to disable a device by its friendly name
function Disable-Touchscreen {
    # Get all HID devices
    $devices = Get-PnpDevice -Class "HIDClass"

    # Filter devices related to touchscreen functionality
    $touchDevices = $devices | Where-Object {
        $_.FriendlyName -match "(?i)(touch|screen|digitizer|panel)"
    }

    if ($touchDevices) {
        foreach ($device in $touchDevices) {
            Write-Output "Disabling: $($device.FriendlyName)"
            Disable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false
        }
        Write-Output "All touchscreen-related devices have been disabled."
    } else {
        Write-Output "No touchscreen-related devices found."
    }
}

# Call the function
Disable-Touchscreen
