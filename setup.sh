#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Abyss Jellyfin Theme - Linux / macOS Installer / Uninstaller
# https://github.com/AumGupta/abyss-jellyfin
# ==============================================================================

# Fallback download source (only used when a file is missing from the local repo)
REPO="${ABYSS_REPO:-lucidsleeping/abyss-jellyfin-glassmorphic}"
BRANCH="${ABYSS_BRANCH:-main}"
RAW="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
REPO_URL="https://github.com/${REPO}"

SPOTLIGHT_FILES=(
    "scripts/spotlight/spotlight.html"
    "scripts/spotlight/spotlight.css"
    "scripts/spotlight/home-html.chunk.js"
    "scripts/spotlight/abyss-spotlight-inject.js"
)

TOUCH_FILES=(
    "scripts/touch/abyss-touch.js"
)

THEME_FILES=(
    "abyss-bundle.css"
    "abyss.css"
    "styles/abyss-liquid-glass.css"
    "styles/abyss-player.css"
    "styles/abyss-touch.css"
    "styles/abyss-layout.css"
    "styles/abyss-polish.css"
    "styles/abyss-je.css"
    "styles/abyss-mbe.css"
)

# Directory containing this setup script (local repo checkout — primary install source)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Required for a complete install (liquid glass + player OSD)
REQUIRED_THEME_FILES=(
    "abyss-bundle.css"
    "abyss.css"
    "styles/abyss-liquid-glass.css"
    "styles/abyss-player.css"
    "styles/abyss-touch.css"
    "styles/abyss-layout.css"
    "styles/abyss-polish.css"
)

# Detect OS once at startup
OS="$(uname -s)"

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

cyan="\033[0;36m"
green="\033[0;32m"
yellow="\033[0;33m"
red="\033[0;31m"
gray="\033[0;90m"
reset="\033[0m"

step() { echo -e "${cyan}  $*${reset}"; }
ok()   { echo -e "${green}  [+] $*${reset}"; }
warn() { echo -e "${yellow}  [!] $*${reset}"; }
fail() { echo -e "${red}  [X] $*${reset}"; }
skip() { echo -e "${gray}  [-] $*${reset}"; }
info() { echo -e "${gray}      $*${reset}"; }

exit_error() {
    echo ""
    [[ -n "${1:-}" ]] && fail "$1"
    read -rp "  Press Enter to exit: "
    exit 1
}

check_dependencies() {
    local missing=()
    for cmd in curl python3; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        fail "Missing required dependencies: ${missing[*]}"
        if [[ "$OS" == "Darwin" ]]; then
            info "Install them via Homebrew: brew install ${missing[*]}"
            info "Or install Xcode Command Line Tools: xcode-select --install"
        else
            info "Install them and re-run this script."
        fi
        exit 1
    fi
}

show_header() {
    clear
    echo ""
    echo -e "${cyan}  ================================================${reset}"
    echo -e "  Abyss Theme - $1"
    if [[ -f "${SCRIPT_DIR}/abyss.css" ]]; then
        info "Install source: ${SCRIPT_DIR}"
    else
        info "Fallback downloads: ${REPO_URL}"
    fi
    echo -e "${cyan}  ================================================${reset}"
    echo ""
}

# ------------------------------------------------------------------------------
# Locate Jellyfin web directory
# ------------------------------------------------------------------------------

get_jellyfin_web_dir() {
    if [[ -n "${JELLYFIN_WEB_DIR:-}" && -d "${JELLYFIN_WEB_DIR}" ]]; then
        echo "${JELLYFIN_WEB_DIR}"
        return
    fi

    local candidates=(
        # Linux; native packages
        "/usr/share/jellyfin/web"
        "/usr/lib/jellyfin/web"
        "/var/lib/jellyfin/web"
        "/opt/jellyfin/web"
        # macOS; Homebrew (intel and apple Silicon)
        "/usr/local/share/jellyfin/web"
        "/opt/homebrew/share/jellyfin/web"
        "/opt/homebrew/opt/jellyfin/web"
        "/usr/local/opt/jellyfin/web"
        # macOS; app bundle
        "/Applications/Jellyfin.app/Contents/Resources/jellyfin-web"
        "$HOME/Applications/Jellyfin.app/Contents/Resources/jellyfin-web"
        "/Applications/Jellyfin.app/Contents/Resources/web"
        "$HOME/Applications/Jellyfin.app/Contents/Resources/web"
        # Docker (official image — path inside the container)
        "/jellyfin/jellyfin-web"
    )

    for p in "${candidates[@]}"; do
        if [[ -d "$p" ]]; then
            echo "$p"
            return
        fi
    done

    warn "Could not auto-detect Jellyfin web directory."
    echo -e "${yellow}  Enter the full path to your jellyfin-web folder:${reset}"
    if [[ "$OS" == "Darwin" ]]; then
        info "Example: /opt/homebrew/share/jellyfin/web"
    else
        info "Example: /usr/share/jellyfin/web"
        info "/Applications/Jellyfin.app/Contents/Resources/jellyfin-web"
    fi
    read -rp "  Path: " path
    if [[ ! -d "$path" ]]; then
        exit_error "Directory not found: $path"
    fi
    echo "$path"
}

# ------------------------------------------------------------------------------
# Install files into jellyfin-web (local repo first, GitHub fallback)
# ------------------------------------------------------------------------------

ensure_writable_dir() {
    local dir="$1"
    mkdir -p "$dir"
    if [[ ! -w "$dir" ]]; then
        exit_error "Cannot write to ${dir}. Re-run with sudo or fix permissions."
    fi
}

download_file() {
    local repo_path="$1"
    local dest_path="$2"
    local dest_dir
    dest_dir="$(dirname "$dest_path")"

    mkdir -p "$dest_dir"

    local url="${RAW}/${repo_path}"
    if curl -fsSL "$url" -o "$dest_path"; then
        ok "Downloaded: ${repo_path}"
    else
        exit_error "Failed to download ${repo_path} from ${REPO}@${BRANCH}."
    fi
}

# Copy from SCRIPT_DIR when present; otherwise download from GitHub
install_repo_file() {
    local repo_rel="$1"
    local dest_path="$2"
    local src="${SCRIPT_DIR}/${repo_rel}"

    mkdir -p "$(dirname "$dest_path")"

    if [[ -f "$src" ]]; then
        cp -f "$src" "$dest_path"
        ok "Copied: ${repo_rel}"
        return 0
    fi

    warn "Missing locally: ${repo_rel}"
    download_file "$repo_rel" "$dest_path"
}

sync_all_abyss_assets() {
    local abyss_dir="$1"

    step "Copying Abyss theme and add-ons into jellyfin-web..."
    echo ""
    info "Repository: ${SCRIPT_DIR}"
    info "Destination:  ${abyss_dir}/"
    echo ""

    ensure_writable_dir "${abyss_dir}"
    ensure_writable_dir "${abyss_dir}/styles"

    # Theme CSS (abyss.css + all styles/*.css including liquid-glass + player)
    install_repo_file "abyss.css" "${abyss_dir}/abyss.css"

    if [[ -d "${SCRIPT_DIR}/styles" ]]; then
        local css
        for css in "${SCRIPT_DIR}"/styles/*.css; do
            [[ -f "$css" ]] || continue
            install_repo_file "styles/$(basename "$css")" "${abyss_dir}/styles/$(basename "$css")"
        done
    else
        local file
        for file in "${THEME_FILES[@]}"; do
            [[ "$file" == "abyss.css" ]] && continue
            install_repo_file "$file" "${abyss_dir}/${file}"
        done
    fi

    # Spotlight staging files (copied to ui/ later)
    local file
    for file in "${SPOTLIGHT_FILES[@]}"; do
        install_repo_file "$file" "${abyss_dir}/$(basename "$file")"
    done

    # Touch script staging (copied to ui/ later)
    for file in "${TOUCH_FILES[@]}"; do
        install_repo_file "$file" "${abyss_dir}/$(basename "$file")"
    done

    echo ""
}

verify_theme_install() {
    local abyss_dir="$1"
    local missing=()
    local f rel

    step "Verifying theme bundle..."
    echo ""

    for rel in "${REQUIRED_THEME_FILES[@]}"; do
        f="${abyss_dir}/${rel}"
        if [[ ! -f "$f" ]]; then
            missing+=("$rel")
        else
            ok "Present: ${rel}"
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo ""
        fail "Incomplete theme install. Missing:"
        for rel in "${missing[@]}"; do
            info "  - ${rel}"
        done
        exit_error "Run setup from the full repo folder containing abyss.css and styles/."
    fi

    if grep -q 'abyss-player.css' "${abyss_dir}/abyss.css" 2>/dev/null; then
        ok "abyss.css imports player OSD styles."
    else
        warn "abyss.css may be outdated (no abyss-player.css import)."
    fi

    if grep -q 'abyss-liquid-glass.css' "${abyss_dir}/abyss.css" 2>/dev/null; then
        ok "abyss.css imports liquid glass material."
    fi

    if grep -q 'abyss-layout.css' "${abyss_dir}/abyss.css" 2>/dev/null; then
        ok "abyss.css imports responsive layout alignment."
    else
        warn "abyss.css may be missing abyss-layout.css import."
    fi

    echo ""
}

# Served from jellyfin-web/abyss/ (not jsDelivr)
abyss_css_import() {
    printf "@import url('/web/abyss/abyss-bundle.css');\n/* Abyss — abyss.css + polish (cascade order) */"
}

apply_custom_css() {
    local server_url="$1"
    local api_header="$2"
    local css
    css="$(abyss_css_import)"

    step "Applying Custom CSS (Dashboard > General)..."
    echo ""

    local branding
    branding=$(curl -fsSL \
        -X GET "${server_url}/Branding/Configuration" \
        -H "X-Emby-Authorization: ${api_header}" 2>/dev/null) || true

    if [[ -z "$branding" ]]; then
        fail "Could not fetch branding config."
        info "Add manually in Dashboard > General > Custom CSS:"
        info "$(printf '%b' "$css")"
        echo ""
        return 1
    fi

    local updated_branding
    updated_branding=$(echo "$branding" | python3 -c "
import sys, json
d = json.load(sys.stdin)
d['CustomCss'] = sys.argv[1]
print(json.dumps(d))
" "$(printf '%b' "$css")")

    if curl -fsSL \
        -X POST "${server_url}/System/Configuration/Branding" \
        -H "Content-Type: application/json" \
        -H "X-Emby-Authorization: ${api_header}" \
        -d "$updated_branding" >/dev/null 2>&1; then
        ok "Custom CSS set to import /web/abyss/abyss-bundle.css"
        info "$(printf '%b' "$css" | head -1)"
    else
        fail "Failed to apply CSS via API."
        info "Paste into Dashboard > General > Custom CSS:"
        info "$(printf '%b' "$css")"
    fi
    echo ""
}

install_touch_ui() {
    local web_dir="$1"
    local abyss_dir="$2"
    local ui_dir="${web_dir}/ui"
    local src="${abyss_dir}/abyss-touch.js"
    local dest="${ui_dir}/abyss-touch.js"
    local index="${web_dir}/index.html"

    step "Installing touch UI..."
    echo ""

    [[ ! -f "$src" ]] && exit_error "Missing abyss-touch.js - try running setup again."

    mkdir -p "$ui_dir"
    cp -f "$src" "$dest"
    ok "Copied: abyss-touch.js"

    if [[ ! -f "$index" ]]; then
        warn "index.html not found; touch script not linked."
        info "Add manually to index.html before </body>:"
        info '<script src="ui/abyss-touch.js" defer></script>'
        echo ""
        return
    fi

    [[ ! -f "${index}.bak.abyss" ]] && cp -f "$index" "${index}.bak.abyss" && ok "Backed up index.html."
    python3 -c "
import sys
path = sys.argv[1]
tags = [
    '<script src=\"ui/abyss-spotlight-inject.js\" defer></script>',
    '<script src=\"ui/abyss-touch.js\" defer></script>',
]
with open(path, encoding='utf-8') as f:
    html = f.read()
changed = False
for tag in tags:
    if tag not in html:
        if '</body>' in html:
            html = html.replace('</body>', tag + chr(10) + '</body>', 1)
        else:
            html = html + chr(10) + tag + chr(10)
        changed = True
if changed:
    with open(path, 'w', encoding='utf-8') as f:
        f.write(html)
" "$index"
    if grep -q 'abyss-spotlight-inject.js' "$index" && grep -q 'abyss-touch.js' "$index"; then
        ok "Linked Abyss UI scripts in index.html."
    elif grep -q 'abyss-spotlight-inject.js' "$index" || grep -q 'abyss-touch.js' "$index"; then
        ok "Partially linked index.html (check script tags)."
    else
        warn "Could not link UI scripts in index.html; add manually before </body>."
    fi
    echo ""
}

uninstall_touch_ui() {
    local web_dir="$1"
    local ui_dir="${web_dir}/ui"
    local index="${web_dir}/index.html"

    step "Removing touch UI..."
    echo ""

    local touch_js="${ui_dir}/abyss-touch.js"
    if [[ -f "$touch_js" ]]; then
        rm -f "$touch_js"
        ok "Removed: abyss-touch.js"
    else
        skip "Not found: abyss-touch.js"
    fi

    if [[ -f "$index" ]] && grep -q 'abyss-touch.js' "$index"; then
        if [[ -f "${index}.bak.abyss" ]]; then
            cp -f "${index}.bak.abyss" "$index"
            rm -f "${index}.bak.abyss"
            ok "Restored index.html from backup."
        else
            python3 -c '
import re, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    html = f.read()
html = re.sub(r"\s*<script[^>]*abyss-touch\.js[^>]*>\s*</script>\s*", "\n", html, flags=re.I)
with open(path, "w", encoding="utf-8") as f:
    f.write(html)
' "$index"
            ok "Removed touch script tag from index.html."
        fi
    else
        skip "Touch script not linked in index.html."
    fi
    echo ""
}

# ------------------------------------------------------------------------------
# Authenticate
# ------------------------------------------------------------------------------

# Globals set by connect_jellyfin (avoids subshell/TTY issue)
ABYSS_TOKEN=""
ABYSS_USER_NAME=""
ABYSS_USER_ID=""

connect_jellyfin() {
    local server_url="$1"
    local max_tries=3
    local _response=""

    local auth_header='MediaBrowser Client="Abyss Setup", Device="Setup", DeviceId="abyss-setup", Version="1.0"'

    for ((try=1; try<=max_tries; try++)); do
        echo -e "${yellow}  Jellyfin admin credentials${reset}"
        echo -n "  Username: "
        read -r _username
        echo -n "  Password: "
        read -rs _password
        echo ""

        # Pass credentials via stdin to avoid exposure in process listings (ps/proc)
        local body
        body=$(printf '%s\n%s' "$_username" "$_password" | python3 -c "
import json, sys
lines = sys.stdin.read().split('\n', 1)
u, p = lines[0], lines[1] if len(lines) > 1 else ''
print(json.dumps({'Username': u, 'Pw': p}))
")

        _response=$(curl -fsSL \
            -X POST "${server_url}/Users/AuthenticateByName" \
            -H "Content-Type: application/json" \
            -H "X-Emby-Authorization: ${auth_header}" \
            -d "$body" 2>/dev/null) && break || true

        if ((try == max_tries)); then
            exit_error "Authentication failed after ${max_tries} attempts."
        fi

        echo ""
        fail "Invalid credentials. Attempt ${try} of ${max_tries}"
        echo ""
    done

    # Write to globals - cannot use subshell return as it breaks interactive read
    ABYSS_TOKEN=$(    echo "$_response" | python3 -c "import json,sys; print(json.load(sys.stdin)['AccessToken'])")
    ABYSS_USER_NAME=$(echo "$_response" | python3 -c "import json,sys; print(json.load(sys.stdin)['User']['Name'])")
    ABYSS_USER_ID=$(  echo "$_response" | python3 -c "import json,sys; print(json.load(sys.stdin)['User']['Id'])")
}

get_api_header() {
    local token="$1"
    echo "MediaBrowser Client=\"Abyss Setup\", Device=\"Setup\", DeviceId=\"abyss-setup\", Version=\"1.0\", Token=\"${token}\""
}

# ------------------------------------------------------------------------------
# Restart Jellyfin
# ------------------------------------------------------------------------------

restart_jellyfin() {
    local server_url="$1"
    local api_header="$2"

    step "Restarting Jellyfin..."

    # Try API restart first (works for all install methods)
    if curl -fsSL \
        -X POST "${server_url}/System/Restart" \
        -H "X-Emby-Authorization: ${api_header}" >/dev/null 2>&1; then
        ok "Restart triggered via API. Wait a few seconds then refresh."
        return
    fi

    # macOS; try Homebrew services
    if [[ "$OS" == "Darwin" ]]; then
        if command -v brew &>/dev/null && brew services list 2>/dev/null | grep -q jellyfin; then
            brew services restart jellyfin \
                && ok "Jellyfin restarted via Homebrew." \
                || warn "Could not restart via Homebrew. Restart Jellyfin manually."
            return
        fi
    fi

    # Linux; try systemctl
    if command -v systemctl &>/dev/null && systemctl list-units --type=service 2>/dev/null | grep -q jellyfin; then
        sudo systemctl restart jellyfin \
            && ok "Jellyfin service restarted." \
            || warn "Could not restart via systemctl. Restart Jellyfin manually."
        return
    fi

    warn "Could not restart automatically. Please restart Jellyfin manually."
}

# ------------------------------------------------------------------------------
# Install
# ------------------------------------------------------------------------------

install_abyss() {
    show_header "Installer"

    # Server URL
    echo -e "${yellow}  Jellyfin server URL${reset}"
    echo -e "${gray}  Press ENTER to use default (http://localhost:8096)${reset}"
    read -rp "  URL: " input_url
    local server_url="${input_url:-http://localhost:8096}"
    server_url="${server_url%/}"
    ok "Server: ${server_url}"
    echo ""

    # Authenticate
    step "Authenticating..."
    echo ""
    connect_jellyfin "$server_url"
    local token="$ABYSS_TOKEN"
    local user_name="$ABYSS_USER_NAME"
    local user_id="$ABYSS_USER_ID"

    local api_header
    api_header=$(get_api_header "$token")

    echo ""
    ok "Authenticated as: ${user_name}"
    echo ""

    # Locate web dir
    step "Locating Jellyfin web directory..."
    local web_dir
    web_dir=$(get_jellyfin_web_dir)
    local abyss_dir="${web_dir}/abyss"

    if [[ ! -d "$abyss_dir" ]]; then
        mkdir -p "$abyss_dir"
        ok "Created: ${abyss_dir}"
    else
        ok "Found: ${abyss_dir}"
    fi
    echo ""

    # Copy theme (liquid glass + player), spotlight, and touch into jellyfin-web/abyss/
    sync_all_abyss_assets "$abyss_dir"
    verify_theme_install "$abyss_dir"
    apply_custom_css "$server_url" "$api_header"

    # Configure display prefs
    step "Configuring theme settings..."
    local display_prefs
    display_prefs=$(curl -fsSL \
        -X GET "${server_url}/DisplayPreferences/usersettings?userId=${user_id}&client=emby" \
        -H "X-Emby-Authorization: ${api_header}" 2>/dev/null) || true

    if [[ -n "$display_prefs" ]]; then
        # Ask before reordering home sections
        echo ""
        echo -e "${yellow}  Reorder home screen sections?${reset}"
        info "Recommended order: Continue Watching, Next Up, My Media, Recently Added."
        info "(Recommended for best experience with Abyss)"
        read -rp "  Reorder sections? [Y/n]: " reorder_choice
        echo ""

        local updated_prefs
        if [[ "${reorder_choice^^}" == "Y" ]]; then
            updated_prefs=$(echo "$display_prefs" | python3 -c "
import sys, json
d = json.load(sys.stdin)
p = d.setdefault('CustomPrefs', {})
p['dashboardTheme'] = 'dark'
p['homesection0']   = 'resume'
p['homesection1']   = 'nextup'
p['homesection2']   = 'smalllibrarytiles'
p['homesection3']   = 'latestmedia'
for i in range(4, 10):
    p[f'homesection{i}'] = 'none'
print(json.dumps(d))
")
        else
            updated_prefs=$(echo "$display_prefs" | python3 -c "
import sys, json
d = json.load(sys.stdin)
p = d.setdefault('CustomPrefs', {})
p['dashboardTheme'] = 'dark'
print(json.dumps(d))
")
        fi

        curl -fsSL \
            -X POST "${server_url}/DisplayPreferences/usersettings?userId=${user_id}&client=emby" \
            -H "Content-Type: application/json" \
            -H "X-Emby-Authorization: ${api_header}" \
            -d "$updated_prefs" >/dev/null 2>&1 \
            && ok "Dashboard theme set to Dark." \
            && { [[ "${reorder_choice^^}" == "Y" ]] && ok "Home screen sections configured." || skip "Home screen sections left unchanged."; } \
            || warn "Could not configure theme settings. Set manually in Settings > Display."
    else
        warn "Could not fetch display preferences."
    fi
    echo ""

    # Install spotlight into web/ui/
    step "Installing Spotlight add-on..."
    echo ""

    local ui_dir="${web_dir}/ui"
    ensure_writable_dir "$ui_dir"

    for f in "spotlight.html" "spotlight.css" "abyss-spotlight-inject.js"; do
        local src="${abyss_dir}/${f}"
        local dest="${ui_dir}/${f}"
        [[ ! -f "$src" ]] && exit_error "Missing ${f} in ${abyss_dir} — sync_all_abyss_assets failed."
        cp -f "$src" "$dest"
        ok "Installed ui/${f}"
    done

    # Find chunk file
    local chunk_file
    chunk_file=$(find "$web_dir" -maxdepth 1 -name "home-html.*.chunk.js" | head -1)

    if [[ -z "$chunk_file" ]]; then
        warn "Could not find home-html.*.chunk.js automatically."
        read -rp "  Enter the exact filename: " chunk_name
        chunk_file="${web_dir}/${chunk_name}"
        [[ ! -f "$chunk_file" ]] && exit_error "Chunk file not found: ${chunk_file}"
    fi
    ok "Found chunk: $(basename "$chunk_file")"

    if [[ ! -f "${chunk_file}.bak" ]]; then
        cp -f "$chunk_file" "${chunk_file}.bak"
        ok "Backup created."
    else
        skip "Backup already exists."
    fi

    local chunk_src="${abyss_dir}/home-html.chunk.js"
    [[ ! -f "$chunk_src" ]] && exit_error "Missing home-html.chunk.js in ${abyss_dir}."
    cp -f "$chunk_src" "$chunk_file"
    ok "Patched: $(basename "$chunk_file")"
    echo ""

    install_touch_ui "$web_dir" "$abyss_dir"

    # Restart
    restart_jellyfin "$server_url" "$api_header"

    # Done
    echo ""
    echo -e "${cyan}  ================================================${reset}"
    echo -e "${green}  Installation complete!${reset}"
    echo -e "${cyan}  ================================================${reset}"
    echo ""
    echo "  Next steps:"
    echo -e "${red}    1. Delete browser cache${reset}"
    echo -e "${yellow}    2. Hard refresh your browser (Ctrl+F5)${reset}"
    echo -e "${gray}    3. Relaunch Jellyfin Media Player if using the desktop app${reset}"
    echo -e "${gray}    4. Docker: run inside the container from this repo:${reset}"
    info "       docker exec -it jellyfin bash"
    info "       cd /path/to/repo && ./setup.sh"
    info "       (web dir: /jellyfin/jellyfin-web or set JELLYFIN_WEB_DIR)"
    info "Theme served from: ${abyss_dir}/"
    info "Custom CSS: @import url('/web/abyss/abyss-bundle.css');"
    info "Verify in browser: ${server_url}/web/abyss/styles/abyss-player.css"
    echo ""
    echo -e "${yellow}  Important: Go to Settings > Display > Theme and set it to Dark${reset}"
    info "Abyss requires the Dark base theme to display correctly."
    echo ""
    echo -e "${green}  Tip: Turn on 'Show Backdrops' in display settings for best experience.${reset}"
    echo ""
    read -rp "  Press Enter to exit: "
}

# ------------------------------------------------------------------------------
# Uninstall
# ------------------------------------------------------------------------------

uninstall_abyss() {
    show_header "Uninstaller"

    echo -e "${yellow}  Jellyfin server URL${reset}"
    echo -e "${gray}  Press ENTER to use default (http://localhost:8096)${reset}"
    read -rp "  URL: " input_url
    local server_url="${input_url:-http://localhost:8096}"
    server_url="${server_url%/}"
    ok "Server: ${server_url}"
    echo ""

    step "Authenticating..."
    echo ""
    connect_jellyfin "$server_url"
    local token="$ABYSS_TOKEN"

    local api_header
    api_header=$(get_api_header "$token")

    echo ""

    # Locate web dir
    step "Locating Jellyfin web directory..."
    local web_dir
    web_dir=$(get_jellyfin_web_dir)
    ok "Found: ${web_dir}"
    echo ""

    # Clear CSS
    step "Clearing custom CSS..."
    local branding
    branding=$(curl -fsSL \
        -X GET "${server_url}/Branding/Configuration" \
        -H "X-Emby-Authorization: ${api_header}" 2>/dev/null) || true

    if [[ -n "$branding" ]]; then
        local updated_branding
        updated_branding=$(echo "$branding" | python3 -c "
import sys, json
d = json.load(sys.stdin)
d['CustomCss'] = ''
print(json.dumps(d))
")
        curl -fsSL \
            -X POST "${server_url}/System/Configuration/Branding" \
            -H "Content-Type: application/json" \
            -H "X-Emby-Authorization: ${api_header}" \
            -d "$updated_branding" >/dev/null 2>&1 \
            && ok "Custom CSS cleared." \
            || { fail "Failed to clear CSS."; info "Clear manually in Dashboard > General > Custom CSS."; }
    fi
    echo ""

    # Restore chunk
    step "Restoring home-html chunk..."
    local chunk_file
    chunk_file=$(find "$web_dir" -maxdepth 1 -name "home-html.*.chunk.js" | head -1)

    if [[ -z "$chunk_file" ]]; then
        warn "Could not find home-html.*.chunk.js automatically."
        read -rp "  Enter the exact filename: " chunk_name
        chunk_file="${web_dir}/${chunk_name}"
        [[ ! -f "$chunk_file" ]] && exit_error "Chunk file not found: ${chunk_file}"
    fi

    if [[ -f "${chunk_file}.bak" ]]; then
        cp -f "${chunk_file}.bak" "$chunk_file"
        rm -f "${chunk_file}.bak"
        ok "Chunk restored."
        ok "Backup removed."
    else
        warn "No backup found. Chunk could not be restored."
        info "You may need to reinstall Jellyfin web."
    fi
    echo ""

    uninstall_touch_ui "$web_dir"

    # Remove spotlight files
    step "Removing spotlight files..."
    local ui_dir="${web_dir}/ui"
    for f in "spotlight.html" "spotlight.css"; do
        local path="${ui_dir}/${f}"
        if [[ -f "$path" ]]; then
            rm -f "$path"
            ok "Removed: ui/${f}"
        else
            skip "Not found: ui/${f}"
        fi
    done

    if [[ -d "$ui_dir" ]]; then
        if [[ -z "$(ls -A "$ui_dir" 2>/dev/null)" ]]; then
            rm -rf "$ui_dir"
            ok "Removed empty ui folder."
        else
            skip "ui folder has other files, leaving in place."
        fi
    fi
    echo ""

    # Remove copied theme from jellyfin-web/abyss/ (optional cleanup)
    step "Removing theme files from jellyfin-web/abyss/..."
    local abyss_dir="${web_dir}/abyss"
    if [[ -d "$abyss_dir" ]]; then
        rm -f "${abyss_dir}/abyss.css"
        rm -f "${abyss_dir}"/*.html "${abyss_dir}"/*.js "${abyss_dir}"/*.css 2>/dev/null || true
        rm -rf "${abyss_dir}/styles"
        ok "Cleared ${abyss_dir}/"
    else
        skip "No abyss folder found."
    fi
    echo ""

    # Restart
    restart_jellyfin "$server_url" "$api_header"

    echo ""
    echo -e "${cyan}  ================================================${reset}"
    echo -e "${green}  Uninstall complete!${reset}"
    echo -e "${cyan}  ================================================${reset}"
    echo ""
    echo "  Next steps:"
    echo -e "${red}    1. Delete browser cache${reset}"
    echo -e "${yellow}    2. Hard refresh your browser (Ctrl+F5)${reset}"
    echo -e "${gray}    3. Relaunch Jellyfin Media Player if using the desktop app${reset}"
    echo ""
    read -rp "  Press Enter to exit: "
}

# ------------------------------------------------------------------------------
# Entry point
# ------------------------------------------------------------------------------

if [[ "$EUID" -ne 0 ]]; then
    if [[ "$OS" == "Darwin" ]]; then
        warn "Not running as root. Some file operations may require sudo."
        info "If you encounter permission errors, re-run with: sudo bash setup.sh"
        echo ""
    else
        echo -e "${red}  This script must be run as root (sudo).${reset}"
        exit 1
    fi
fi

check_dependencies

show_header "Setup"

echo "  What would you like to do?"
echo ""
echo -e "${green}   [1] Install${reset}        ${yellow}[2] Uninstall${reset}"
echo ""
read -rp "  Enter 1 or 2: " choice

case "$choice" in
    1) install_abyss ;;
    2) uninstall_abyss ;;
    *) exit_error "Invalid choice. Please enter 1 or 2." ;;
esac