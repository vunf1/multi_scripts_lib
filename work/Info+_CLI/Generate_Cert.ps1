# Define the path to the .env file at the root of the project
$envPath = Join-Path -Path $PSScriptRoot -ChildPath ".env"

# Check if the .env file exists
if (Test-Path $envPath) {
    # Read the .env file line by line
    Get-Content $envPath | ForEach-Object {
        if ($_ -match "^(.*?)=(.*)$") {
            # Set each variable as an environment variable
            [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
        }
    }

    # Access the password from the environment variable
    $passwordPlainText = [System.Environment]::GetEnvironmentVariable("PASSWORD")

    # Check if the password is loaded
    if (-not $passwordPlainText) {
        Write-Error "Password not found in .env file. Please add a PASSWORD variable."
        exit 1
    }

    # Convert the password to a SecureString
    $securePassword = ConvertTo-SecureString -String $passwordPlainText -AsPlainText -Force

    # Generate a self-signed certificate
    $cert = New-SelfSignedCertificate -DnsName "HardStockApp" -CertStoreLocation "Cert:\CurrentUser\My" -NotAfter (Get-Date).AddYears(1)

    # Export the certificate
    $outputPath = Join-Path -Path $PSScriptRoot -ChildPath "MyCert.pfx"
    Export-PfxCertificate -Cert $cert -FilePath $outputPath -Password $securePassword
    Write-Host " "
    Write-Host "Certificate successfully created and exported to $outputPath"
} else {
    Write-Error "The .env file was not found at $envPath. Please ensure it exists at the root of the project."
}
