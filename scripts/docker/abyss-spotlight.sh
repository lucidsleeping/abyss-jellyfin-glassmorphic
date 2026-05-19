#!/usr/bin/with-contenv bash
# Abyss theme — full install for linuxserver/jellyfin (custom-cont-init.d)
#
# Installs: theme CSS → /abyss/, Spotlight → /ui/, home chunk patch, touch script
#
# Mount:  ./config/custom-cont-init.d:/custom-cont-init.d
# Optional: ./your-repo-clone:/abyss-source:ro  and  ABYSS_LOCAL_DIR=/abyss-source
#
# Env (optional):
#   ABYSS_REPO          GitHub repo (default: lucidsleeping/abyss-jellyfin-glassmorphic)
#   ABYSS_BRANCH        Branch (default: main)
#   ABYSS_LOCAL_DIR     Use local files instead of GitHub downloads
#   JELLYFIN_URL        e.g. http://127.0.0.1:8096 — apply Custom CSS via API
#   ABYSS_ADMIN_USER    Admin username (with JELLYFIN_URL)
#   ABYSS_ADMIN_PASSWORD Admin password

set -euo pipefail

REPO="${ABYSS_REPO:-lucidsleeping/abyss-jellyfin-glassmorphic}"
BRANCH="${ABYSS_BRANCH:-main}"
RAW="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
WEB_DIR="${JELLYFIN_WEB_DIR:-/usr/share/jellyfin/web}"
ABYSS_DIR="${WEB_DIR}/abyss"
UI_DIR="${WEB_DIR}/ui"
STAGE_DIR="/tmp/abyss-stage-$$"

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

SPOTLIGHT_FILES=(
    "scripts/spotlight/spotlight.html"
    "scripts/spotlight/spotlight.css"
    "scripts/spotlight/home-html.chunk.js"
    "scripts/spotlight/abyss-spotlight-inject.js"
)

TOUCH_FILE="scripts/touch/abyss-touch.js"

log() { echo "**** [abyss] $* ****"; }

cleanup() { rm -rf "$STAGE_DIR"; }
trap cleanup EXIT

fetch_file() {
    local repo_path="$1"
    local dest="$2"
    local optional="${3:-0}"

    if [[ -n "${ABYSS_LOCAL_DIR:-}" && -f "${ABYSS_LOCAL_DIR}/${repo_path}" ]]; then
        cp -f "${ABYSS_LOCAL_DIR}/${repo_path}" "$dest"
        return 0
    fi

    if curl -fsSL "${RAW}/${repo_path}" -o "$dest"; then
        return 0
    fi

    if [[ "$optional" == "1" ]]; then
        log "WARNING: Optional file not found (push to GitHub or set ABYSS_LOCAL_DIR): ${repo_path}"
        return 1
    fi

    log "ERROR: Failed to download ${repo_path} from ${REPO}@${BRANCH}"
    exit 1
}

stage_all_files() {
    mkdir -p "$STAGE_DIR/styles"
    local f
    for f in "${THEME_FILES[@]}"; do
        fetch_file "$f" "${STAGE_DIR}/${f}" || exit 1
        log "Staged: ${f}"
    done
    for f in "${SPOTLIGHT_FILES[@]}"; do
        if [[ "$f" == "scripts/spotlight/abyss-spotlight-inject.js" ]]; then
            fetch_file "$f" "${STAGE_DIR}/abyss-spotlight-inject.js" 1 \
                && log "Staged: abyss-spotlight-inject.js" \
                || true
            continue
        fi
        fetch_file "$f" "${STAGE_DIR}/$(basename "$f")" || exit 1
        log "Staged: $(basename "$f")"
    done
    fetch_file "$TOUCH_FILE" "${STAGE_DIR}/abyss-touch.js" || exit 1
    log "Staged: abyss-touch.js"
}

install_theme_css() {
    mkdir -p "${ABYSS_DIR}/styles"
    local f dest src
    for f in "${THEME_FILES[@]}"; do
        src="${STAGE_DIR}/${f}"
        if [[ "$f" == styles/* ]]; then
            dest="${ABYSS_DIR}/${f}"
        else
            dest="${ABYSS_DIR}/$(basename "$f")"
        fi
        if [[ ! -f "$src" ]]; then
            log "ERROR: Missing staged file ${f}"
            exit 1
        fi
        if ! cmp -s "$src" "$dest" 2>/dev/null; then
            cp -f "$src" "$dest"
            log "Updated: ${f}"
        else
            log "Unchanged: ${f}"
        fi
    done
}

install_spotlight() {
    mkdir -p "$UI_DIR"
    local f src dest
    for f in spotlight.html spotlight.css; do
        src="${STAGE_DIR}/${f}"
        dest="${UI_DIR}/${f}"
        cp -f "$src" "$dest"
        log "Installed ui/${f}"
    done

    if [[ -f "${STAGE_DIR}/abyss-spotlight-inject.js" ]]; then
        cp -f "${STAGE_DIR}/abyss-spotlight-inject.js" "${UI_DIR}/abyss-spotlight-inject.js"
        log "Installed ui/abyss-spotlight-inject.js"
    else
        log "WARNING: abyss-spotlight-inject.js missing — mount repo at /abyss-source or push file to GitHub"
    fi

    local chunk_file
    chunk_file=$(find "$WEB_DIR" -maxdepth 1 -name "home-html.*.chunk.js" | head -1)
    if [[ -z "$chunk_file" ]]; then
        log "WARNING: home-html.*.chunk.js not found — Spotlight home banner will not load"
        return 0
    fi

    log "Found chunk: $(basename "$chunk_file")"
    local chunk_src="${STAGE_DIR}/home-html.chunk.js"
    if ! cmp -s "$chunk_src" "$chunk_file" 2>/dev/null; then
        [[ ! -f "${chunk_file}.bak.abyss" ]] && cp -f "$chunk_file" "${chunk_file}.bak.abyss"
        cp -f "$chunk_src" "$chunk_file"
        log "Patched home chunk for Spotlight"
    else
        log "Home chunk already up to date"
    fi
}

install_touch() {
    cp -f "${STAGE_DIR}/abyss-touch.js" "${UI_DIR}/abyss-touch.js"
    log "Installed ui/abyss-touch.js"
}

link_ui_scripts() {
    local index="${WEB_DIR}/index.html"
    [[ ! -f "$index" ]] && return 0

    [[ ! -f "${index}.bak.abyss" ]] && cp -f "$index" "${index}.bak.abyss"

    local inject_tag='<script src="ui/abyss-spotlight-inject.js" defer></script>'
    local touch_tag='<script src="ui/abyss-touch.js" defer></script>'
    local tmp="${index}.abyss.tmp"

    if ! grep -q 'abyss-spotlight-inject.js' "$index" 2>/dev/null; then
        awk -v tag="$inject_tag" '{ gsub(/<\/body>/, tag "\n</body>"); print }' "$index" > "$tmp" && mv -f "$tmp" "$index"
        log "Linked spotlight inject in index.html"
    fi

    if ! grep -q 'abyss-touch.js' "$index" 2>/dev/null; then
        awk -v tag="$touch_tag" '{ gsub(/<\/body>/, tag "\n</body>"); print }' "$index" > "$tmp" && mv -f "$tmp" "$index"
        log "Linked touch script in index.html"
    fi
}

apply_custom_css_api() {
    local url="${JELLYFIN_URL%/}"
    local user="${ABYSS_ADMIN_USER:-}"
    local pass="${ABYSS_ADMIN_PASSWORD:-}"
    [[ -z "$user" || -z "$pass" ]] && return 0

    if ! command -v python3 >/dev/null 2>&1; then
        log "WARNING: python3 missing — skip API Custom CSS apply"
        return 0
    fi

    export JELLYFIN_URL="$url"
    export ABYSS_ADMIN_USER="$user"
    export ABYSS_ADMIN_PASSWORD="$pass"
    export ABYSS_CSS="@import url('/web/abyss/abyss-bundle.css?v=$(date +%s)');"
    log "Applying Custom CSS via Jellyfin API..."

    if python3 <<'PY'; then
import json
import os
import sys
import urllib.error
import urllib.request

url = os.environ["JELLYFIN_URL"].rstrip("/")
user = os.environ["ABYSS_ADMIN_USER"]
password = os.environ["ABYSS_ADMIN_PASSWORD"]
css = os.environ["ABYSS_CSS"]
client = 'MediaBrowser Client="Abyss Init", Device="Docker", DeviceId="abyss-docker-init", Version="1.0"'

try:
    req = urllib.request.Request(
        f"{url}/Users/AuthenticateByName",
        # Jellyfin API uses "Pw", not "Password" (same as setup.sh)
        data=json.dumps({"Username": user, "Pw": password}).encode(),
        headers={"Content-Type": "application/json", "X-Emby-Authorization": client},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        token = json.load(resp)["AccessToken"]

    api_header = f'{client}, Token="{token}"'
    headers = {"Content-Type": "application/json", "X-Emby-Authorization": api_header}

    req2 = urllib.request.Request(f"{url}/Branding/Configuration", headers=headers)
    with urllib.request.urlopen(req2, timeout=30) as resp:
        branding = json.load(resp)

    branding["CustomCss"] = css

    req3 = urllib.request.Request(
        f"{url}/System/Configuration/Branding",
        data=json.dumps(branding).encode(),
        headers=headers,
        method="POST",
    )
    with urllib.request.urlopen(req3, timeout=30) as resp:
        resp.read()
except urllib.error.HTTPError as e:
    print(f"HTTP {e.code}: {e.reason}", file=sys.stderr)
    sys.exit(1)
except urllib.error.URLError as e:
    print(f"Connection error: {e.reason}", file=sys.stderr)
    sys.exit(1)
PY
        log "Custom CSS applied via API"
    else
        log "WARNING: Could not apply Custom CSS via API (check ABYSS_ADMIN_USER / ABYSS_ADMIN_PASSWORD)"
        log "Add manually in Dashboard > General > Custom CSS:"
        log "  @import url('/web/abyss/abyss-bundle.css');"
    fi
}

# ── Main ──

# Use bind-mounted repo when present (recommended for forks / unreleased files)
if [[ -z "${ABYSS_LOCAL_DIR:-}" && -d /abyss-source ]]; then
    ABYSS_LOCAL_DIR="/abyss-source"
fi

log "Abyss full theme install (${REPO}@${BRANCH})"

if [[ ! -d "$WEB_DIR" ]]; then
    log "ERROR: Web directory not found: ${WEB_DIR}"
    log "Set JELLYFIN_WEB_DIR for your image (official: /jellyfin/jellyfin-web)"
    exit 1
fi

if [[ -n "${ABYSS_LOCAL_DIR:-}" ]]; then
    log "Using local source: ${ABYSS_LOCAL_DIR}"
else
    log "Downloading from GitHub: ${REPO}@${BRANCH}"
fi

stage_all_files
install_theme_css
install_spotlight
install_touch
link_ui_scripts

export JELLYFIN_URL="${JELLYFIN_URL:-http://127.0.0.1:8096}"
export ABYSS_CSS="@import url('/web/abyss/abyss-bundle.css?v=$(date +%s)');"
apply_custom_css_api

log "Done. Theme: ${ABYSS_DIR}/"
log "Verify: ${JELLYFIN_URL:-http://127.0.0.1:8096}/web/abyss/styles/abyss-layout.css"
log "Spotlight: /web/ui/spotlight.html (home page)"
if [[ -z "${ABYSS_ADMIN_USER:-}" ]]; then
    log "Tip: set ABYSS_ADMIN_USER + ABYSS_ADMIN_PASSWORD to auto-apply Custom CSS"
fi
