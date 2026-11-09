#!/bin/bash
# Builds build/Ledge.app and build/Ledge.zip (the file a release ships).
# Usage: scripts/build-app.sh 1.2
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?Usage: scripts/build-app.sh <version>, for example 1.2}"
APP=build/Ledge.app

swift build -c release
rm -rf build
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/Ledge" "$APP/Contents/MacOS/Ledge"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>app.ledge.Ledge</string>
    <key>CFBundleName</key><string>Ledge</string>
    <key>CFBundleExecutable</key><string>Ledge</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSUIElement</key><true/>
    <key>NSAppleEventsUsageDescription</key><string>Ledge reads and controls the song playing in Music, Spotify, Chrome or Safari.</string>
    <key>NSLocationUsageDescription</key><string>Ledge uses your location to show local weather.</string>
    <key>NSLocationWhenInUseUsageDescription</key><string>Ledge uses your location to show local weather.</string>
    <key>NSCalendarsFullAccessUsageDescription</key><string>Ledge shows this week's events in the notch.</string>
    <key>NSCalendarsUsageDescription</key><string>Ledge shows this week's events in the notch.</string>
    <key>NSBluetoothAlwaysUsageDescription</key><string>Ledge shows your AirPods and their battery when they connect.</string>
</dict>
</plist>
EOF

# macOS remembers permissions (Music, Location, Bluetooth) per signature. A fixed certificate keeps them
# across updates; the ad-hoc fallback changes every build, so macOS asks again after each update.
IDENTITY="${LEDGE_SIGN_IDENTITY:-Ledge Signing}"
if security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
    codesign --force --sign "$IDENTITY" "$APP"
else
    echo "Note: no \"$IDENTITY\" certificate, signing ad-hoc (permissions will be asked again after updates)."
    codesign --force --sign - "$APP"
fi
ditto -c -k --keepParent "$APP" build/Ledge.zip
echo "Built $APP and build/Ledge.zip (version $VERSION)"
