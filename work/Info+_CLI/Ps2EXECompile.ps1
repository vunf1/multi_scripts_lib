# NO SELF SIGNATURE APPLY 
# Define paths and options
$inputFile = ".\infoplus.ps1" # PowerShell script
$outputFile = "$([Environment]::GetFolderPath('Desktop'))\infoplus.exe" # Target output
$iconFile = ".\images\icons\icon4.ico" # icon file
$ps2exePath = ".\tools\PS2EXE-GUI\ps2exe.ps1" # Path to ps2exe.ps1
$version = "9.2.0"
$description = "PowerShell-based system utility with modular design and task monitoring."
$productName = "InfoPlus"
$company = "Maia"
$copyright = "2025 Maia Systems"

# ────────────────────────────────────────────────────────
# 🔍 Step 1: Verify ps2exe Existence
# ────────────────────────────────────────────────────────
Write-Host "`n Checking for ps2exe.ps1 at: `"$ps2exePath`"" -ForegroundColor Yellow

if (-not (Test-Path $ps2exePath)) {
    Write-Host "Error: ps2exe.ps1 not found! Please verify the path." -ForegroundColor Red
    exit 1
} else {
    Write-Host "ps2exe.ps1 found successfully." -ForegroundColor Green
}

# ────────────────────────────────────────────────────────
# 📂 Step 2: Verify Input Script Existence
# ────────────────────────────────────────────────────────
Write-Host "`nChecking for input script at: `"$inputFile`"" -ForegroundColor Yellow

if (-not (Test-Path $inputFile)) {
    Write-Host "Error: Input script not found! Please verify the path." -ForegroundColor Red
    exit 1
} else {
    Write-Host "Input script found successfully." -ForegroundColor Green
}

# ────────────────────────────────────────────────────────
# 🖼️ Step 3: Verifying Icon File Existence
# ────────────────────────────────────────────────────────
Write-Host "`nChecking for icon file at: `"$iconFile`"" -ForegroundColor Yellow

if (-not (Test-Path $iconFile)) {
    Write-Host "Warning: Icon file not found! Proceeding without a custom icon." -ForegroundColor DarkYellow
    $iconFile = $null
} else {
    Write-Host "Icon file found successfully." -ForegroundColor Green
}
# ────────────────────────────────────────────────────────
# 🛠️ Step 4: Ensure Output File Does Not Exist Before Compilation
# ────────────────────────────────────────────────────────
if (Test-Path $outputFile) {
    Write-Host "`nExisting output file found: $outputFile" -ForegroundColor Yellow
    Write-Host "Deleting old output file..." -ForegroundColor DarkGray
    Remove-Item -Force $outputFile
    Write-Host "Old output file removed." -ForegroundColor Green
} else {
    Write-Host "`nNo existing output file detected. Proceeding..." -ForegroundColor Cyan
}
# ────────────────────────────────────────────────────────
# 🚀 Step 5: Start Compilation Process
# ────────────────────────────────────────────────────────
Write-Host "`nStarting compilation of `"$inputFile`" to `"$outputFile`"..." -ForegroundColor Cyan

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
        -x64 `
        -MTA `
        -runtime40

    Write-Host "Compilation process completed successfully." -ForegroundColor Green
} catch {
    Write-Host "Error during compilation: $_" -ForegroundColor Red
    exit 1
}

# ────────────────────────────────────────────────────────
# 🔍 Step 6: Verify the Output File
# ────────────────────────────────────────────────────────
Write-Host "`nVerifying the generated executable..." -ForegroundColor Yellow

if (Test-Path $outputFile) {
    Write-Host "Compilation successful! Executable is ready: `"$outputFile`"" -ForegroundColor Green
} else {
    Write-Host "Error: Compilation failed." -ForegroundColor Red
}
# ────────────────────────────────────────────────────────
# 📜 Final Compilation Summary
# ────────────────────────────────────────────────────────
Write-Host "`n---------------------------------------------------" -ForegroundColor Gray
Write-Host "   Compilation Summary:" -ForegroundColor White
Write-Host "---------------------------------------------------" -ForegroundColor Gray

Write-Host "   Input Script      : " -ForegroundColor Cyan -NoNewline
Write-Host "$inputFile" -ForegroundColor White

Write-Host "   Output Executable : " -ForegroundColor Cyan -NoNewline
Write-Host "$outputFile" -ForegroundColor White

Write-Host "   Icon File         : " -ForegroundColor Cyan -NoNewline
Write-Host "$iconFile" -ForegroundColor White

Write-Host "   Version           : " -ForegroundColor Cyan -NoNewline
Write-Host "$version" -ForegroundColor White

Write-Host "   Description       : " -ForegroundColor Cyan -NoNewline
Write-Host "$description" -ForegroundColor White

Write-Host "   Product Name      : " -ForegroundColor Cyan -NoNewline
Write-Host "$productName" -ForegroundColor White

Write-Host "   Company           : " -ForegroundColor Cyan -NoNewline
Write-Host "$company" -ForegroundColor White

Write-Host "   Copyright        : " -ForegroundColor Cyan -NoNewline
Write-Host "$copyright" -ForegroundColor White

Write-Host "---------------------------------------------------" -ForegroundColor Gray