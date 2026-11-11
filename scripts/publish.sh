#!/bin/zsh
# Publishes the release built by scripts/release.sh as a GitHub release of theo-mrn/PNotch, with:
#   - PNotch.dmg, for first installs: the README's download button points at releases/latest/download/PNotch.dmg;
#   - appcast.xml, read by installed copies at releases/latest/download/appcast.xml (SPARKLE_FEED_URL);
#   - the signed update archive, and the deltas from older versions, that the appcast points to.
#
#   scripts/publish.sh
#
# The release uses the tag vX.Y.Z, which must already be pushed: this script never pushes the source.
#
# Environment: PNOTCH_RELEASES_REPO (default: theo-mrn/PNotch).
set -euo pipefail

cd "${0:A:h}/.."

RELEASES_REPO="${PNOTCH_RELEASES_REPO:-theo-mrn/PNotch}"
BUILD_DIR="build/release.noindex"
UPDATES_DIR="$BUILD_DIR/updates"
APP="$BUILD_DIR/export/PNotch.app"

fail() {
    print -u2 "✗ $1"
    exit 1
}

step() {
    print "› $1"
}

# MARK: Checks

[[ -d "$APP" ]] || fail "Nothing to publish: run scripts/release.sh first."
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="$BUILD_DIR/PNotch-$VERSION.dmg"
APPCAST="$UPDATES_DIR/appcast.xml"
[[ -f "$DMG" ]] || fail "$DMG is missing: run scripts/release.sh again."
[[ -f "$APPCAST" ]] || fail "No appcast in $UPDATES_DIR: is SPARKLE_FEED_URL set?"
xcrun stapler validate "$DMG" >/dev/null 2>&1 || fail "$DMG isn't notarized."
command -v gh >/dev/null || fail "The GitHub CLI (gh) is needed: brew install gh, then gh auth login."
gh release view "v$VERSION" --repo "$RELEASES_REPO" >/dev/null 2>&1 \
    && fail "PNotch $VERSION is already published: raise MARKETING_VERSION and CURRENT_PROJECT_VERSION first."
gh api "repos/$RELEASES_REPO/git/ref/tags/v$VERSION" >/dev/null 2>&1 \
    || fail "The tag v$VERSION isn't on $RELEASES_REPO yet: git tag v$VERSION && git push origin v$VERSION"

# The files the appcast expects in this release: the archive and the deltas made by release.sh.
prefix="https://github.com/$RELEASES_REPO/releases/download/v$VERSION/"
update_files=(${(u)${${(f)"$(grep -oE "${prefix//./\\.}[^\"]+" "$APPCAST" | sed "s|^$prefix||" || true)"}:#}})
(( ${#update_files} > 0 )) || fail "The appcast has no update for $VERSION: run scripts/release.sh again."
for file in $update_files; do
    [[ -f "$UPDATES_DIR/$file" ]] || fail "$UPDATES_DIR/$file, listed in the appcast, is missing."
done

# MARK: Release

step "Publishing PNotch $VERSION"
# A stable name, so the latest release always has the same download link.
STABLE_DMG="$BUILD_DIR/PNotch.dmg"
cp "$DMG" "$STABLE_DMG"
gh release create "v$VERSION" "$STABLE_DMG" "$APPCAST" "${update_files[@]/#/$UPDATES_DIR/}" \
    --repo "$RELEASES_REPO" \
    --verify-tag \
    --latest \
    --title "PNotch $VERSION" \
    --generate-notes \
    --notes "Open the DMG and drag PNotch to Applications. Later versions then install themselves."

print "✓ PNotch $VERSION is published:"
print "  • https://github.com/$RELEASES_REPO/releases/tag/v$VERSION"
print "  • installed copies will find it within a day, or right away with « Check for Updates… »"
