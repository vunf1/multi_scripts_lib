# Function to test syntax
function Test-Syntax {
    param (
        [string]$ScriptContent
    )
    try {
        # Use PowerShell's parser to validate the script
        $errors = @()
        [System.Management.Automation.Language.Parser]::ParseInput($ScriptContent, [ref]$null, [ref]$errors)

        if ($errors.Count -eq 0) {
            return @{
                IsValid = $true
                Errors = @()
            }
        } else {
            $errorDetails = $errors | ForEach-Object {
                "Syntax Error: $($_.Message) at Line: $($_.Extent.StartLineNumber)"
            }

            foreach ($detail in $errorDetails) {
                Write-Host $detail -ForegroundColor Red
            }

            return @{
                IsValid = $false
                Errors = $errorDetails
            }
        }
    } catch {
        Write-Host "Unexpected error during syntax validation: $_" -ForegroundColor Red
        return @{
            IsValid = $false
            Errors = @("Unexpected error: $_")
        }
    }
}

# Main combining logic
$scriptFiles = @(
    "./main/DriversTest.ps1",
    "./main/AudioTest.ps1",
    "./main/CommandHelpers.ps1",
    "./main/GetSystemInfo.ps1",
    "./main/TweaksSystem.ps1",
    "./main/CustomMessageBox.ps1",
    "./main/main.ps1"
)

$outputFile = ".\infoplus.ps1"
$errorLog = ".\infoplus_error.log"

if (Test-Path $outputFile) { Remove-Item -Path $outputFile -Force }
if (Test-Path $errorLog) { Remove-Item -Path $errorLog -Force }

$startTime = Get-Date
Write-Host "Combining scripts started at: $startTime"

$totalLines = 0
$totalSizeBytes = 0
$combinedFiles = @()
$syntaxErrors = 0
$generalErrors = 0
$syntaxErrorDetails = @()

# Progress bar setup
$totalFiles = $scriptFiles.Count
$currentFileIndex = 0

foreach ($file in $scriptFiles) {
    $currentFileIndex++
    $percentComplete = [math]::Round(($currentFileIndex / $totalFiles) * 100)

    Write-Progress -Activity "Combining Scripts" `
                   -Status "Processing file $currentFileIndex of ${totalFiles}: $file" `
                   -PercentComplete $percentComplete

    if (Test-Path $file) {
        try {
            Write-Host "Processing file: $file"

            $content = Get-Content -Path $file -Raw
            $syntaxCheck = Test-Syntax -ScriptContent $content

            if (-not $syntaxCheck.IsValid) {
                Add-Content -Path $errorLog -Value "Syntax error in $file"
                Write-Warning "Syntax error in $file. Skipping..."
                $syntaxErrors += $syntaxCheck.Errors.Count
                $syntaxErrorDetails += $syntaxCheck.Errors | ForEach-Object { "$file -> $_" }
                continue
            }

            $fileInfo = Get-Item -Path $file
            $lineCount = $content -split "`r?`n" | Measure-Object -Line
            $fileSize = $fileInfo.Length / 1KB

            Write-Host "File: $file | Lines: $($lineCount.Lines) | Size: $([math]::Round($fileSize, 2)) KB"

            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Add-Content -Path $outputFile -Value "`n# ---- Content from $file ----`n# Added on: $timestamp`n"

            Add-Content -Path $outputFile -Value $content
            $totalLines += $lineCount.Lines
            $totalSizeBytes += $fileInfo.Length
            $combinedFiles += $file
        } catch {
            $errorMsg = "Error processing ${file}: $_"
            Add-Content -Path $errorLog -Value $errorMsg
            Write-Host $errorMsg -ForegroundColor Red
            $generalErrors++
        }
    } else {
        $errorMsg = "File not found: $file"
        Add-Content -Path $errorLog -Value $errorMsg
        Write-Host $errorMsg -ForegroundColor Red
        $generalErrors++
    }
}

$endTime = Get-Date
$elapsedTime = ($endTime - $startTime).TotalSeconds

# Friendlier Summary Design
Write-Host "`n========== Summary ==========" -ForegroundColor Cyan
Write-Host "Total Files Combined: $($combinedFiles.Count)" -ForegroundColor DarkCyan
Write-Host "Total Lines Combined: $totalLines" -ForegroundColor DarkCyan
Write-Host "Total Size Combined: $([math]::Round($totalSizeBytes / 1KB, 2)) KB" -ForegroundColor DarkCyan
Write-Host "Output File: $outputFile" -ForegroundColor DarkCyan

# Display syntax errors count in red if greater than 0
if ($syntaxErrors -gt 0) {
    Write-Host "Syntax Errors: $syntaxErrors" -ForegroundColor Red
    Write-Host "Details:"
    foreach ($detail in $syntaxErrorDetails) {
        Write-Host $detail -ForegroundColor Red
    }
} else {
    Write-Host "Syntax Errors: $syntaxErrors" -ForegroundColor Green
}

# Display general errors count in red if greater than 0
if ($generalErrors -gt 0) {
    Write-Host "General Errors Logged: $generalErrors" -ForegroundColor Red
} else {
    Write-Host "General Errors Logged: $generalErrors" -ForegroundColor Green
}

# Success message if no errors
if ($syntaxErrors -eq 0 -and $generalErrors -eq 0) {
    Write-Host "`nSuccess: All scripts combined without errors!" -ForegroundColor Green
} else {
    Write-Host "`nProcess completed with errors." -ForegroundColor Yellow
}

Write-Host "Completed at: $endTime | Total Time: $elapsedTime seconds" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
