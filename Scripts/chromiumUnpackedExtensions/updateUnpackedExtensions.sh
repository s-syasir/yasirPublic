#!/bin/bash
# Updates Manifest V2 extensions Google's update server no longer serves (uBlock Origin,
# ClearURLs) by unpacking their GitHub releases into fixed folders that Ungoogled Chromium
# loads as unpacked extensions. New versions take effect on the next Chromium start.
# One-time per extension: chrome://extensions -> Developer mode -> Load unpacked -> its folder.
# Never fails the caller: problems are printed and the current version is kept.

# Inside the Flatpak's own data dir, the only home location the sandbox can read without overrides
DEST="$HOME/.var/app/io.github.ungoogled_software.ungoogled_chromium/data/unpacked"

# name|GitHub repo|regex matching the release asset
EXTENSIONS=(
    "uBlock0.chromium|gorhill/uBlock|uBlock0_.*\.chromium\.zip$"
    "ClearURLs|ClearURLs/Addon|ClearURLs\.zip$"
)

if ! flatpak info io.github.ungoogled_software.ungoogled_chromium >/dev/null 2>&1; then
    echo "Ungoogled Chromium not installed, skipping unpacked extensions"
    exit 0
fi

mkdir -p "$DEST"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

manifest_version() {
    python3 -I -c "import json,sys; print(json.load(open(sys.argv[1]))['version'])" "$1" 2>/dev/null
}

for entry in "${EXTENSIONS[@]}"; do
    IFS='|' read -r name repo pattern <<< "$entry"
    target="$DEST/$name"

    release=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest") || {
        echo "$name: couldn't reach GitHub, keeping current version"; continue; }
    url=$(grep -oE '"browser_download_url": *"[^"]+"' <<< "$release" | cut -d'"' -f4 | grep -E "$pattern" | head -1)
    [ -n "$url" ] || { echo "$name: no matching release asset, keeping current version"; continue; }

    current=$(manifest_version "$target/manifest.json")
    work="$TMP/$name"
    mkdir -p "$work"
    curl -fsSL -o "$work/release.zip" "$url" && unzip -q "$work/release.zip" -d "$work/x" 2>/dev/null || {
        echo "$name: download or unzip failed, keeping current version"; continue; }

    # uBlock's zip has a top-level folder, ClearURLs' doesn't
    manifest=$(find "$work/x" -maxdepth 2 -name manifest.json | head -1)
    [ -n "$manifest" ] || { echo "$name: no manifest.json in release, keeping current version"; continue; }
    latest=$(manifest_version "$manifest")

    if [ "$latest" = "$current" ]; then
        echo "$name: up to date ($current)"
        continue
    fi

    # same folder path keeps the extension ID, so settings survive; swap by rename so it's never half-written
    rm -rf "$target.new" "$target.old"
    mv "$(dirname "$manifest")" "$target.new"
    [ -d "$target" ] && mv "$target" "$target.old"
    mv "$target.new" "$target" && rm -rf "$target.old"
    echo "$name: ${current:-not installed} -> $latest (restart Chromium or click reload in chrome://extensions)"
done
exit 0
