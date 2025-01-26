# NO SELF SIGNATURE APPLY 
# Define paths and options
$inputFile = ".\infoplus.ps1" # PowerShell script
$outputFile = "$([Environment]::GetFolderPath('Desktop'))\infoplus.exe" # Target output
$iconFile = ".\images\icons\icon4.ico" # icon file
$ps2exePath = ".\tools\PS2EXE-GUI\ps2exe.ps1" # Path to ps2exe.ps1
$version = "6.5.0"
$description = "PS Helper"
$productName = "InfoPlus"
$company = "Maia"
$copyright = "Copyright Maia"

# Step 1: Verify ps2exe existence
Write-Host "Step 1: Checking for ps2exe.ps1..." -ForegroundColor Yellow
if (-not (Test-Path $ps2exePath)) {
    Write-Host "Error: ps2exe.ps1 not found at $ps2exePath. Please verify the path." -ForegroundColor Red
    exit 1
} else {
    Write-Host "ps2exe.ps1 found successfully." -ForegroundColor Green
}

# Step 2: Verify input script existence
Write-Host "Step 2: Checking for input script at $inputFile..." -ForegroundColor Yellow
if (-not (Test-Path $inputFile)) {
    Write-Host "Error: Input script not found at $inputFile. Please verify the path." -ForegroundColor Red
    exit 1
} else {
    Write-Host "Input script found successfully." -ForegroundColor Green
}

# Step 3: Verifying icon file existence
Write-Host "Step 3: Checking for icon file at $iconFile..." -ForegroundColor Yellow
if (-not (Test-Path $iconFile)) {
    Write-Host "Warning: Icon file not found at $iconFile. Proceeding without custom icon." -ForegroundColor Red
    $iconFile = $null
} else {
    Write-Host "Icon file found successfully." -ForegroundColor Green
}

# Step 4: Start compilation
Write-Host "Step 4: Starting compilation of $inputFile to $outputFile..." -ForegroundColor Cyan
try {
    & $ps2exePath `
        -inputFile $inputFile `
        -outputFile $outputFile `
        -iconFile $iconFile `
        -version $version `
        -description $description `
        -product $productName `
        -company $company `
        -copyright $copyright `
        -requireAdmin `
        -MTA `
        -runtime40

    Write-Host "Compilation process completed. Verifying output..." -ForegroundColor Yellow
} catch {
    Write-Host "Error during compilation: $_" -ForegroundColor Red
    exit 1
}

# Step 5: Verify the output file
Write-Host "Step 5: Verifying the generated executable..." -ForegroundColor Yellow
if (Test-Path $outputFile) {
    Write-Host "Compilation successful! Executable created at:" -ForegroundColor Green
    Write-Host $outputFile -ForegroundColor Cyan
} else {
    Write-Host "Error: Compilation failed. Please check logs and settings." -ForegroundColor Red
}

# Final Summary
Write-Host "----------------------------------------" -ForegroundColor Gray
Write-Host "Compilation Summary:" -ForegroundColor White
Write-Host "Input Script   : $inputFile" -ForegroundColor Cyan
Write-Host "Output Executable: $outputFile" -ForegroundColor Cyan
Write-Host "Icon File      : $iconFile" -ForegroundColor Cyan
Write-Host "Version        : $version" -ForegroundColor Cyan
Write-Host "Description    : $description" -ForegroundColor Cyan
Write-Host "Product Name   : $productName" -ForegroundColor Cyan
Write-Host "Company        : $company" -ForegroundColor Cyan
Write-Host "Copyright      : $copyright" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Gray
