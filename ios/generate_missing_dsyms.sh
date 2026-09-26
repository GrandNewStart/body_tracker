#!/bin/sh
set -e

# This script generates dSYM files for precompiled/static binary frameworks
# (such as GoogleMobileAds and UserMessagingPlatform) that are embedded in the app
# but lack standalone dSYM files. This satisfies App Store Connect's symbol validator
# without any "Upload Symbols Failed" warnings.

if [ -n "$1" ] && [ -d "$1" ]; then
  ARCHIVE_PATH="$1"
  # Find the .app inside Products/Applications
  APP_DIR=$(find "$ARCHIVE_PATH/Products/Applications" -maxdepth 1 -name "*.app" | head -n 1)
  FRAMEWORKS_DIR="$APP_DIR/Frameworks"
  DSYM_DIR="$ARCHIVE_PATH/dSYMs"
else
  # Running inside Xcode build phase
  FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
  DSYM_DIR="${DWARF_DSYM_FOLDER_PATH}"
fi

if [ -d "$FRAMEWORKS_DIR" ] && [ -d "$DSYM_DIR" ]; then
  echo "[dSYM Generator] Checking embedded frameworks in $FRAMEWORKS_DIR..."
  for framework in "$FRAMEWORKS_DIR"/*.framework; do
    [ -d "$framework" ] || continue
    framework_name=$(basename "$framework" .framework)
    binary="$framework/$framework_name"
    dsym_path="$DSYM_DIR/$framework_name.framework.dSYM"
    
    if [ -f "$binary" ] && [ ! -d "$dsym_path" ]; then
      echo "[dSYM Generator] Generating missing dSYM for $framework_name..."
      xcrun dsymutil "$binary" -o "$dsym_path" 2>/dev/null || true
      if [ -d "$dsym_path" ]; then
        echo "[dSYM Generator] Created $dsym_path"
      fi
    fi
  done
fi
