#!/bin/bash
set -e

# Build the app using Xcode command line tools
xcodebuild -project AviationMetarMenubar/AviationMetarMenubar.xcodeproj -scheme AviationMetarMenubar -configuration Release -derivedDataPath build

# Find the built .app bundle
APP_PATH="build/Build/Products/Release/AviationMetarMenubar.app"

# Copy to /Applications (overwrite if exists)
if [ -d "/Applications/AviationMetarMenubar.app" ]; then
    rm -rf "/Applications/AviationMetarMenubar.app"
fi
cp -R "$APP_PATH" /Applications/

echo "App deployed to /Applications. You can now run it from Launchpad or Finder."
