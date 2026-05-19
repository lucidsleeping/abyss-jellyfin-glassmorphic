#!/usr/bin/env bash
# One-shot deploy: copy local repo into a running jellyfin container (linuxserver image).
set -euo pipefail

CONTAINER="${JELLYFIN_CONTAINER:-jellyfin}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WEB_ABYSS="/usr/share/jellyfin/web/abyss"

echo "[abyss] Deploy from ${REPO_ROOT} -> ${CONTAINER}:${WEB_ABYSS}"

docker cp "${REPO_ROOT}/abyss-bundle.css" "${CONTAINER}:${WEB_ABYSS}/"
docker cp "${REPO_ROOT}/abyss.css" "${CONTAINER}:${WEB_ABYSS}/"
docker cp "${REPO_ROOT}/styles/." "${CONTAINER}:${WEB_ABYSS}/styles/"

echo "[abyss] Files on container:"
docker exec "${CONTAINER}" sh -c "ls -la ${WEB_ABYSS}/abyss-bundle.css ${WEB_ABYSS}/styles/abyss-polish.css"

echo ""
echo "[abyss] Custom CSS (Dashboard > General):"
echo "  @import url('/web/abyss/abyss-bundle.css');"
echo ""
echo "[abyss] Hard-refresh the browser (Ctrl+Shift+R)."
echo "[abyss] To survive restarts: push to GitHub OR mount repo at /abyss-source and run init with ABYSS_LOCAL_DIR."
