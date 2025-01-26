# Path to the .env file
$envPath = Join-Path -Path $PSScriptRoot -ChildPath ".env"

if (Test-Path $envPath) {
    # Load the .env file
    Get-Content $envPath | ForEach-Object {
        if ($_ -match "^(.*?)=(.*)$") {
            # Set each variable as an environment variable
            [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
        }
    }

    # Retrieve the password from the environment variable
    $certificatePassword = [System.Environment]::GetEnvironmentVariable("PASSWORD")

    # Validate that the password exists
    if (-not $certificatePassword) {
        Write-Error "PASSWORD variable not found in .env file. Please add it to the .env file."
        exit 1
    }

    # Dynamically set paths based on the current script directory
    $rootPath = Join-Path -Path $PSScriptRoot -ChildPath "main.ps1"
    $outputPath = Join-Path -Path $PSScriptRoot -ChildPath "out"
    $iconPath = Join-Path -Path $PSScriptRoot -ChildPath "images/icons/icon4.ico"
    $certificatePath = Join-Path -Path $PSScriptRoot -ChildPath "MyCert.pfx"

    # Validate the existence of the Root file
    if (-not (Test-Path $rootPath)) {
        Write-Error "Root file not found: $rootPath. Ensure 'main.ps1' exists in the script directory."
        exit 1
    }

    # Create the output directory if it doesn't exist
    if (-not (Test-Path $outputPath)) {
        New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
    }

    # Manually construct the configuration string
    $packageConfig = @"
@{
    Root = '$rootPath'
    OutputPath = '$outputPath'
    Package = @{
        Enabled = $true
        Obfuscate = $true
        HideConsoleWindow = $false
        DotNetVersion = 'v4.6.2'
        FileVersion = '4.1.0'
        FileDescription = 'PowerShell-based system utility with modular design and task monitoring.'
        ProductName = 'Info+'
        ProductVersion = '4.1.0'
        Copyright = '© 2024 Maia Systems'
        RequireElevation = $true
        ApplicationIconPath = '$iconPath'
        TaskbarName = 'Info+'
        LegalTrademarks = 'Info+ is a registered trademark of Maia'
        CompanyName = 'Maia'
        InternalName = 'InfoPlusApp'
        OriginalFilename = 'InfoPlus.exe'
    }
    Bundle = @{
        Enabled = $true
        Modules = $true
        AdditionalFiles = @(
            './main/CustomMessageBox.ps1',
            './main/DriversTest.ps1',
            './main/AudioTest.ps1',
            './main/CommandHelpers.ps1',
            './main/GetSystemInfo.ps1',
            './main/TweaksSystem.ps1',
            './images/logo.png',
            './config/settings.json'
        )
    }
    SignExecutable = @{
        CertificatePath = '$certificatePath'
        CertificatePassword = '$certificatePassword'
        TimestampURL = 'http://timestamp.digicert.com'
        DigestAlgorithm = 'sha256' 
        OverwriteSignature = $true
    }
}
"@

    # Path to the package configuration file
    $configFilePath = Join-Path -Path $PSScriptRoot -ChildPath "package.psd1"

    # Write the configuration to the package.psd1 file
    Set-Content -Path $configFilePath -Value $packageConfig -Force -Encoding UTF8

    Write-Host "Configuration file generated at: $configFilePath"
} else {
    Write-Error "The .env file was not found at $envPath. Please ensure it exists in the root of the project."
    exit 1
}
