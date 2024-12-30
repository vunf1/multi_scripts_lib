function Show-CustomMessageBox {
    param (
        [string]$Message,
        [string]$Title = "Notification",
        [ValidateSet("Information", "Warning", "Error", "Critical")]
        [string]$Type = "Information",
        [ValidateSet("OK", "YesNo", "YesNoCancel", "RetryCancel", "AbortRetryIgnore")]
        [string]$ButtonLayout = "YesNo",
        [string]$CustomIconPath = "$PSScriptRoot\images\icons\icon2.ico" # Path to your default icon
    )

    # Add required .NET assembly for Windows Forms
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Create the form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.StartPosition = "CenterScreen"
    $form.Width = 270
    $form.Height = 150
    $form.FormBorderStyle = "FixedDialog"
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30) # Dark background
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ShowInTaskbar = $true
    $form.Tag = $null # Use the Tag property to store the response

    # Set the custom icon
    if (Test-Path $CustomIconPath) {
        $form.Icon = New-Object System.Drawing.Icon($CustomIconPath)
    } else {
        Write-Host "Custom icon not found at $CustomIconPath. Using default icon." -ForegroundColor Yellow
    }

    # Create the message label
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Message
    $label.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
    $label.ForeColor = [System.Drawing.Color]::White
    $label.TextAlign = "MiddleCenter"
    $label.Dock = "Top"
    $label.Height = 50
    $form.Controls.Add($label)

    # Create a FlowLayoutPanel to center buttons
    $buttonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttonPanel.FlowDirection = "LeftToRight"
    $buttonPanel.WrapContents = $false
    $buttonPanel.Anchor = "Bottom"
    $buttonPanel.Dock = "Bottom"
    $buttonPanel.Padding = New-Object System.Windows.Forms.Padding(10)
    $buttonPanel.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $buttonPanel.AutoSize = $true
    $buttonPanel.AutoSizeMode = "GrowAndShrink"
    $form.Controls.Add($buttonPanel)

    # Helper function to create buttons
    function CreateButton($text, $width, $height, $clickAction) {
        $button = New-Object System.Windows.Forms.Button
        $button.Text = $text
        $button.Font = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Regular)
        $button.BackColor = [System.Drawing.Color]::White
        $button.ForeColor = [System.Drawing.Color]::Black
        $button.Width = $width
        $button.Height = $height
        $button.Margin = New-Object System.Windows.Forms.Padding(5) # Adds default spacing between buttons
        $button.Add_Click($clickAction)
        return $button
    }

    # Add buttons based on the ButtonLayout parameter
    switch ($ButtonLayout) {
        "OK" {
            $okButton = CreateButton "OK" 80 30 { $form.Tag = "OK"; $form.Close() }
            $okButton.Margin = New-Object System.Windows.Forms.Padding(80, 0, 10, 0) 
            $buttonPanel.Controls.Add($okButton)
        }
        "YesNo" {
            $yesButton = CreateButton "Yes" 80 30 { $form.Tag = "Yes"; $form.Close() }
            $yesButton.Margin = New-Object System.Windows.Forms.Padding(10, 0, 50, 0) 
            $noButton = CreateButton "No" 80 30 { $form.Tag = "No"; $form.Close() }
            $noButton.Margin = New-Object System.Windows.Forms.Padding(10, 0, 50, 0) 
            $buttonPanel.Controls.Add($yesButton)
            $buttonPanel.Controls.Add($noButton)
        }
        "YesNoCancel" {
            $yesButton = CreateButton "Yes" 70 30 { $form.Tag = "Yes"; $form.Close() }
            $noButton = CreateButton "No" 70 30 { $form.Tag = "No"; $form.Close() }
            $cancelButton = CreateButton "Cancel" 70 30 { $form.Tag = "Cancel"; $form.Close() }
            $buttonPanel.Controls.Add($yesButton)
            $buttonPanel.Controls.Add($noButton)
            $buttonPanel.Controls.Add($cancelButton)
        }
    }

    # Center content dynamically on resize
    $form.Add_SizeChanged({
        $label.Width = $form.ClientSize.Width
        $buttonPanel.Width = $form.ClientSize.Width
        $buttonPanel.Left = ($form.ClientSize.Width - $buttonPanel.Width) / 2
    })

    # Show the form and return the user's response
    $form.ShowDialog() | Out-Null
    return $form.Tag
}