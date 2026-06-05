#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="${1:?Usage: ./Scripts/release-macos.sh VERSION}"
APP="$ROOT/build/Release/Storage.app"
ZIP="$ROOT/build/storage-macos-v${VERSION}.zip"

echo "Building Storage (Release, universal)…"
xcodebuild -scheme Storage -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$ROOT/build/DerivedData" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  build CONFIGURATION_BUILD_DIR="$ROOT/build/Release" \
  -quiet

echo "Architectures: $(lipo -info "$APP/Contents/MacOS/Storage" 2>/dev/null || echo unknown)"

echo "Preparing app for distribution…"
xattr -cr "$APP"
codesign --force --deep --sign - --options runtime \
  --preserve-metadata=entitlements,requirements,flags,runtime \
  "$APP"
codesign --verify --deep --strict "$APP"

echo "Creating zip…"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
ls -lh "$ZIP"
echo "Done: $ZIP"
