#!/bin/zsh
# Builds "Word Box.app" into WordBoxApp/build/. Run from anywhere: ./WordBoxApp/build.sh
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Word Box.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/tmp

# 1. the page (shared with the web version)
{
  printf '%s\n' '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"></head><body>'
  cat ../word-box.html
  printf '%s\n' '</body></html>'
} > "$APP/Contents/Resources/index.html"

# 2. the app icon
if [[ ! -f build/tmp/AppIcon.icns || Resources/make-icon.swift -nt build/tmp/AppIcon.icns ]]; then
  swift Resources/make-icon.swift build/tmp/icon-1024.png
  ICONSET=build/tmp/AppIcon.iconset
  rm -rf "$ICONSET"; mkdir -p "$ICONSET"
  for s in 16 32 128 256 512; do
    sips -z $s $s build/tmp/icon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) build/tmp/icon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o build/tmp/AppIcon.icns
fi
cp build/tmp/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# 3. the program
swiftc -O -o "$APP/Contents/MacOS/WordBox" Sources/main.swift \
  -framework Cocoa -framework WebKit -target "$(uname -m)-apple-macos13.0" 2>&1 | grep -v "^$" || true
[[ -x "$APP/Contents/MacOS/WordBox" ]] || { echo "Build failed"; exit 1; }

# 4. app info
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Word Box</string>
  <key>CFBundleDisplayName</key><string>Word Box</string>
  <key>CFBundleIdentifier</key><string>com.suwitchaya.wordbox</string>
  <key>CFBundleExecutable</key><string>WordBox</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.education</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>Your personal word box.</string>
</dict>
</plist>
PLIST

# 5. sign for this Mac only
xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
echo "Built: $(pwd)/$APP"
