# Create a new WPF window
Add-Type -AssemblyName PresentationFramework

# Create the XAML for the WPF window
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PC Information" Height="300" Width="400" WindowStartupLocation="CenterScreen">
    <Grid>
        <TextBox Name="InfoTextBox" Margin="10" FontFamily="Arial" FontSize="12" IsReadOnly="True" TextWrapping="Wrap"/>
    </Grid>
</Window>
"@

# Load the XAML into an XmlDocument
$xmlDocument = New-Object System.Xml.XmlDocument
$xmlDocument.LoadXml($xaml)

# Parse the XAML into a WPF window object
$reader = New-Object System.Xml.XmlNodeReader($xmlDocument)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Retrieve the TextBox from the window
$infoTextBox = $window.FindName("InfoTextBox")

# Function to gather system information
function Get-SystemInfo {
    $cpu = (Get-CimInstance -ClassName Win32_Processor).Name
    $ram = [math]::round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    $os = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
    $gpu = (Get-CimInstance -ClassName Win32_VideoController | Select-Object -First 1).Name
    $diskInfo = (Get-CimInstance -ClassName Win32_LogicalDisk | ForEach-Object {
        "$($_.DeviceID): $([math]::round($_.Size / 1GB, 2)) GB"
    }) -join "`n"
    

    return @"
CPU: $cpu
RAM: $ram GB
OS: $os
GPU: $gpu
Disks:
$diskInfo
"@
}

# Set the system info in the TextBox when the window is loaded
$window.Add_Loaded({
    $infoTextBox.Text = Get-SystemInfo
})

# Show the WPF window
[void]$window.ShowDialog()
