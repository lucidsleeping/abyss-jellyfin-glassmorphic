$ErrorActionPreference = "Stop"

# Constants 

$REPO     = "lucidsleeping/abyss-jellyfin-touch-ui"
$BRANCH   = "main"
$RAW      = "https://raw.githubusercontent.com/$REPO/$BRANCH"
$REPO_URL = "https://github.com/$REPO"

$SPOTLIGHT_FILES = @(
    "scripts/spotlight/spotlight.html",
    "scripts/spotlight/spotlight.css",
    "scripts/spotlight/home-html.chunk.js"
)

$TOUCH_FILES = @(
    "scripts/touch/abyss-touch.js"
)

$THEME_FILES = @(
    "abyss.css",
    "styles/abyss-liquid-glass.css",
    "styles/abyss-player.css",
    "styles/abyss-touch.css",
    "styles/abyss-layout.css",
    "styles/abyss-je.css",
    "styles/abyss-mbe.css"
)

$ScriptDir = $PSScriptRoot

# Helpers 

function Write-Step { param($msg) Write-Host " $msg" -ForegroundColor Cyan }
function Write-Ok   { param($msg) Write-Host " [+] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host " [!] $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host " [X] $msg" -ForegroundColor Red }
function Write-Skip { param($msg) Write-Host " [-] $msg" -ForegroundColor DarkGray }
function Write-Info { param($msg) Write-Host "     $msg" -ForegroundColor DarkGray }

function Exit-WithError {
    param($msg)
    Write-Host ""
    if ($msg) { Write-Fail $msg }
    Read-Host " Press Enter to exit"
    exit 1
}

function Invoke-WithTrap {
    param([ScriptBlock]$block)
    try {
        & $block
    } catch {
        Write-Host ""
        Write-Fail "An unexpected error occurred:"
        Write-Info "$_"
        Read-Host " Press Enter to exit"
        exit 1
    }
}

function Show-Header {
    param($subtitle)
    Clear-Host
    Write-Host ""
    Write-Host " ================================================" -ForegroundColor Cyan
    Write-Host "  Abyss Theme - $subtitle" -ForegroundColor White
    Write-Host "  $REPO_URL" -ForegroundColor DarkGray
    Write-Host " ================================================" -ForegroundColor Cyan
    Write-Host ""
}

# Locate Jellyfin web directory 

function Get-JellyfinWebDir {
    $candidates = @(
        "C:\Program Files\Jellyfin\Server\jellyfin-web",
        "C:\Program Files (x86)\Jellyfin\Server\jellyfin-web",
        "C:\ProgramData\Jellyfin\Server\jellyfin-web"
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }

    Write-Warn "Could not auto-detect Jellyfin web directory."
    Write-Host " Enter the full path to your jellyfin-web folder:" -ForegroundColor Yellow
    Write-Info "Example: C:\Program Files\Jellyfin\Server\jellyfin-web"
    $path = Read-Host "  Path"
    if (-not (Test-Path $path)) {
        Exit-WithError "Directory not found: $path"
    }
    return $path
}

# Download files — always re-downloads to pick up latest versions

function Get-AbyssFile {
    param($repoPath, $destPath)
    $url     = "$RAW/$repoPath"
    $destDir = Split-Path $destPath
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    try {
        Invoke-WebRequest -Uri $url -OutFile $destPath -UseBasicParsing
        Write-Ok "Downloaded: $(Split-Path $destPath -Leaf)"
    } catch {
        Exit-WithError "Failed to download $repoPath - check your internet connection."
    }
}

function Sync-SpotlightFiles {
    param($abyssDir)
    Write-Step "Downloading latest spotlight files..."
    Write-Host ""
    foreach ($file in $SPOTLIGHT_FILES) {
        $destPath = Join-Path $abyssDir (Split-Path $file -Leaf)
        Get-AbyssFile $file $destPath
    }
    Write-Host ""
}

function Sync-ThemeFiles {
    param($abyssDir)
    Write-Step "Installing Abyss theme CSS..."
    Write-Host ""
    $stylesDir = Join-Path $abyssDir "styles"
    New-Item -ItemType Directory -Path $stylesDir -Force | Out-Null

    $localCss = Join-Path $ScriptDir "abyss.css"
    if (Test-Path $localCss) {
        Copy-Item -Path $localCss -Destination (Join-Path $abyssDir "abyss.css") -Force
        Write-Ok "Installed: abyss.css (from local repo)"
        Get-ChildItem -Path (Join-Path $ScriptDir "styles") -Filter "*.css" -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination (Join-Path $stylesDir $_.Name) -Force
            Write-Ok "Installed: styles/$($_.Name) (from local repo)"
        }
    } else {
        Write-Warn "Local abyss.css not found; downloading theme from GitHub..."
        foreach ($file in $THEME_FILES) {
            if ($file -like "styles/*") {
                $dest = Join-Path $abyssDir $file
            } else {
                $dest = Join-Path $abyssDir (Split-Path $file -Leaf)
            }
            Get-AbyssFile $file $dest
        }
    }
    Write-Host ""
}

function Get-AbyssCssImport {
    $version = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    return "@import url('/abyss/abyss.css?v=$version');`n/* Customise Abyss: https://aumgupta.github.io/abyss-jellyfin/ */"
}

function Sync-TouchFiles {
    param($abyssDir)
    Write-Step "Downloading touch UI files..."
    Write-Host ""
    foreach ($file in $TOUCH_FILES) {
        $destPath = Join-Path $abyssDir (Split-Path $file -Leaf)
        Get-AbyssFile $file $destPath
    }
    Write-Host ""
}

function Install-TouchUi {
    param($webDir, $abyssDir)

    Write-Step "Installing touch UI..."
    Write-Host ""

    $uiDir   = Join-Path $webDir "ui"
    $src     = Join-Path $abyssDir "abyss-touch.js"
    $dest    = Join-Path $uiDir "abyss-touch.js"
    $index   = Join-Path $webDir "index.html"
    $tag     = '<script src="ui/abyss-touch.js" defer></script>'

    if (-not (Test-Path $src)) { Exit-WithError "Missing abyss-touch.js - try running setup again to re-download." }

    if (-not (Test-Path $uiDir)) { New-Item -ItemType Directory -Path $uiDir -Force | Out-Null }
    Copy-Item $src $dest -Force
    Write-Ok "Copied: abyss-touch.js"

    if (-not (Test-Path $index)) {
        Write-Warn "index.html not found; touch script not linked."
        Write-Info "Add manually before </body>: $tag"
        Write-Host ""
        return
    }

    $html = Get-Content $index -Raw -Encoding UTF8
    if ($html -match 'abyss-touch\.js') {
        Write-Skip "Touch script already linked in index.html."
    } else {
        $bak = "$index.bak.abyss"
        if (-not (Test-Path $bak)) {
            Copy-Item $index $bak -Force
            Write-Ok "Backed up index.html."
        }
        if ($html -match '</body>') {
            $html = $html -replace '</body>', "$tag`n</body>", 1
        } else {
            $html = "$html`n$tag`n"
        }
        Set-Content $index $html -Encoding UTF8 -NoNewline
        Write-Ok "Linked touch script in index.html."
    }
    Write-Host ""
}

function Uninstall-TouchUi {
    param($webDir)

    Write-Step "Removing touch UI..."
    Write-Host ""

    $uiDir   = Join-Path $webDir "ui"
    $touchJs = Join-Path $uiDir "abyss-touch.js"
    $index   = Join-Path $webDir "index.html"
    $bak     = "$index.bak.abyss"

    if (Test-Path $touchJs) {
        Remove-Item $touchJs -Force
        Write-Ok "Removed: abyss-touch.js"
    } else {
        Write-Skip "Not found: abyss-touch.js"
    }

    if ((Test-Path $index) -and (Get-Content $index -Raw) -match 'abyss-touch\.js') {
        if (Test-Path $bak) {
            Copy-Item $bak $index -Force
            Remove-Item $bak -Force
            Write-Ok "Restored index.html from backup."
        } else {
            $html = Get-Content $index -Raw -Encoding UTF8
            $html = [regex]::Replace($html, '\s*<script[^>]*abyss-touch\.js[^>]*>\s*</script>\s*', "`n", 'IgnoreCase')
            Set-Content $index $html -Encoding UTF8 -NoNewline
            Write-Ok "Removed touch script tag from index.html."
        }
    } else {
        Write-Skip "Touch script not linked in index.html."
    }
    Write-Host ""
}

# Authenticate 

function Connect-Jellyfin {
    param($serverUrl)

    $maxTries     = 3
    $authResponse = $null

    for ($try = 1; $try -le $maxTries; $try++) {

        if ($try -gt 1) {
            for ($i = 0; $i -lt 5; $i++) {
                [Console]::SetCursorPosition(0, [Console]::CursorTop - 1)
                Write-Host (" " * [Console]::WindowWidth) -NoNewline
                [Console]::SetCursorPosition(0, [Console]::CursorTop)
            }
            Write-Host " [X] Invalid credentials. Attempt $($try - 1) of $maxTries" -ForegroundColor Red
            Write-Host ""
        }

        Write-Host " Jellyfin admin credentials" -ForegroundColor Yellow
        $username       = Read-Host "  Username"
        $securePassword = Read-Host "  Password" -AsSecureString
        $password       = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
        )

        $authBody    = @{ Username = $username; Pw = $password } | ConvertTo-Json
        $authHeaders = @{
            "Content-Type"         = "application/json"
            "X-Emby-Authorization" = 'MediaBrowser Client="Abyss Setup", Device="Setup", DeviceId="abyss-setup", Version="1.0"'
        }

        try {
            $authResponse = Invoke-RestMethod `
                -Uri "$serverUrl/Users/AuthenticateByName" `
                -Method Post -Headers $authHeaders -Body $authBody
            break
        } catch {
            if ($try -eq $maxTries) {
                Exit-WithError "Authentication failed after $maxTries attempts."
            }
        }
    }

    Write-Host ""
    Write-Ok "Authenticated as: $($authResponse.User.Name)"
    Write-Host ""

    return $authResponse
}

function Get-ApiHeaders {
    param($token)
    return @{
        "Content-Type"         = "application/json"
        "X-Emby-Authorization" = "MediaBrowser Client=`"Abyss Setup`", Device=`"Setup`", DeviceId=`"abyss-setup`", Version=`"1.0`", Token=`"$token`""
    }
}

# Install 

function Install-Abyss {
    Show-Header "Installer"

    # Server URL
    Write-Host " Jellyfin server URL" -ForegroundColor Yellow
    Write-Host " Press ENTER to use default (http://localhost:8096)" -ForegroundColor DarkGray
    $inputUrl  = Read-Host "  URL"
    $serverUrl = if ($inputUrl.Trim() -eq "") { "http://localhost:8096" } else { $inputUrl.Trim().TrimEnd("/") }
    Write-Ok "Server: $serverUrl"
    Write-Host ""

    # Authenticate
    Write-Step "Authenticating..."
    Write-Host ""
    $auth       = Connect-Jellyfin $serverUrl
    $token      = $auth.AccessToken
    $userId     = $auth.User.Id
    $apiHeaders = Get-ApiHeaders $token

    # Locate Jellyfin web dir
    Write-Step "Locating Jellyfin web directory..."
    $webDir   = Get-JellyfinWebDir
    $abyssDir = Join-Path $webDir "abyss"
    if (-not (Test-Path $abyssDir)) {
        New-Item -ItemType Directory -Path $abyssDir -Force | Out-Null
        Write-Ok "Created: $abyssDir"
    } else {
        Write-Ok "Found: $abyssDir"
    }
    Write-Host ""

    # Theme + spotlight + touch (local repo preferred for CSS)
    Sync-ThemeFiles $abyssDir
    Sync-SpotlightFiles $abyssDir
    Sync-TouchFiles $abyssDir

    # Apply Abyss CSS (served from jellyfin-web/abyss/, not jsDelivr)
    Write-Step "Applying Abyss CSS..."
    try {
        $branding           = Invoke-RestMethod -Uri "$serverUrl/Branding/Configuration" -Method Get -Headers $apiHeaders
        $branding.CustomCss = Get-AbyssCssImport
        Invoke-RestMethod -Uri "$serverUrl/System/Configuration/Branding" -Method Post -Headers $apiHeaders -Body ($branding | ConvertTo-Json -Depth 10) | Out-Null
        Write-Ok "Abyss CSS applied."
    } catch {
        Write-Fail "Failed to apply CSS."
        Write-Info "Add this manually in Dashboard > General > Custom CSS:"
        Write-Info "@import url('/abyss/abyss.css');"
    }
    Write-Host ""

    # Configure theme settings
    Write-Step "Configuring theme settings..."
    try {
        $displayPrefs = Invoke-RestMethod -Uri "$serverUrl/DisplayPreferences/usersettings?userId=$userId&client=emby" -Method Get -Headers $apiHeaders
        $displayPrefs.CustomPrefs.dashboardTheme = "dark"
        Write-Ok "Dashboard theme set to Dark."

        # Ask before reordering home sections
        Write-Host ""
        Write-Host " Reorder home screen sections?" -ForegroundColor Yellow
        Write-Info "Recommended order: Continue Watching, Next Up, My Media, Recently Added."
        Write-Info "(Recommended for best experience with Abyss)"
        $reorderChoice = Read-Host "  Reorder sections? [Y/n]"
        if ($reorderChoice.Trim().ToUpper() -eq "Y") {
            $displayPrefs.CustomPrefs.homesection0 = "resume"
            $displayPrefs.CustomPrefs.homesection1 = "nextup"
            $displayPrefs.CustomPrefs.homesection2 = "smalllibrarytiles"
            $displayPrefs.CustomPrefs.homesection3 = "latestmedia"
            $displayPrefs.CustomPrefs.homesection4 = "none"
            $displayPrefs.CustomPrefs.homesection5 = "none"
            $displayPrefs.CustomPrefs.homesection6 = "none"
            $displayPrefs.CustomPrefs.homesection7 = "none"
            $displayPrefs.CustomPrefs.homesection8 = "none"
            $displayPrefs.CustomPrefs.homesection9 = "none"
            Write-Ok "Home screen sections configured."
        } else {
            Write-Skip "Home screen sections left unchanged."
        }

        Invoke-RestMethod -Uri "$serverUrl/DisplayPreferences/usersettings?userId=$userId&client=emby" -Method Post -Headers $apiHeaders -Body ($displayPrefs | ConvertTo-Json -Depth 10) | Out-Null
    } catch {
        Write-Warn "Could not configure theme settings automatically."
        Write-Info "Set manually: Settings > Display > Server Dashboard Theme > Dark"
    }
    Write-Host ""

    # Install spotlight
    Write-Step "Installing Spotlight add-on..."
    Write-Host ""

    $uiDir = Join-Path $webDir "ui"
    if (-not (Test-Path $uiDir)) {
        New-Item -ItemType Directory -Path $uiDir -Force | Out-Null
        Write-Ok "Created ui folder."
    } else {
        Write-Skip "ui folder exists."
    }

    foreach ($f in @("spotlight.html", "spotlight.css")) {
        $src  = Join-Path $abyssDir $f
        $dest = Join-Path $uiDir $f
        if (-not (Test-Path $src)) { Exit-WithError "Missing file: $f - try running setup again to re-download." }
        Copy-Item $src $dest -Force
        Write-Ok "Copied: $f"
    }

    $chunkFile = Get-ChildItem "$webDir\home-html.*.chunk.js" | Select-Object -First 1 -ExpandProperty FullName
    if (-not $chunkFile) {
        Write-Warn "Could not find home-html.*.chunk.js automatically."
        $chunkName = Read-Host "  Enter the exact filename"
        $chunkFile = Join-Path $webDir $chunkName
        if (-not (Test-Path $chunkFile)) { Exit-WithError "Chunk file not found: $chunkFile" }
    }
    Write-Ok "Found chunk: $(Split-Path $chunkFile -Leaf)"

    if (-not (Test-Path "$chunkFile.bak")) {
        Copy-Item $chunkFile "$chunkFile.bak" -Force
        Write-Ok "Backup created."
    } else {
        Write-Skip "Backup already exists."
    }

    $chunkSrc = Join-Path $abyssDir "home-html.chunk.js"
    if (-not (Test-Path $chunkSrc)) { Exit-WithError "Missing home-html.chunk.js - try running setup again to re-download." }
    Copy-Item $chunkSrc $chunkFile -Force
    Write-Ok "Chunk patched."
    Write-Host ""

    Install-TouchUi $webDir $abyssDir

    # Restart
    Write-Step "Restarting Jellyfin..."
    try {
        Invoke-RestMethod -Uri "$serverUrl/System/Restart" -Method Post -Headers $apiHeaders | Out-Null
        Write-Ok "Restart triggered. Wait a few seconds then refresh."
    } catch {
        Write-Warn "Could not restart automatically. Please restart Jellyfin manually."
    }

    # Done
    Write-Host ""
    Write-Host " ================================================" -ForegroundColor Cyan
    Write-Host "  Installation complete!" -ForegroundColor Green
    Write-Host " ================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Next steps:" -ForegroundColor White
    Write-Host "    1. Delete browser cache" -ForegroundColor Red
    Write-Host "    2. Hard refresh your browser (Ctrl+F5)" -ForegroundColor Yellow
    Write-Host "    3. Relaunch Jellyfin Media Player if using the desktop app" -ForegroundColor DarkGray

    try {
        $displayPrefs = Invoke-RestMethod -Uri "$serverUrl/DisplayPreferences/usersettings?userId=$userId&client=emby" -Method Get -Headers $apiHeaders
        $currentTheme = $displayPrefs.CustomPrefs.appTheme
        if ($currentTheme -ne "dark" -and $currentTheme -ne "Dark") {
            Write-Host ""
            Write-Host "  Important:" -ForegroundColor Red
            Write-Host "    4. Go to Settings > Display > Theme and set it to Dark" -ForegroundColor Yellow
            Write-Info "Abyss requires the Dark base theme to display correctly."
        }
    } catch {
        Write-Host ""
        Write-Host "  Important:" -ForegroundColor Red
        Write-Host "    4. Go to Settings > Display > Theme and set it to Dark" -ForegroundColor Yellow
        Write-Info "Abyss requires the Dark base theme to display correctly."
    }

    Write-Host ""
    Write-Host "  Tip: Turn on 'Show Backdrops' in display settings for best experience." -ForegroundColor Green
    Write-Host ""
    Write-Host "  Customise your theme:" -ForegroundColor White
    Write-Host "    https://aumgupta.github.io/abyss-jellyfin/" -ForegroundColor Cyan
    Write-Host ""
    Read-Host " Press Enter to exit"
}

# Uninstall 

function Uninstall-Abyss {
    Show-Header "Uninstaller"

    # Server URL
    Write-Host " Jellyfin server URL" -ForegroundColor Yellow
    Write-Host " Press ENTER to use default (http://localhost:8096)" -ForegroundColor DarkGray
    $inputUrl  = Read-Host "  URL"
    $serverUrl = if ($inputUrl.Trim() -eq "") { "http://localhost:8096" } else { $inputUrl.Trim().TrimEnd("/") }
    Write-Ok "Server: $serverUrl"
    Write-Host ""

    # Authenticate
    Write-Host ""
    $auth       = Connect-Jellyfin $serverUrl
    $token      = $auth.AccessToken
    $apiHeaders = Get-ApiHeaders $token

    # Locate Jellyfin web dir
    Write-Step "Locating Jellyfin web directory..."
    $webDir = Get-JellyfinWebDir
    Write-Ok "Found: $webDir"
    Write-Host ""

    # Clear CSS
    Write-Step "Clearing custom CSS..."
    try {
        $branding           = Invoke-RestMethod -Uri "$serverUrl/Branding/Configuration" -Method Get -Headers $apiHeaders
        $branding.CustomCss = ""
        Invoke-RestMethod -Uri "$serverUrl/System/Configuration/Branding" -Method Post -Headers $apiHeaders -Body ($branding | ConvertTo-Json -Depth 10) | Out-Null
        Write-Ok "Custom CSS cleared."
    } catch {
        Write-Fail "Failed to clear CSS."
        Write-Info "Clear it manually in Dashboard > General > Custom CSS."
    }
    Write-Host ""

    # Restore chunk
    Write-Step "Restoring home-html chunk..."
    $chunkFile = Get-ChildItem "$webDir\home-html.*.chunk.js" | Select-Object -First 1 -ExpandProperty FullName
    if (-not $chunkFile) {
        Write-Warn "Could not find home-html.*.chunk.js automatically."
        $chunkName = Read-Host "  Enter the exact filename"
        $chunkFile = Join-Path $webDir $chunkName
        if (-not (Test-Path $chunkFile)) { Exit-WithError "Chunk file not found: $chunkFile" }
    }

    if (Test-Path "$chunkFile.bak") {
        Copy-Item "$chunkFile.bak" $chunkFile -Force
        Remove-Item "$chunkFile.bak" -Force
        Write-Ok "Chunk restored."
        Write-Ok "Backup removed."
    } else {
        Write-Warn "No backup found. Chunk could not be restored."
        Write-Info "You may need to reinstall Jellyfin."
    }
    Write-Host ""

    Uninstall-TouchUi $webDir

    # Remove spotlight files
    Write-Step "Removing spotlight files..."
    $uiDir = Join-Path $webDir "ui"
    foreach ($f in @("spotlight.html", "spotlight.css")) {
        $path = Join-Path $uiDir $f
        if (Test-Path $path) {
            Remove-Item $path -Force
            Write-Ok "Removed: $f"
        } else {
            Write-Skip "Not found: $f"
        }
    }

    if (Test-Path $uiDir) {
        if ((Get-ChildItem $uiDir).Count -eq 0) {
            Remove-Item $uiDir -Force
            Write-Ok "Removed empty ui folder."
        } else {
            Write-Skip "ui folder has other files, leaving in place."
        }
    }
    Write-Host ""

    # Restart
    Write-Step "Restarting Jellyfin..."
    try {
        Invoke-RestMethod -Uri "$serverUrl/System/Restart" -Method Post -Headers $apiHeaders | Out-Null
        Write-Ok "Restart triggered. Wait a few seconds then refresh."
    } catch {
        Write-Warn "Could not restart automatically. Please restart Jellyfin manually."
    }

    # Done
    Write-Host ""
    Write-Host " ================================================" -ForegroundColor Cyan
    Write-Host "  Uninstall complete!" -ForegroundColor Green
    Write-Host " ================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Next steps:" -ForegroundColor White
    Write-Host "    1. Delete browser cache" -ForegroundColor Red
    Write-Host "    2. Hard refresh your browser (Ctrl+F5)" -ForegroundColor Yellow
    Write-Host "    3. Relaunch Jellyfin Media Player if using the desktop app" -ForegroundColor DarkGray
    Write-Host ""
    Read-Host " Press Enter to exit"
}

# Entry point 

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    if ($exePath -like "*.exe") {
        Start-Process -FilePath $exePath -Verb RunAs
    } elseif ($PSCommandPath) {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    } else {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm https://raw.githubusercontent.com/AumGupta/abyss-jellyfin/main/setup.ps1 | iex`"" -Verb RunAs
    }
    exit
}

Invoke-WithTrap {
    Show-Header "Setup"

    Write-Host "  What would you like to do?" -ForegroundColor White
    Write-Host ""
    Write-Host "   [1] Install" -ForegroundColor Green -NoNewline
    Write-Host "        [2] Uninstall" -ForegroundColor Yellow
    Write-Host ""
    $choice = Read-Host "  Enter 1 or 2"

    switch ($choice) {
        "1" { Install-Abyss }
        "2" { Uninstall-Abyss }
        default { Exit-WithError "Invalid choice. Please enter 1 or 2." }
    }
}