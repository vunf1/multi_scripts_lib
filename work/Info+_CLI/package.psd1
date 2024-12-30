@{
    Root = 'f:\exc\scripts\various_scripts\multi_scripts_lib\work\Info+_CLI\main.ps1'
    OutputPath = 'f:\exc\scripts\various_scripts\multi_scripts_lib\work\Info+_CLI\out'
    Package = @{
        Enabled = $true
        Obfuscate = $true
        HideConsoleWindow = $false
        DotNetVersion = 'v4.6.2'
        FileVersion = '4.1.0'
        FileDescription = 'PowerShell-based system utility designed to gather and display system information, perform background installation tasks (such as installing Winget and WebView2), and execute additional functionality like displaying a YouTube iframe. It supports modular design for handling various scripts and includes task monitoring with real-time status updates. The program is intended for advanced users or administrators and offers customization options like elevation requirements and bundling dependencies.'
        ProductName = 'Info+'
        ProductVersion = '4.1.0'
        Copyright = 'Maia'
        RequireElevation = $true
        ApplicationIconPath = 'F:\exc\scripts\various_scripts\multi_scripts_lib\work\Info+_CLI\images\icons\icon4.ico'
        PackageType = 'Console'    
        TaskbarName = 'Info+'       # Add a TaskbarName property (if supported by your packaging tool)

    }
    Bundle = @{
        Enabled = $true
        Modules = $true
        AdditionalFiles = @(
            './CustomMessageBox.ps1',
            './DriversTest.ps1',
            './AudioTest.ps1',
            './CommandHelpers.ps1',
            './GetSystemInfo.ps1',
            './TweaksSystem.ps1',
            './InstallDependencies.ps1'
        )
    }
}
        