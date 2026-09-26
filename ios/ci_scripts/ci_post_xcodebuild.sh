#!/bin/sh
set -e

echo "=== [Xcode Cloud] Running Post-Xcodebuild Script ==="

# If an archive was produced in this Xcode Cloud workflow action,
# generate dSYMs for static/embedded frameworks (e.g. GoogleMobileAds)
# before uploading symbols to App Store Connect / TestFlight.
if [ -n "$CI_ARCHIVE_PATH" ] && [ -d "$CI_ARCHIVE_PATH" ]; then
  echo "Generating missing framework dSYMs for archive at: $CI_ARCHIVE_PATH"
  "$CI_PRIMARY_REPOSITORY_PATH/ios/generate_missing_dsyms.sh" "$CI_ARCHIVE_PATH"
fi

echo "=== [Xcode Cloud] Post-Xcodebuild script completed! ==="
exit 0
