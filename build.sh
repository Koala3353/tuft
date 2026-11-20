#!/bin/bash
# Builds build/Tuft.app from the Swift package. Needs only the Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="build/Tuft.app"
ICON="build/icon-work"
rm -rf "$APP" "$ICON"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ICON/Tuft.iconset"
cp .build/release/Tuft "$APP/Contents/MacOS/Tuft"
cp Info.plist "$APP/Contents/Info.plist"
if ls Wallpapers/*.jpg >/dev/null 2>&1; then
  mkdir -p "$APP/Contents/Resources/wallpapers"
  cp Wallpapers/*.jpg "$APP/Contents/Resources/wallpapers/"
fi

"$APP/Contents/MacOS/Tuft" --icon "$ICON/icon.png"
for s in 16 32 128 256 512; do
  sips -z $s $s "$ICON/icon.png" --out "$ICON/Tuft.iconset/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2))
  sips -z $d $d "$ICON/icon.png" --out "$ICON/Tuft.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICON/Tuft.iconset" -o "$APP/Contents/Resources/Tuft.icns"
rm -rf "$ICON"

codesign --force --sign - "$APP"
echo "Built $APP"
