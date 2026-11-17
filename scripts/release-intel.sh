#!/usr/bin/env bash
# =============================================================================
# HyperMac — standalone Intel (x86_64) release build.
#
# Tạo bản HyperMac dành riêng cho Mac Intel (x86_64) mà KHÔNG ảnh hưởng tới
# luồng phát hành Apple Silicon chính. Chạy trên máy có Swift toolchain hỗ trợ
# target x86_64 (Apple Silicon hoặc Intel có CLT đầy đủ).
#
# Output: dist/HyperMac-Intel-<VER>-x86_64.app.zip  (ad-hoc signed, GPL-3.0)
#
# Cách dùng:
#   scripts/release-intel.sh            # mặc định VER=1.9.8
#   VER=2.0.0 scripts/release-intel.sh  # tự đặt version
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$ROOT/dist}"
VER="${1:-1.9.8}"
ARCH="x86_64"
TRIPLE="${ARCH}-apple-macosx"
BUNDLE_ID="${BUNDLE_ID:-com.opensource.hypermac}"
APP_NAME="HyperMac-Intel.app"

echo "==> [1/5] Build $TRIPLE (release)..."
swift build --package-path "$ROOT" --triple "$TRIPLE" -c release

echo "==> [2/5] Assemble $APP_NAME..."
APP="$OUT/$APP_NAME"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
BIN="$ROOT/.build/$TRIPLE/release/HyperMac"
if [ ! -f "$BIN" ]; then
  echo "ERROR: binary not found at $BIN" >&2; exit 1
fi
cp "$BIN" "$APP/Contents/MacOS/HyperMac"
cp -R "$ROOT/Resources/." "$APP/Contents/Resources/"
if [ -f "$ROOT/LICENSE" ]; then cp "$ROOT/LICENSE" "$APP/Contents/Resources/"; fi
chmod +x "$APP/Contents/MacOS/HyperMac" \
         "$APP/Contents/Resources/smc" \
         "$APP/Contents/Resources/displaycontrol-power" 2>/dev/null || true

echo "==> [3/5] Write Info.plist..."
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>HyperMac</string>
  <key>CFBundleIdentifier</key><string>com.opensource.hypermac</string>
  <key>CFBundleName</key><string>HyperMac-Intel</string>
  <key>CFBundleDisplayName</key><string>HyperMac (Intel)</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>@VER@</string>
  <key>CFBundleVersion</key><string>@VER@</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSMainNibFile</key><string></string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST
# inject version (sed: @VER@ literal placeholder)
if [[ "$(uname -s)" == "Darwin" ]]; then
  /usr/bin/sed -i '' "s/@VER@/$VER/g" "$APP/Contents/Info.plist"
else
  sed -i "s/@VER@/$VER/g" "$APP/Contents/Info.plist"
fi

echo "==> [4/5] Ad-hoc codesign..."
codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP" 2>&1 | tail -1 || true

echo "==> [5/5] Package zip..."
ZIP="$OUT/HyperMac-Intel-${VER}-${ARCH}.app.zip"
rm -f "$ZIP"
( cd "$OUT" && zip -qry "$(basename "$ZIP")" "$APP_NAME" )
echo "==> Done: $ZIP"
echo "    Install: unzip + copy HyperMac-Intel.app to /Applications (Intel Mac)."
echo "    Note: first run grant Accessibility / Screen Recording / Bluetooth;"
echo "          helper install prompts one admin password (SMC fan control)."
