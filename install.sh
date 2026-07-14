#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="beer.devs.minimidezpreviews"
PLASMOID_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/plasmoids"
DESTINATION="$PLASMOID_DIR/$PLUGIN_ID"
OLD_IDS=(
    "$PLASMOID_DIR/beer.devs.minimizedpreviews"
    "$PLASMOID_DIR/com.github.0x0086.minimizedpreviews"
)
OLD_COMBINED="$PLASMOID_DIR/com.github.0x0086.macosicontasks"

if ! command -v kpackagetool6 >/dev/null 2>&1; then
    echo "kpackagetool6 is required." >&2
    exit 1
fi

PLASMA_VERSION="$(plasmashell --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)"
if [[ -z "$PLASMA_VERSION" ]]; then
    echo "Could not detect the Plasma version." >&2
    exit 1
fi

if [[ "$PLASMA_VERSION" != 6.7.* ]]; then
    echo "This build currently supports Plasma 6.7.x. Detected: $PLASMA_VERSION" >&2
    exit 1
fi

if [[ ! -f "$ROOT_DIR/package/contents/ui/PipeWireThumbnail.qml" ]]; then
    echo "The package is incomplete: PipeWireThumbnail.qml is missing." >&2
    exit 1
fi

mkdir -p "$PLASMOID_DIR"
rm -rf "$DESTINATION" "${OLD_IDS[@]}" "$OLD_COMBINED"
kpackagetool6 --type Plasma/Applet --install "$ROOT_DIR/package"

kbuildsycoca6 >/dev/null 2>&1 || true

echo "Installed: Minimized Window Previews"
echo "The old combined task manager package was removed."
echo "Restart Plasma with: systemctl --user restart plasma-plasmashell.service"
