function Show-PowerInfoPage {
    . ./CommandHelpers.ps1
    try {
        # Initialize variables
        $batteries = $null
        $powerSupplyInfo = $null

        # Attempt to fetch battery info using Win32_Battery
        $batteries = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue

        # Attempt to fetch power supply info using Win32_PowerSupply
        $powerSupplyInfo = Get-CimInstance -ClassName Win32_PowerSupply -ErrorAction SilentlyContinue

        # Fallback: If no batteries or power supply detected, notify the user
        if ((-not $batteries -or $batteries.Count -eq 0) -and (-not $powerSupplyInfo -or $powerSupplyInfo.Count -eq 0)) {
            $htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Power Info</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: rgb(77, 77, 77);
            color: white;
            text-align: center;
            margin: 0;
            padding: 2rem;
        }
        h1 {
            margin-bottom: 1rem;
        }
    </style>
</head>
<body>
    <h1>No Power Supply or Battery Detected</h1>
    <p>Unable to retrieve information about the power supply or batteries on this system.</p>
</body>
</html>
"@
        } else {
            # Generate dynamic HTML content
            $htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Power Info</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: rgb(77, 77, 77);
            color: white;
            margin: 0;
            padding: 2rem;
            text-align: center;
        }
        table {
            width: 80%;
            margin: 1rem auto;
            border-collapse: collapse;
        }
        th, td {
            border: 1px solid white;
            padding: 0.5rem;
            text-align: left;
        }
        th {
            background-color: rgb(50, 50, 50);
        }
        h2 {
            margin-top: 2rem;
        }
    </style>
</head>
<body>
    <h1>Power Information</h1>
"@

            # Add Battery Information
            if ($batteries -and $batteries.Count -gt 0) {
                $htmlContent += @"
    <h2>Battery Information</h2>
    <table>
        <thead>
            <tr>
                <th>Name</th>
                <th>Status</th>
                <th>Charge (%)</th>
                <th>Run Time (min)</th>
                <th>Chemistry</th>
            </tr>
        </thead>
        <tbody>
"@
                foreach ($battery in $batteries) {
                    $chargeRemaining = if ($null -ne $battery.EstimatedChargeRemaining) { "$($battery.EstimatedChargeRemaining)%" } else { "N/A" }
                    $runTime = if ($null -ne $battery.EstimatedRunTime) { "$($battery.EstimatedRunTime) min" } else { "N/A" }
                    $chemistry = switch ($battery.Chemistry) {
                        1 { 'Other' }
                        2 { 'Unknown' }
                        3 { 'Lead Acid' }
                        4 { 'Nickel Cadmium' }
                        5 { 'Nickel Metal Hydride' }
                        6 { 'Lithium-ion' }
                        7 { 'Zinc Air' }
                        8 { 'Lithium Polymer' }
                        Default { 'Not Specified' }
                    }
                    $htmlContent += @"
            <tr>
                <td>$($battery.Name)</td>
                <td>$($battery.Status)</td>
                <td>$chargeRemaining</td>
                <td>$runTime</td>
                <td>$chemistry</td>
            </tr>
"@
                }
                $htmlContent += "</tbody></table>"
            }

            # Add Power Supply Information
            if ($powerSupplyInfo -and $powerSupplyInfo.Count -gt 0) {
                $htmlContent += @"
    <h2>Power Supply Information</h2>
    <table>
        <thead>
            <tr>
                <th>Name</th>
                <th>Status</th>
                <th>Model</th>
                <th>Manufacturer</th>
            </tr>
        </thead>
        <tbody>
"@
                foreach ($psu in $powerSupplyInfo) {
                    $htmlContent += @"
            <tr>
                <td>$($psu.Name)</td>
                <td>$($psu.Status)</td>
                <td>$($psu.Model)</td>
                <td>$($psu.Manufacturer)</td>
            </tr>
"@
                }
                $htmlContent += "</tbody></table>"
            }

            # Close HTML tags
            $htmlContent += "</body></html>"
        }

        # Encode the HTML content as Base64
        $base64Content = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($htmlContent))

        # Construct the data URL
        $dataUrl = "data:text/html;base64,$base64Content"

        # Launch in Edge
        $edgePath = Get-EdgePath
        if (-not $edgePath) {
            Write-Error "Microsoft Edge executable not found. Please ensure Edge is installed."
            return
        }

        # Define screen width and position
        $screenWidth = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
        $screenHeight = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height
        $windowWidth = [math]::Floor($screenWidth / 2)
        $windowHeight = $screenHeight
        $windowX = $screenWidth - $windowWidth
        $windowY = 0

        # Launch Edge
        try {
            Start-Process -FilePath $edgePath -ArgumentList "--app=$dataUrl", "--inprivate", "--window-size=$windowWidth,$windowHeight", "--window-position=$windowX,$windowY"
        } catch {
            Write-Host "Error launching Edge: $_" -ForegroundColor Red
        }
    } catch {
        # Handle errors during retrieval
        Write-Host "An error occurred while generating the power information page: $_" -ForegroundColor Red
    }
}

# Call the function
Show-PowerInfoPage
