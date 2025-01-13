# Specify the script files in the order to be combined
$scriptFiles = @(
    "./CustomMessageBox.ps1",
    "./DriversTest.ps1",
    "./AudioTest.ps1",
    "./CommandHelpers.ps1",
    "./GetSystemInfo.ps1",
    "./TweaksSystem.ps1",
    "./main.ps1"
)

# Define the output file
$outputFile = "./infoplus.ps1"

# Clear the output file if it exists
if (Test-Path $outputFile) {
    Write-Host "Removing existing output file: $outputFile"
    Remove-Item -Path $outputFile -Force
}

# Initialize the start time
$startTime = Get-Date
Write-Host "Combining scripts started at: $startTime"

# Combine the files
foreach ($file in $scriptFiles) {
    if (Test-Path $file) {
        Write-Host "Adding content from: $file"
        
        # Add file header with debug timestamp
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path $outputFile -Value "`n# ---- Content from $file ----`n# Added on: $timestamp`n"

        # Get content line count for debugging
        $lineCount = (Get-Content -Path $file).Count
        Write-Host "File: $file | Lines: $lineCount"

        # Add content to the combined file
        Get-Content -Path $file | Add-Content -Path $outputFile
    } else {
        Write-Host "File not found: $file"
    }
}

# Calculate elapsed time
$endTime = Get-Date
$elapsedTime = ($endTime - $startTime).TotalSeconds
Write-Host "Scripts combined into $outputFile successfully!"
Write-Host "Completed at: $endTime | Total Time: $elapsedTime seconds"
