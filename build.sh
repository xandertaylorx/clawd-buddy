#!/bin/bash
# Builds build/Clawd.app (no Xcode project needed, just the Swift toolchain).
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Clawd.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/icon.iconset

swiftc -O -o "$APP/Contents/MacOS/Clawd" Sources/*.swift -framework Cocoa -framework ServiceManagement -framework EventKit -framework Carbon

# app icon rendered from the same sprite code
"$APP/Contents/MacOS/Clawd" --icon build/icon-1024.png
for s in 16 32 128 256 512; do
  sips -z $s $s build/icon-1024.png --out build/icon.iconset/icon_${s}x${s}.png >/dev/null
  sips -z $((s*2)) $((s*2)) build/icon-1024.png --out build/icon.iconset/icon_${s}x${s}@2x.png >/dev/null
done
iconutil -c icns build/icon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>Clawd</string>
  <key>CFBundleIdentifier</key><string>com.randomclaudething.clawd</string>
  <key>CFBundleName</key><string>Clawd</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>__VERSION__</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSCalendarsFullAccessUsageDescription</key><string>Clawd warns you a few minutes before your calendar events start.</string>
  <key>NSCalendarsUsageDescription</key><string>Clawd warns you a few minutes before your calendar events start.</string>
  <key>NSAppleEventsUsageDescription</key><string>Clawd looks at which folder a Finder window shows so he can tidy it for you.</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
sed -i '' "s/__VERSION__/$(cat VERSION)/" "$APP/Contents/Info.plist"

codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Built $APP"
