Add-Type -AssemblyName System.Windows.Forms

# Shared variable to track task completion
$global:taskCompletionTracker = [hashtable]::Synchronized(@{})

# Function to handle the background installation process
function Start-InstallationTasks {
    param (
        [string]$TaskName,
        [ScriptBlock]$TaskScript
    )

    # Create a runspace for each task
    $runspace = [powershell]::Create()
    $runspace.AddScript($TaskScript)

    # Start asynchronous execution
    $asyncResult = $runspace.BeginInvoke() | Out-Null  # Suppress any output

    # Monitor the runspace using a background job
    Start-Job -ScriptBlock {
        param ($runspace, $taskName, $asyncResult, $tracker)

        try {
            # Wait for the task to complete
            $null = $runspace.EndInvoke($asyncResult)
            $tracker[$taskName] = $true  # Mark the task as completed
            #[System.Windows.Forms.MessageBox]::Show("$taskName completed successfully.", "Task Status", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        } catch {
            [System.Windows.Forms.MessageBox]::Show("$taskName failed: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        } finally {
            # Clean up the runspace
            $runspace.Dispose()
        }
    } -ArgumentList $runspace, $TaskName, $asyncResult, $global:taskCompletionTracker | Out-Null  # Suppress job output
}

# Installation scripts for Winget and WebView2 Runtime
$installWingetScript = {
    try {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            $appInstallerUri = "https://aka.ms/getwinget"
            $tempInstaller = "$env:TEMP\AppInstaller.msixbundle"

            if (Test-Path $tempInstaller) { Remove-Item -Path $tempInstaller -Force }
            try {
                Invoke-WebRequest -Uri $appInstallerUri -OutFile $tempInstaller -UseBasicParsing
                Add-AppxPackage -Path $tempInstaller
                if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
                    [System.Windows.Forms.MessageBox]::Show("Failed to install Winget.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                    return
                }
                if (Test-Path $tempInstaller) { Remove-Item -Path $tempInstaller -Force }
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Error during Winget installation process: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            }
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error installing Winget: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

$installWebView2Script = {
    try {
        $webView2Key = "HKLM:\\SOFTWARE\\Microsoft\\EdgeUpdate\\Clients\\{F1C0906E-33B9-48F6-95C9-78A0744C7E16}"
        $webView2Installed = Get-ItemProperty -Path $webView2Key -ErrorAction SilentlyContinue
        if ($webView2Installed) {
            #[System.Windows.Forms.MessageBox]::Show("WebView2 Runtime is already installed.", "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            return
        }

        winget install --id Microsoft.EdgeWebView2Runtime --silent --accept-package-agreements --accept-source-agreements
        #[System.Windows.Forms.MessageBox]::Show("WebView2 Runtime installed successfully.", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error installing WebView2 Runtime: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# Start both installation tasks in the background
Start-InstallationTasks -TaskName "Winget Installation" -TaskScript $installWingetScript
Start-InstallationTasks -TaskName "WebView2 Runtime Installation" -TaskScript $installWebView2Script