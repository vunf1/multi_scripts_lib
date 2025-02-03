
param(
    [switch]$Debug,
    [switch]$Local
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null # Set console code page to UTF-8

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsFormsIntegration
Add-Type -AssemblyName System.Windows.Forms
function Set-ConsoleWindowPosition {
    param (
        [int]$OffsetX = 0,  # X-offset from the right edge of the screen
        [int]$OffsetY = 0   # Y-offset from the bottom edge of the screen
    )

    # Get the console window handle
    $consoleHandle = [System.Diagnostics.Process]::GetCurrentProcess().MainWindowHandle

    # Import the user32.dll functions
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class User32 {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }
}
"@

    # Get screen dimensions
    $screenWidth = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
    $screenHeight = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height

    # Get current console window size
    $rect = New-Object User32+RECT
    [User32]::GetWindowRect($consoleHandle, [ref]$rect)

    # Calculate new position
    $windowWidth = $rect.Right - $rect.Left
    $windowHeight = $rect.Bottom - $rect.Top
    $newX = $screenWidth - $windowWidth - $OffsetX
    $newY = $screenHeight - $windowHeight - $OffsetY

    # Move the window
    [User32]::MoveWindow($consoleHandle, $newX, $newY, $windowWidth, $windowHeight, $true)
}

if ($Debug) {
    Write-Host "Debug mode is ON." -ForegroundColor Yellow
    Write-Host "Console will not be clean." -ForegroundColor Cyan
    $host.UI.RawUI.WindowTitle = "Info+ - DEBUG MODE"

} else {
    Write-Host "Debug mode is OFF."
    $host.UI.RawUI.WindowTitle = "Info+"
}
Set-ConsoleWindowPosition -OffsetX 10 -OffsetY 10
$host.UI.RawUI.BackgroundColor = "Black"
function Clear-SystemCache {
    
    $confirmation = Show-Confirmation -message "Are you sure you want to clean the system cache?" -title "Confirmation"

    if ($confirmation -eq [System.Windows.Forms.DialogResult]::Yes -or $confirmation -eq $true) {
        Write-Host "`nCleaning System Cache..." -ForegroundColor Cyan

        # 1. Clean up Windows Component Store via DISM
        Write-Host "Cleaning up Windows Component Store..."
        Start-Process -FilePath "dism.exe" -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup" -Wait -NoNewWindow

        # 2. Clear Windows Update Cache
        Write-Host "Clearing Windows Update Cache..."
        Write-Host "Stopping Windows Update Service..."
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        Remove-Item "C:\Windows\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Starting Windows Update Service..."
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue

        # 3. Clear Browser Caches (Chrome, Firefox, Edge)
        Write-Host "Cleaning browser caches..."
        # Chrome
        Remove-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue
        # Firefox (for each profile)
        Get-ChildItem "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-Item "$($_.FullName)\cache2\*" -Recurse -Force -ErrorAction SilentlyContinue
        }
        # Edge
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue

        # 4. Clear Internet Explorer/Legacy Edge Cache
        Write-Host "Clearing Internet Explorer/Edge Cache..."
        Start-Process "RunDll32.exe" -ArgumentList "InetCpl.cpl,ClearMyTracksByProcess 255" -Wait -NoNewWindow

        # 5. Clear DNS Cache
        Write-Host "Clearing DNS Cache..."
        Clear-DnsClientCache -ErrorAction SilentlyContinue

        # 6. Clear System Event Logs
        Write-Host "Clearing System Event Logs..."
        wevtutil el | ForEach-Object { wevtutil cl $_ } | Out-Null

        # 7. Empty the Recycle Bin
        Write-Host "Emptying Recycle Bin..."
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue

        # 8. Run Disk Cleanup for Temporary & Delivery Optimization Files
        Write-Host "Running Disk Cleanup..."
        # Assumes that /sagerun:1 has been configured (via cleanmgr /sageset:1) beforehand.
        Start-Process "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait -NoNewWindow

        # 9. Remove old Windows versions (ResetBase removes superseded components)
        Write-Host "Removing old Windows versions..."
        Start-Process -FilePath "dism.exe" -ArgumentList "/Online /Cleanup-Image /ResetBase" -Wait -NoNewWindow

        # 10. Clear Windows Temp Files
        Write-Host "Clearing Windows Temp Folder..."
        Remove-Item "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

        # 11. Clear User Temp Files
        Write-Host "Clearing User Temp Folder..."
        Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue

        # 12. Clear Downloads Folder (optional)
        Write-Host "Clearing Downloads Folder..."
        Remove-Item "$env:USERPROFILE\Downloads\*" -Recurse -Force -ErrorAction SilentlyContinue

        Write-Host "`nSystem Cache and Unnecessary Files Cleaned Successfully!" -ForegroundColor Green
    } else {
        Write-Host "Operation cancelled by user." -ForegroundColor Yellow
    }
}
# Function to configure power settings
function Use-ConfigurePowerSettings {
    Write-Host "Configuring Power Settings..." -ForegroundColor Yellow

    # Set sleep and screen off timers to 0
    powercfg /change standby-timeout-ac 0
    powercfg /change standby-timeout-dc 0
    powercfg /change monitor-timeout-ac 0
    powercfg /change monitor-timeout-dc 0
    Write-Host "Set sleep and screen-off timers to 0." -ForegroundColor Green

    # Disable fast startup
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f
    Write-Host "Fast Startup has been disabled." -ForegroundColor Green

    # Set screensaver to blank with a timer of 5 minutes
    reg add "HKCU\Control Panel\Desktop" /v SCRNSAVE.EXE /t REG_SZ /d "C:\Windows\System32\scrnsave.scr" /f
    reg add "HKCU\Control Panel\Desktop" /v ScreenSaveTimeOut /t REG_SZ /d 300 /f
    reg add "HKCU\Control Panel\Desktop" /v ScreenSaveActive /t REG_SZ /d 1 /f
    Write-Host "Screensaver set to blank with a timer of 5 minutes." -ForegroundColor Green

    Write-Host "Power settings configured successfully." -ForegroundColor Green
}

function Register-OEMKey {
    try {
        # Retrieve the OEM key
        $oemKey = Get-OEMKey 
        if (-not $oemKey) {
            Write-Host "OEM Key not found on this system." -ForegroundColor Red
            return
        }

        # Display the confirmation dialog
        $response = Show-Confirmation -Message "Do you want to register the OEM Key?" `
            -Title "Confirmation" 
        
        if ($response -ne [System.Windows.Forms.DialogResult]::Yes) {
            Write-Host "Operation cancelled by user." -ForegroundColor Red
            return
        }
        $tasks = @(
            @{ 
                Name = "Gathering OEM Key"; 
                Task = { Write-Host "OEM Key Found: $oemKey" -ForegroundColor Yellow } 
            },
            @{ 
                Name = "Reinstalling OEM Key"; 
                Task = {
                    $installKeyCommand = "cscript.exe"
                    $arguments = "$env:SystemRoot\System32\slmgr.vbs /ipk $oemKey"
                    Start-Process -FilePath $installKeyCommand -ArgumentList $arguments -NoNewWindow -Wait
                } 
            },
            @{ 
                Name = "Activating OEM Key"; 
                Task = {
                    $activateCommand = "cscript.exe"
                    $arguments = "$env:SystemRoot\System32\slmgr.vbs /ato"
                    Start-Process -FilePath $activateCommand -ArgumentList $arguments -NoNewWindow -Wait
                } 
            },
            @{ 
                Name = "Validating Activation Status"; 
                Task = {
                    $statusCommand = "cscript.exe"
                    $arguments = "$env:SystemRoot\System32\slmgr.vbs /dli"
                    $process = Start-Process -FilePath $statusCommand -ArgumentList $arguments -NoNewWindow -Wait -PassThru
                    $output = $process.StandardOutput.ReadToEnd()
                    Write-Host "Activation Status:" -ForegroundColor Green
                    Write-Host $output
                } 
            }
        )
        

        $totalTasks = $tasks.Count
        $progressCount = 0

        # Process each task with progress updates
        foreach ($taskItem in $tasks) {
            $progressCount++
            $percentComplete = [math]::Round(($progressCount / $totalTasks) * 100)

            Write-Progress -Activity "Registering OEM Key >>>>>> " `
                           -Status "Processing: $($taskItem.Name) ($progressCount of $totalTasks)" `
                           -PercentComplete $percentComplete
            & $taskItem.Task
        }

        # Clear the progress bar
        Write-Progress -Activity "Registering OEM Key" -Completed

        Write-Host "OEM Key registration process completed." -ForegroundColor Green

    } catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
    }
}
function Start-ActivationScript {
    param (
        [string]$Url = "https://get.activated.win",
        [string]$OutFile = "$env:TEMP\safe_script.ps1"
    )

    # Step 1: Download the script safely
    try {
        Invoke-RestMethod -Uri $Url -OutFile $OutFile -ErrorAction Stop
        Write-Host " Script downloaded to: $OutFile" -ForegroundColor Green
    }
    catch {
        Write-Host " Failed to download script." -ForegroundColor Red
        return
    }

    # Step 2: Execute the script in the same session without blocking
    Write-Host " Executing script in background... (It will auto-delete after execution)" -ForegroundColor Yellow
    Start-Job -ScriptBlock {
        param ($OutFile)
        powershell -ExecutionPolicy Bypass -File $OutFile
        Remove-Item -Force $OutFile
    } -ArgumentList $OutFile

    # Step 3: Allow the script to continue running in the background
    Write-Host "🔄 Script is running in the background. Main script continues." -ForegroundColor Cyan
}