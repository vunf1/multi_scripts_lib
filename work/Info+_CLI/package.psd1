@{
    Root = 'F:\exc\scripts\various_scripts\multi_scripts_lib\work\Info+_CLI\main.ps1'
    OutputPath = 'F:\exc\scripts\various_scripts\multi_scripts_lib\work\Info+_CLI\out'
    Package = @{
        Enabled = True
        Obfuscate = True
        HideConsoleWindow = False
        DotNetVersion = 'v4.6.2'
        FileVersion = '4.1.0'
        FileDescription = 'PowerShell-based system utility with modular design and task monitoring.'
        ProductName = 'Info+'
        ProductVersion = '4.1.0'
        Copyright = '© 2024 Maia Systems'
        RequireElevation = True
        ApplicationIconPath = 'F:\exc\scripts\various_scripts\multi_scripts_lib\work\Info+_CLI\images\icons\icon4.ico'
        TaskbarName = 'Info+'
        LegalTrademarks = 'Info+ is a registered trademark of Maia'
        CompanyName = 'Maia'
        InternalName = 'InfoPlusApp'
        OriginalFilename = 'InfoPlus.exe'
    }
    Bundle = @{
        Enabled = True
        Modules = True
        AdditionalFiles = @(
            './CustomMessageBox.ps1',
            './DriversTest.ps1',
            './AudioTest.ps1',
            './CommandHelpers.ps1',
            './GetSystemInfo.ps1',
            './TweaksSystem.ps1',
            './images/logo.png',
            './config/settings.json'
        )
    }
    SignExecutable = @{
        CertificatePath = 'F:\exc\scripts\various_scripts\multi_scripts_lib\work\Info+_CLI\MyCert.pfx'
        CertificatePassword = 'YourStrongPassword'
        TimestampURL = 'http://timestamp.digicert.com'
        DigestAlgorithm = 'sha256' 
        OverwriteSignature = True
    }
}
