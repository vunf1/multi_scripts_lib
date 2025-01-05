function Show-DriverPage {
    # Define links, their URLs, and associated icon URLs
    $links = @(
        @{ Text = "INTEL"; URL = "https://www.intel.com.br/content/www/br/pt/support/detect.html"; IconURL = "https://cdn.worldvectorlogo.com/logos/intel.svg" },
        @{ Text = "AMD"; URL = "https://www.amd.com/pt/support/download/drivers.html"; IconURL = "https://cdn.worldvectorlogo.com/logos/amd-logo-1.svg" },
        @{ Text = "NVIDIA"; URL = "https://www.nvidia.com/pt-br/software/nvidia-app/"; IconURL = "https://cdn.worldvectorlogo.com/logos/nvidia.svg" },
        @{ Text = "HP"; URL = "https://support.hp.com/pt-pt/drivers"; IconURL = "https://cdn.worldvectorlogo.com/logos/hp-5.svg" },
        @{ Text = "HP Support"; URL = "https://support.hp.com/pt-pt/help/hp-support-assistant"; IconURL = "https://cdn.worldvectorlogo.com/logos/hp-2.svg" },
        @{ Text = "DELL"; URL = "https://www.dell.com/support/home/pt-pt?app=drivers&lwp=rt"; IconURL = "https://cdn.worldvectorlogo.com/logos/dell-2.svg" },
        @{ Text = "LENOVO"; URL = "https://support.lenovo.com/pt/pt/solutions/ht003029-lenovo-system-update-update-drivers-bios-and-applications"; IconURL = "https://cdn.worldvectorlogo.com/logos/lenovo-2.svg" },
        @{ Text = "FUJITSU"; URL = "https://support.ts.fujitsu.com/Deskupdate/index.asp?lng=pt"; IconURL = "https://cdn.worldvectorlogo.com/logos/fujitsu-2.svg" },
        @{ Text = "SURFACE"; URL = "https://www.microsoft.com/store/productId/9WZDNCRFJB8P"; IconURL = "https://cdn.worldvectorlogo.com/logos/microsoft-5.svg" }
    )
    
    # Generate dynamic HTML content
    $htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" href="https://www.svgrepo.com/show/420913/computer-cpu-hardware-2.svg" type="image/svg">
    
    <title>DRIVERS LINKS</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: rgb(77, 77, 77);
            margin: 5vh;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
        }
        .content {
            text-align: center;
        }
            
        .links {
            display: grid;
            grid-template-columns: repeat(3, 1fr); 
            gap: 20px;
            width: 90%; 
            margin: 0 auto;
        }
            
        .link-item {
            text-align: center; 
            display: flex;
            flex-direction: column; 
            align-items: center; 
            justify-content: center; 
        }
        .link-item img {
            width: 80%; 
            max-width: 150px; 
            height: auto; 
            margin-bottom: 10px;
        }
        .link-item a {
            display: block;
            font-size: 1.2em; /* Responsive text size */
            text-decoration: none;
            color: rgb(255, 255, 255);
        }
        .link-item a:hover {
            text-decoration: underline;
        }
        h1, h4 {
            margin: 0 0 20px;
            color: rgb(255, 255, 255);
        }
            
        footer {
            position: absolute;
            bottom: 0vh;
            width: 100%;
            text-align: center;
            padding: 10px;
            font-size: 16px;
            color: #E0E0E0;
        }
        footer a {
            text-decoration: none;
            color: #1DB954;
        }
        footer a:hover {
            text-decoration: underline;
            color: #1ED760;
        }

        @media (max-width: 768px) {
            .links {
                grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
                gap: 15px;
            }
            .link-item img {
                max-width: 120px; 
            }
            .link-item a {
                font-size: 1em; 
            }
        }

        @media (max-width: 480px) {
            .links {
                grid-template-columns: repeat(auto-fit, minmax(100px, 1fr)); 
                gap: 10px;
            }
            .link-item img {
                max-width: 100px;
            }
            .link-item a {
                font-size: 0.9em;
            }
        }
    </style>

    
    <script>    
        document.addEventListener('keydown', function (event) {
            const key = event.key.toLowerCase();
            if ((event.ctrlKey && key === 'r') || key === 'f5') {
                event.preventDefault();
                alert('Page refresh is disabled.');
            }
        });

        document.addEventListener('contextmenu', function (event) {
            event.preventDefault(); // Disable right-click menu
        });
    </script>
</head>
<body>
    <section class="content">
        <h1>Please Accept All Cookies</h1>
    </section>
    <section class="links">
"@

    # Append link entries dynamically
    foreach ($link in $links) {
        $htmlContent += @"
        <section class="link-item">
        <a href="$($link.URL)" target="_blank">
            <img src="$($link.IconURL)" alt="$($link.Text) Logo">
        </a>
        <a href="$($link.URL)" target="_blank">$($link.Text)</a>
        </section>
"@
    }

    # Close HTML tags
    $htmlContent += @"
    </section>
    <footer>
        <h5>Developed by <a href="https://github.com/vunf1" target="_blank">Vunf1</a></h5>
    </footer>
</body>
</html>
"@


    # Encode the HTML content as Base64
    $base64Content = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($htmlContent))

    # Construct the data URL
    $dataUrl = "data:text/html;base64,$base64Content"

    $edgePath = Get-EdgePath

    # Launch Edge with the Base64 content
    try {
        # Define Edge arguments
        $arguments = @(
            "--app=$dataUrl"          
            "--inprivate"
        )

        # Start Edge with the defined arguments
        Start-Process -FilePath $edgePath -ArgumentList $arguments
    } catch {
        Write-Host "Error during Edge manipulation: $_" -ForegroundColor Red
    }
}