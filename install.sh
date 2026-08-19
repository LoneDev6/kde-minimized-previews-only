#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="beer.devs.peardock"

if ! command -v kpackagetool6 >/dev/null 2>&1; then
    echo "kpackagetool6 is required." >&2
    exit 1
fi

for required in metadata.json contents/ui/main.qml contents/ui/Task.qml contents/ui/PreviewTask.qml contents/ui/PipeWireThumbnail.qml; do
    if [[ ! -f "$ROOT_DIR/package/$required" ]]; then
        echo "The package is incomplete: $required is missing." >&2
        exit 1
    fi
done

if kpackagetool6 --type Plasma/Applet --show "$PLUGIN_ID" >/dev/null 2>&1; then
    kpackagetool6 --type Plasma/Applet --upgrade "$ROOT_DIR/package"
else
    kpackagetool6 --type Plasma/Applet --install "$ROOT_DIR/package"
fi

kbuildsycoca6 >/dev/null 2>&1 || true

echo "Installed: PearDock"
echo "Restart Plasma with: systemctl --user restart plasma-plasmashell.service"
