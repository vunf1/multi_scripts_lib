function Test-StuckPixel {
    $url = "https://www.jscreenfix.com/fix.html"
    $edgePath = Get-EdgePath
    $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"

    # Define ad-blocking entries
    $adEntries = @(
        "127.0.0.1 googleads.g.doubleclick.net"
        "127.0.0.1 pagead2.googlesyndication.com"
        "127.0.0.1 ep2.adtrafficquality.google"
    )

    try {
        # Read existing hosts file content
        $hostsContent = Get-Content -Path $hostsFile -ErrorAction SilentlyContinue

        # Check if any ad domain is missing in the hosts file
        $entriesToAdd = @()
        foreach ($entry in $adEntries) {
            $domain = $entry -split "\s+" | Select-Object -Last 1  # Extract domain
            if ($hostsContent -notmatch [regex]::Escape($domain)) {
                $entriesToAdd += $entry
            }
        }

        # Add missing entries
        if ($entriesToAdd.Count -gt 0) {
            Write-Host "Blocking ads by updating hosts file..." -ForegroundColor Yellow
            Add-Content -Path $hostsFile -Value $entriesToAdd
        }

        # Define Edge launch arguments
        $arguments = @(
            "--app=$url"              
            "--inprivate"
            "--disable-features=InterestFeedContent,AdTagging,InterestFeed"  
            "--block-new-web-contents"
        )
        
        # Start Edge
        Start-Process -FilePath $edgePath -ArgumentList $arguments

        # Wait a few seconds for Edge to launch before restoring the hosts file
        Start-Sleep -Seconds 3

        # Restore the hosts file by removing added entries
        $updatedHosts = Get-Content -Path $hostsFile | Where-Object { $_ -notmatch [regex]::Escape($adEntries -join "|") }
        Set-Content -Path $hostsFile -Value $updatedHosts

        Write-Host "Restored original hosts file." -ForegroundColor Green

    } catch {
        Write-Host "Error during execution: $_" -ForegroundColor Red
    }
}



function Test-DeadPixel {
    $url = "https://lcdtech.info/en/tests/dead.pixel.htm"
    $edgePath = Get-EdgePath

    try {
        $arguments = @(
            "--app=$url"              
            "--inprivate"
        )
        
        Start-Process -FilePath $edgePath -ArgumentList $arguments
    } catch {
        Write-Host "Error during iframe execution: $_" -ForegroundColor Red
    }
}
