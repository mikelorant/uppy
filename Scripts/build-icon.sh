#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$ROOT/.build/icons/Uppy.iconset"
mkdir -p "$ICONSET" "$ROOT/Bundle/Contents/Resources"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$ROOT/Assets/Logo.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  retina=$((size * 2))
  sips -z "$retina" "$retina" "$ROOT/Assets/Logo.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$ROOT/Bundle/Contents/Resources/Uppy.icns"
