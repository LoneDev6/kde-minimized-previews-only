#!/usr/bin/env bash
set -euo pipefail

rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/plasma/plasmoids/com.github.0x0086.minimizedpreviews"
kbuildsycoca6 >/dev/null 2>&1 || true

echo "Removed: Minimized Window Previews"
