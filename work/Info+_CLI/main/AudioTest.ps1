function Show-YouTubeIframe {
    param (
        [string]$YouTubeURL = "https://www.youtube.com/embed/6TWJaFD6R2s?start=6&autoplay=1&mute=1&enablejsapi=1",
        [string]$DeveloperName = "Vunf1",
        [string]$GitHubURL = "https://github.com/vunf1"
    )
    
    $htmlContent = @"
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <link rel="icon" href="https://img.icons8.com/ios-filled/50/ffffff/speaker.png" type="image/png">
        <title>Audio Test</title>
        <style>
            body {
                margin: 0;
                font-family: Arial, sans-serif;
                display: flex;
                flex-direction: column;
                justify-content: center;
                align-items: center;
                height: 100vh;
                background-color: #121212;
                color: #FFFFFF;
            }
            iframe {
                width: 90vw;
                height: 90vh;
                border: none;
                border-radius: 4px;
            }
            .button {
                position: absolute;
                width: 90vw;
                height: 7vh;
                background-color: rgb(59, 59, 59);
                color: white;
                padding: 15px 30px;
                font-size: 20px; 
                font-weight: bold;
                border: none;
                border-radius: 10px; 
                cursor: pointer;
                display: flex;
                align-items: center;
                justify-content: center;
            }
            .button img {
                width: 20px; 
                height: 20px;
                margin-right: 8px;
            }
            .unmute-button {
                top: 5vh;
            }
            .refresh-button {
                top: 13vh;
            }
            .unmute-button:hover, .refresh-button:hover {
                background-color: rgb(80, 80, 80);
                transform: scale(1.05);
            }
            footer {
                position: absolute;
                bottom: 10vh; 
                width: 100%; 
                text-align: center;
                padding: 10px;
                font-size: 12px; 
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
        </style>
        <script>
            document.addEventListener("DOMContentLoaded", function () {
                let player;

                /* Entry point to create and configure the YouTube player */
                function onYouTubeIframeAPIReady() { /* Registers an event listener for when the player is ready */
                    player = new YT.Player('youtubeIframe', {
                        events: { 'onReady': onPlayerReady }
                    });
                }

                function onPlayerReady() {
                    document.getElementById('unmuteButton').style.display = 'block';
                    document.getElementById('refreshButton').style.display = 'block';
                }

                function toggleMute() {
                    if (player) {
                        const buttonIcon = document.getElementById('buttonIcon');
                        const buttonText = document.getElementById('buttonText');
                        if (player.isMuted()) {
                            player.unMute();
                            buttonIcon.src = "https://img.icons8.com/ios-filled/50/FFFFFF/no-audio--v1.png";
                            buttonText.textContent = "CLICK TO MUTE";
                        } else {
                            player.mute();
                            buttonIcon.src = "https://img.icons8.com/ios-filled/50/ffffff/speaker.png";
                            buttonText.textContent = "CLICK TO UNMUTE";
                        }
                    }
                }

                function refreshIframe() {
                    const iframe = document.getElementById('youtubeIframe');
                    iframe.src = iframe.src; // Reload iframe source
                    player.mute();
                    buttonIcon.src = "https://img.icons8.com/ios-filled/50/ffffff/speaker.png";
                    buttonText.textContent = "CLICK TO UNMUTE";
                }

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

                const tag = document.createElement('script');
                tag.src = "https://www.youtube.com/iframe_api";
                document.body.appendChild(tag);

                document.getElementById('unmuteButton').addEventListener('click', toggleMute);
                document.getElementById('refreshButton').addEventListener('click', refreshIframe);

                window.onYouTubeIframeAPIReady = onYouTubeIframeAPIReady;
            });
        </script>
    </head>
    <body>
        <button id="refreshButton" class="refresh-button button">
            <img src="https://img.icons8.com/ios-filled/50/FFFFFF/restart.png" alt="Refresh Icon">
            <span>REFRESH VIDEO</span>
        </button>
        <iframe
            id="youtubeIframe"
            src="https://www.youtube.com/embed/6TWJaFD6R2s?start=6&autoplay=1&mute=1&enablejsapi=1"
            allow="autoplay"
            allowfullscreen>
        </iframe>
        <button id="unmuteButton" class="unmute-button button">
            <img id="buttonIcon" src="https://img.icons8.com/ios-filled/50/ffffff/speaker.png" alt="Speaker Icon">
            <span id="buttonText">CLICK TO UNMUTE</span>
        </button>
        <footer>
            <h5>Developed by <a href="https://github.com/vunf1" target="_blank">Vunf1</a></h5>
        </footer>
    </body>
    </html>
"@


    # Encode the HTML content as Base64 avoid the need to save the HTML file to disk. 
    # The HTML content is entirely self-contained in the data: URL, ensuring portability and ease of testing.
    $base64Content = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($htmlContent))
    
    # Construct the data URL
    $dataUrl = "data:text/html;base64,$base64Content"
    
    $edgePath = Get-EdgePath
    try {
        
        $arguments = @(
            "--app=$dataUrl"              
            "--inprivate"    
        )
        
        Start-Process -FilePath $edgePath -ArgumentList $arguments
    } catch {
        Write-Host "Error during iframe execution: $_" -ForegroundColor Red
    }
}