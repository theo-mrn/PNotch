#!/bin/zsh
# Publishes the release built by scripts/release.sh:
#   - the update files (appcast.xml and the signed zip) on GitHub Pages, in theo-mrn/pnotch-updates,
#     where SPARKLE_FEED_URL points, so installed copies find the new version;
#   - the DMG, as PNotch.dmg, on a GitHub release of theo-mrn/PNotch, for first installs:
#     the README's download button points at releases/latest/download/PNotch.dmg.
#
#   scripts/publish.sh
#
# The release uses the tag vX.Y.Z, which must already be pushed: this script never pushes the source.
#
# Environment: PNOTCH_UPDATES_REPO (default: theo-mrn/pnotch-updates),
#              PNOTCH_RELEASES_REPO (default: theo-mrn/PNotch).
set -euo pipefail

cd "${0:A:h}/.."

UPDATES_REPO="${PNOTCH_UPDATES_REPO:-theo-mrn/pnotch-updates}"
RELEASES_REPO="${PNOTCH_RELEASES_REPO:-theo-mrn/PNotch}"
BUILD_DIR="build/release.noindex"
UPDATES_DIR="$BUILD_DIR/updates"
SITE_DIR="build/pnotch-updates"
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
[[ -f "$DMG" ]] || fail "$DMG is missing: run scripts/release.sh again."
[[ -f "$UPDATES_DIR/appcast.xml" ]] || fail "No appcast in $UPDATES_DIR: is SPARKLE_FEED_URL set?"
xcrun stapler validate "$DMG" >/dev/null 2>&1 || fail "$DMG isn't notarized."
command -v gh >/dev/null || fail "The GitHub CLI (gh) is needed: brew install gh, then gh auth login."
gh release view "v$VERSION" --repo "$RELEASES_REPO" >/dev/null 2>&1 \
    && fail "PNotch $VERSION is already published: raise MARKETING_VERSION and CURRENT_PROJECT_VERSION first."
gh api "repos/$RELEASES_REPO/git/ref/tags/v$VERSION" >/dev/null 2>&1 \
    || fail "The tag v$VERSION isn't on $RELEASES_REPO yet: git tag v$VERSION && git push origin v$VERSION"

# MARK: Updates, on GitHub Pages

step "Publishing the update files"
if [[ ! -d "$SITE_DIR/.git" ]]; then
    gh repo clone "$UPDATES_REPO" "$SITE_DIR" -- --quiet
fi
git -C "$SITE_DIR" pull --ff-only --quiet
ditto "$UPDATES_DIR" "$SITE_DIR"
git -C "$SITE_DIR" add --all
git -C "$SITE_DIR" commit --quiet -m "PNotch $VERSION"
git -C "$SITE_DIR" push --quiet

# MARK: DMG, as a GitHub release

step "Publishing the DMG"
# A stable name, so the latest release always has the same download link.
STABLE_DMG="$BUILD_DIR/PNotch.dmg"
cp "$DMG" "$STABLE_DMG"
gh release create "v$VERSION" "$STABLE_DMG" \
    --repo "$RELEASES_REPO" \
    --verify-tag \
    --title "PNotch $VERSION" \
    --generate-notes \
    --notes "Ouvre le DMG et glisse PNotch dans Applications. Les versions suivantes s'installent ensuite toutes seules.

Open the DMG and drag PNotch to Applications. Later versions then install themselves."

print "✓ PNotch $VERSION is published:"
print "  • https://github.com/$RELEASES_REPO/releases/tag/v$VERSION"
print "  • installed copies will find it within a day, or right away with « Check for Updates… »"
