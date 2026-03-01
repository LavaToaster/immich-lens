#!/usr/bin/env bash
set -euo pipefail

# Build a signed, notarized macOS DMG for ImmichLens.
#
# Prerequisites:
#   - Developer ID Application certificate in your Keychain
#   - brew install create-dmg xcbeautify
#
# Notarization (optional, skip with --no-notarize):
#   Set these env vars, or store a keychain profile named "notarytool":
#     NOTARIZE_KEY_PATH   - path to App Store Connect API .p8 key
#     NOTARIZE_KEY_ID     - API key ID
#     NOTARIZE_ISSUER_ID  - issuer ID

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/ImmichLens-macOS.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
DMG_DIR="$BUILD_DIR/dmg"

NOTARIZE=true
VERSION=""

for arg in "$@"; do
  case "$arg" in
    --no-notarize) NOTARIZE=false ;;
    --version=*)   VERSION="${arg#--version=}" ;;
    *)             echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

# --- Derive version ---
if [[ -z "$VERSION" ]]; then
  VERSION=$(sed -n 's/.*MARKETING_VERSION = \(.*\);/\1/p' "$PROJECT_DIR/ImmichLens.xcodeproj/project.pbxproj" | head -1 | tr -d ' ')
fi
BUILD_NUMBER=$(git -C "$PROJECT_DIR" rev-list --count HEAD)

echo "==> Version: $VERSION (build $BUILD_NUMBER)"

# --- Clean previous build ---
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH" "$DMG_DIR"
mkdir -p "$DMG_DIR"

# --- Archive ---
echo "==> Archiving..."
set -o pipefail
xcodebuild archive \
  -project "$PROJECT_DIR/ImmichLens.xcodeproj" \
  -scheme ImmichLens \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  -skipPackagePluginValidation \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" 2>&1 | xcbeautify

# --- Export ---
echo "==> Exporting with Developer ID signing..."

EXPORT_PLIST=$(mktemp)
cat > "$EXPORT_PLIST" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>PV3AE7C4X7</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  -exportPath "$EXPORT_PATH" 2>&1 | xcbeautify

rm -f "$EXPORT_PLIST"

APP_PATH="$EXPORT_PATH/ImmichLens.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Error: Expected app not found at $APP_PATH"
  exit 1
fi

# --- Create DMG ---
DMG_NAME="ImmichLens-${VERSION}.dmg"
DMG_PATH="$DMG_DIR/$DMG_NAME"

echo "==> Creating DMG..."
create-dmg \
  --volname "ImmichLens" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "ImmichLens.app" 150 190 \
  --app-drop-link 450 190 \
  --hide-extension "ImmichLens.app" \
  "$DMG_PATH" \
  "$APP_PATH"

echo "==> DMG created at $DMG_PATH"

# --- Notarize ---
if [[ "$NOTARIZE" == true ]]; then
  echo "==> Submitting for notarization..."

  NOTARIZE_ARGS=()
  if [[ -n "${NOTARIZE_KEY_PATH:-}" ]]; then
    NOTARIZE_ARGS+=(--key "$NOTARIZE_KEY_PATH" --key-id "$NOTARIZE_KEY_ID" --issuer "$NOTARIZE_ISSUER_ID")
  else
    NOTARIZE_ARGS+=(--keychain-profile "notarytool")
  fi

  xcrun notarytool submit "$DMG_PATH" "${NOTARIZE_ARGS[@]}" --wait

  echo "==> Stapling notarization ticket..."
  xcrun stapler staple "$DMG_PATH"

  echo "==> Verifying..."
  spctl -a -t open --context context:primary-signature -v "$DMG_PATH"
fi

echo ""
echo "Done! DMG is at: $DMG_PATH"
