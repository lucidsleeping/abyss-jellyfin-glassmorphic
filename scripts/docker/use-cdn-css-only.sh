#!/usr/bin/env bash
# Switch Jellyfin to Abyss theme via jsDelivr only — remove /web/abyss/ copies.
set -euo pipefail

CONTAINER="${JELLYFIN_CONTAINER:-jellyfin}"
REPO="${ABYSS_REPO:-lucidsleeping/abyss-jellyfin-glassmorphic}"
BRANCH="${ABYSS_BRANCH:-main}"
WEB_ABYSS="/usr/share/jellyfin/web/abyss"

CSS_LINE1="@import url('https://cdn.jsdelivr.net/gh/${REPO}@${BRANCH}/abyss.css');"
CSS_LINE2="@import url('https://cdn.jsdelivr.net/gh/${REPO}@${BRANCH}/styles/abyss-polish.css');"

echo "[abyss] Removing local theme: ${WEB_ABYSS}"
docker exec "${CONTAINER}" rm -rf "${WEB_ABYSS}" 2>/dev/null || true

BRANDING_FILE="$(mktemp)"
trap 'rm -f "$BRANDING_FILE"' EXIT
cat > "$BRANDING_FILE" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<BrandingOptions xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <LoginDisclaimer />
  <CustomCss>${CSS_LINE1}
${CSS_LINE2}</CustomCss>
  <SplashscreenEnabled>true</SplashscreenEnabled>
</BrandingOptions>
EOF

echo "[abyss] Writing /config/branding.xml"
docker cp "$BRANDING_FILE" "${CONTAINER}:/config/branding.xml"

echo ""
echo "[abyss] Custom CSS:"
echo "${CSS_LINE1}"
echo "${CSS_LINE2}"
echo ""
echo "[abyss] Prevent reinstall on restart — add to jellyfin compose:"
echo "  environment:"
echo "    - ABYSS_CSS_CDN=1"
echo ""
echo "[abyss] Hard-refresh Jellyfin (Ctrl+Shift+R)."
echo "[abyss] git push origin main  # jsDelivr serves GitHub main"
