# Input script path
$scriptPath = ".\infoplus.ps1"  # Replace with your script path
$outputEncodedPath = ".\info.encoded"  # Encoded output path

# Step 1: Read the script content
if (-not (Test-Path $scriptPath)) {
    Write-Host "Error: Script file not found at $scriptPath" -ForegroundColor Red
    exit
}
$scriptContent = Get-Content -Path $scriptPath -Raw

# Step 2: Compress the content
$compressedStream = New-Object System.IO.MemoryStream
$gzipStream = New-Object System.IO.Compression.GZipStream $compressedStream, ([System.IO.Compression.CompressionMode]::Compress)
$streamWriter = New-Object System.IO.StreamWriter $gzipStream

$streamWriter.Write($scriptContent)
$streamWriter.Close()
$gzipStream.Close()

# Step 3: Convert to Base64
$compressedBytes = $compressedStream.ToArray()
$encodedScript = [Convert]::ToBase64String($compressedBytes)

# Step 4: Save the Base64-encoded script to a file
Set-Content -Path $outputEncodedPath -Value $encodedScript

Write-Host "Script successfully compressed and encoded to Base64." -ForegroundColor Green
Write-Host "Encoded file saved at: $outputEncodedPath" -ForegroundColor Cyan
