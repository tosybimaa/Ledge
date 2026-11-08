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
</dict>
</plist>
EOF

# Ad-hoc signature: enough to run on your own Mac.
codesign --force --sign - "$APP"
ditto -c -k --keepParent "$APP" build/Ledge.zip
echo "Built $APP and build/Ledge.zip (version $VERSION)"
