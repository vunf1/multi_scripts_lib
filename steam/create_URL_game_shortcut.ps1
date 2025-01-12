$startMenuPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"

$shortcutName = "CS2.lnk"
$shortcutPath = Join-Path -Path $startMenuPath -ChildPath $shortcutName
$targetPath = "steam://rungameid/730"

$iconPath =  (Resolve-Path ".\cs2.exe").Path  # Replace with .ico file or an .exe file path

$Shell = New-Object -ComObject WScript.Shell
$Shortcut = $Shell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = $targetPath

$Shortcut.IconLocation = $iconPath

$Shortcut.Save()

Write-Host "Shortcut for $shortcutName created in the Start Menu with an icon!" -ForegroundColor Green
