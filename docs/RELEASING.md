# Releasing PNotch

Everything is distributed through the releases of this repository. Each one carries:

- `PNotch.dmg`, for first installs. The README's download button points at `releases/latest/download/PNotch.dmg`.
- `appcast.xml`, the Sparkle feed. Installed copies read it at `releases/latest/download/appcast.xml` (`SPARKLE_FEED_URL` in `Configuration/Distribution.xcconfig`), so the latest release is always the one they see.
- The signed update archive, `PNotch-X.Y.Z.zip`, and the deltas from older versions, which the appcast points to.

## Steps

1. Raise `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`, merge, and tag the merge: `git tag vX.Y.Z`, then push the tag.
2. `scripts/release.sh` archives the app, signs it with Developer ID, notarizes and staples it, builds a signed and notarized DMG (the app next to a link to Applications), and signs the update archive into the appcast. Everything stays in `build/release.noindex`, out of Spotlight's reach: try the DMG first.
3. `scripts/publish.sh` creates the release for the tag, with the DMG, the appcast and the update files, and marks it as the latest. Installed copies find the new version within a day, or right away with « Check for Updates… ».

Keep `build/release.noindex/updates` between releases: the appcast grows there, and Sparkle makes the deltas from the archives it holds.

## One-time setup

Already done on the release Mac:

- **Developer ID Application certificate** for team CLFGDZUD7W: Xcode › Settings › Apple Accounts › *Manage Certificates* › **+**. It expires on 1 February 2027; releases signed before then keep opening, new ones need a renewed certificate.
- **Notarization credentials**, under the `PNotch` keychain profile, with an app-specific password from account.apple.com:
  ```sh
  xcrun notarytool store-credentials PNotch --apple-id <apple id> --team-id CLFGDZUD7W
  ```
- **Sparkle signing key**, made by `generate_keys` and kept in the keychain: back it up, it signs every update. Its public half is `SPARKLE_PUBLIC_ED_KEY` in `Configuration/Distribution.xcconfig`, next to `SPARKLE_FEED_URL`.
- **GitHub CLI** signed in to the account owning this repository (`gh auth login`).

## Installing on this Mac

`scripts/install.sh` builds PNotch in Release for this Mac's processor, stripped of debug symbols (in `build/install.noindex`, apart from Xcode's builds), quits the running copy, replaces `/Applications/PNotch.app` and opens it. It's signed with the development certificate, like the builds from Xcode: for this Mac only, not to share.
