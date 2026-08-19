#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
QMLLINT="$(command -v qmllint || true)"
[[ -x "$QMLLINT" ]] || QMLLINT="/usr/lib64/qt6/bin/qmllint"

if [[ ! -x "$QMLLINT" ]]; then
    echo "qmllint is required." >&2
    exit 1
fi

"$QMLLINT" --silent -I /usr/lib64/qt6/qml \
    "$ROOT_DIR/package/contents/ui/main.qml" \
    "$ROOT_DIR/package/contents/ui/Task.qml" \
    "$ROOT_DIR/package/contents/ui/MouseHandler.qml" \
    "$ROOT_DIR/package/contents/ui/PreviewTask.qml" \
    "$ROOT_DIR/package/contents/ui/PipeWireThumbnail.qml"

echo "QML syntax verified."
