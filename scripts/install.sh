#!/bin/zsh
# Builds PNotch in Release and installs it on this Mac: replaces /Applications/PNotch.app, then opens it.
# Signed with the development certificate, like the builds from Xcode: for this Mac only.
# Built for this Mac's processor only and stripped of its debug symbols: a binary a fraction the size.
# To share PNotch with others, use scripts/release.sh instead.
#
#   scripts/install.sh
set -euo pipefail

cd "${0:A:h}/.."

# Its own build folder, so a build running in Xcode isn't disturbed.
# `.noindex` keeps Spotlight from listing this copy of the app next to the installed one.
BUILD_DIR="$PWD/build/install.noindex"
APP="$BUILD_DIR/Build/Products/Release/PNotch.app"
DEST="/Applications/PNotch.app"
BUNDLE_ID="com.pnotch.PNotch"

fail() {
    print -u2 "✗ $1"
    exit 1
}

step() {
    print "› $1"
}

step "Building PNotch (Release)"
xcodebuild build \
    -project PNotch.xcodeproj \
    -scheme PNotch \
    -configuration Release \
    -destination "platform=macOS" \
    -derivedDataPath "$BUILD_DIR" \
    -clonedSourcePackagesDirPath "$BUILD_DIR/SourcePackages" \
    -packageCachePath "$BUILD_DIR/PackageCache" \
    ONLY_ACTIVE_ARCH=YES \
    DEPLOYMENT_POSTPROCESSING=YES \
    STRIP_INSTALLED_PRODUCT=YES \
    -quiet
[[ -d "$APP" ]] || fail "The build didn't produce $APP."

step "Quitting PNotch"
osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
for _ in {1..50}; do
    pgrep -xq PNotch || break
    sleep 0.1
done
pkill -x PNotch 2>/dev/null || true

step "Installing in /Applications"
rm -rf "$DEST"
ditto "$APP" "$DEST"
# Tells macOS about the new copy, so the Dock and Finder show its current icon.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST"

step "Opening"
open "$DEST"

version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$DEST/Contents/Info.plist")
build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$DEST/Contents/Info.plist")
print "✓ PNotch $version ($build) is installed in /Applications."
