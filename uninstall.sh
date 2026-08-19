#!/usr/bin/env bash
set -euo pipefail

kpackagetool6 --type Plasma/Applet --remove beer.devs.peardock 2>/dev/null || true
kbuildsycoca6 >/dev/null 2>&1 || true

echo "Removed: PearDock"
