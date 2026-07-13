#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="com.github.0x0086.minimizedpreviews"
PLASMOID_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/plasmoids"
DESTINATION="$PLASMOID_DIR/$PLUGIN_ID"
OLD_COMBINED="$PLASMOID_DIR/com.github.0x0086.macosicontasks"

if ! command -v git >/dev/null 2>&1; then
    echo "git is required. Install it with: sudo dnf install -y git" >&2
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

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
SOURCE_ROOT="$WORK_DIR/plasma-desktop"
TAG="v$PLASMA_VERSION"

echo "Fetching PipeWire thumbnail component for Plasma $TAG..."
git clone \
    --quiet \
    --depth 1 \
    --single-branch \
    --branch "$TAG" \
    --filter=blob:none \
    --sparse \
    https://github.com/KDE/plasma-desktop.git \
    "$SOURCE_ROOT"

git -C "$SOURCE_ROOT" sparse-checkout set applets/taskmanager/qml
PIPEWIRE_SOURCE="$SOURCE_ROOT/applets/taskmanager/qml/PipeWireThumbnail.qml"

if [[ ! -f "$PIPEWIRE_SOURCE" ]]; then
    echo "PipeWireThumbnail.qml was not found for Plasma $TAG." >&2
    exit 1
fi

STAGING="$WORK_DIR/package"
cp -a "$ROOT_DIR/package" "$STAGING"
cp "$PIPEWIRE_SOURCE" "$STAGING/contents/ui/PipeWireThumbnail.qml"

mkdir -p "$PLASMOID_DIR"
rm -rf "$DESTINATION" "$OLD_COMBINED"
cp -a "$STAGING" "$DESTINATION"

kbuildsycoca6 >/dev/null 2>&1 || true

echo "Installed: Minimized Window Previews"
echo "The old combined task manager package was removed."
echo "Restart Plasma with: systemctl --user restart plasma-plasmashell.service"
