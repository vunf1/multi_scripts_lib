
Add-Type -AssemblyName System.Windows.Forms

function Show-Confirmation {
    param (
        [string]$message,
        [string]$title
    )
    
    # Create a hidden form to enforce STA mode
    $form = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true; Visible = $false }
    
    # Show the MessageBox in a proper STA thread
    $response = [System.Windows.Forms.MessageBox]::Show($form, $message, $title, 
        [System.Windows.Forms.MessageBoxButtons]::YesNo, 
        [System.Windows.Forms.MessageBoxIcon]::Question)
    
    return $response
}

function Show-Info {
    param (
        [string]$message,
        [string]$title
    )
    $form = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true; Visible = $false }
    return [System.Windows.Forms.MessageBox]::Show($form, $message, $title, 
        [System.Windows.Forms.MessageBoxButtons]::OK, 
        [System.Windows.Forms.MessageBoxIcon]::Information)
}

function Show-Warning {
    param (
        [string]$message,
        [string]$title
    )
    $form = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true; Visible = $false }
    return [System.Windows.Forms.MessageBox]::Show($form, $message, $title, 
        [System.Windows.Forms.MessageBoxButtons]::OK, 
        [System.Windows.Forms.MessageBoxIcon]::Warning)
}

function Show-OkCancel {
    param (
        [string]$message,
        [string]$title
    )

    # Create a hidden form to enforce STA mode and ensure proper MessageBox behavior
    $form = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true; Visible = $false }
    
    # Show the MessageBox in a proper STA thread with OK and Cancel buttons
    $response = [System.Windows.Forms.MessageBox]::Show($form, $message, $title, 
        [System.Windows.Forms.MessageBoxButtons]::OKCancel, 
        [System.Windows.Forms.MessageBoxIcon]::Information)
    
    return $response
}

function Show-Error {
    param (
        [string]$message,
        [string]$title
    )

    # Create a hidden form to enforce STA mode and avoid thread-related issues
    $form = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true; Visible = $false }
    
    # Show an error message box with an OK button
    return [System.Windows.Forms.MessageBox]::Show($form, $message, $title, 
        [System.Windows.Forms.MessageBoxButtons]::OK, 
        [System.Windows.Forms.MessageBoxIcon]::Error)
}
# Unicode Emojis Using UTF-8 Encoding
$unicodeEmojiGrinningFace = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x98, 0x80))  # 😀 Grinning Face
$unicodeEmojiSmilingFaceWithSmilingEyes = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x98, 0x8A))  # 😊 Smiling Face with Smiling Eyes
$unicodeEmojiThumbsUp = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x91, 0x8D))  # 👍 Thumbs Up
$unicodeEmojiThumbsDown = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x91, 0x8E))  # 👎 Thumbs Down
$unicodeEmojiRocket = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x9A, 0x80))  # 🚀 Rocket
$unicodeEmojiCheckMark = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xE2, 0x9C, 0x85))  # ✅ Check Mark
$unicodeEmojiCrossMark = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xE2, 0x9D, 0x8C))  # ❌ Cross Mark
$unicodeEmojiWarning = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xE2, 0x9A, 0xA0))  # ⚠️ Warning
$unicodeEmojiInformation = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xE2, 0x84, 0xB9))  # ℹ️ Information
$unicodeEmojiHourglass = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xE2, 0x8C, 0x9B))  # ⌛ Hourglass
$unicodeEmojiLightBulb = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x92, 0xA1))  # 💡 Light Bulb
$unicodeEmojiFire = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x94, 0xA5))  # 🔥 Fire
$unicodeEmojiHeart = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xE2, 0x99, 0xA5))  # ♥ Heart
$unicodeEmojiStar = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xE2, 0xAD, 0x90))  # ⭐ Star
$unicodeEmojiWave = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x8C, 0x8A))  # 🌊 Wave
$unicodeEmojiBarChart = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x93, 0x8A))  # 📊 Bar Chart
$unicodeEmojiKeyboard = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x96, 0xA4))  # ⌨️ Keyboard
$unicodeEmojiGlobe = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x8C, 0x90))  # 🌐 Globe
$unicodeEmojiLock = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x94, 0x92))  # 🔒 Lock
$unicodeEmojiSlot = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x97, 0xBC))  # 🗼 RAM Slot (Tower)
$unicodeEmojiComputer = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x92, 0xBB))  # 💻 Computer
$unicodeEmojiChip = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0xA7, 0xA1))  # 🧡 Chip
$unicodeEmojiDatabase = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x93, 0x81))  # 📁 Database
$unicodeEmojiServer = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x97, 0x82))  # 🖂 Server
$unicodeEmojiPrinter = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x96, 0xA8))  # 🖨️ Printer
$unicodeEmojiBattery = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x94, 0x8B))  # 🔋 Battery
$unicodeEmojiNetwork = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x93, 0xA3))  # 📣 Network
$unicodeEmojiHardDrive = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x96, 0xA5))  # 🖥️ Hard Drive
$unicodeEmojiBug = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x90, 0x9E))  # 🐞 Bug
$unicodeEmojiWrench = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x94, 0xA7))  # 🔧 Wrench
$unicodeEmojiClock = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x95, 0x92))  # ⏲️ Clock
$unicodeEmojiTrans = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x94, 0xA3))  # 🔣 
$unicodeEmojiMagnifyingGlass = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x94, 0x8D))  # 🔍 Magnifying Glass
$unicodeEmojiFolder = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x93, 0x82))  # 📂 Folder
$unicodeEmojiSatellite = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x9A, 0xA1))  # 🚡 Satellite

$unicodeEmojiCPU = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0xA7, 0xA1))  # 🧠 CPU / Processor

$unicodeEmojiChip = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x92, 0xBB))  # 💻 Chipset
$unicodeEmojiCooling = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x92, 0xA7))  # 💧 Cooling System
$unicodeEmojiFan = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0xA8, 0x81))  # 🌀 Fan / Airflow
$unicodeEmojiStorage = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xF0, 0x9F, 0x93, 0x81))  # 📁 SSD / HDD Storage

# Unicode Fullwidth Numbers (Large Format)
$unicodeEmojiFullwidthZero = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xEF, 0xBC, 0x90))  # ０ Fullwidth Zero
$unicodeEmojiFullwidthOne = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xEF, 0xBC, 0x91))  # １ Fullwidth One
$unicodeEmojiFullwidthTwo = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xEF, 0xBC, 0x92))  # ２ Fullwidth Two
$unicodeEmojiFullwidthThree = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xEF, 0xBC, 0x93))  # ３ Fullwidth Three
$unicodeEmojiFullwidthFour = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xEF, 0xBC, 0x94))  # ４ Fullwidth Four
$unicodeEmojiFullwidthFive = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xEF, 0xBC, 0x95))  # ５ Fullwidth Five
$unicodeEmojiFullwidthSix = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xEF, 0xBC, 0x96))  # ６ Fullwidth Six
$unicodeEmojiFullwidthSeven = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xEF, 0xBC, 0x97))  # ７ Fullwidth Seven
$unicodeEmojiFullwidthEight = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xEF, 0xBC, 0x98))  # ８ Fullwidth Eight
$unicodeEmojiFullwidthNine = [System.Text.Encoding]::UTF8.GetString([byte[]]@(0xEF, 0xBC, 0x99))  # ９ Fullwidth Nine
