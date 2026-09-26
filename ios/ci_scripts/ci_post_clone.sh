#!/bin/sh

# Fail this script immediately if any subcommand fails.
set -e

# The default execution directory of this script is the ci_scripts directory.
# Move to the Flutter project root directory.
cd "$CI_PRIMARY_REPOSITORY_PATH"

echo "=== [Xcode Cloud] Step 1: Installing CocoaPods ==="
export HOMEBREW_NO_AUTO_UPDATE=1
brew install cocoapods

echo "=== [Xcode Cloud] Step 2: Installing Flutter SDK (stable) ==="
git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"

echo "=== [Xcode Cloud] Step 3: Flutter Doctor & Precache ==="
flutter doctor -v
flutter precache --ios

echo "=== [Xcode Cloud] Step 4: Injecting Secrets & Configuring Flutter ==="
# Inject iOS App ID into Secrets.xcconfig if present in Xcode Cloud environment variables
if [ -n "$ADMOB_IOS_APP_ID" ]; then
  echo "Injecting ADMOB_IOS_APP_ID into Secrets.xcconfig..."
  echo "ADMOB_IOS_APP_ID = $ADMOB_IOS_APP_ID" > "$CI_PRIMARY_REPOSITORY_PATH/ios/Flutter/Secrets.xcconfig"
fi

flutter pub get

# Inject AdMob Rewarded Ad Unit ID into Flutter build configuration if present
DART_DEFINES=""
if [ -n "$ADMOB_IOS_REWARDED_AD_UNIT_ID" ]; then
  echo "Injecting ADMOB_IOS_REWARDED_AD_UNIT_ID via --dart-define..."
  DART_DEFINES="--dart-define=ADMOB_IOS_REWARDED_AD_UNIT_ID=$ADMOB_IOS_REWARDED_AD_UNIT_ID"
fi
flutter build ios --config-only --release --no-codesign $DART_DEFINES

echo "=== [Xcode Cloud] Step 5: Installing iOS CocoaPods ==="
cd ios
pod install

echo "=== [Xcode Cloud] Pre-build configuration completed successfully! ==="
exit 0
