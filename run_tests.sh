#!/bin/bash
set -e

rm -rf build

# Run unit tests for the AviationMetarMenubar Xcode project
xcodebuild -project AviationMetarMenubar/AviationMetarMenubar.xcodeproj \
           -scheme AviationMetarMenubar \
           -destination 'platform=macOS' \
           test
