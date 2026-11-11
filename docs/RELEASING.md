# Releasing PNotch

PNotch ships as a signed, notarized DMG, attached to a release of this repository. Installed copies update themselves with Sparkle from [theo-mrn/pnotch-updates](https://github.com/theo-mrn/pnotch-updates), served by GitHub Pages at `https://theo-mrn.github.io/pnotch-updates/appcast.xml`. That repository only holds what is distributed (update archives and `appcast.xml`), never the source.

## Steps

1. Raise `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`, merge, and tag the merge: `git tag vX.Y.Z`, then push the tag.
2. `scripts/release.sh` archives the app, signs it with Developer ID, notarizes and staples it, builds a signed and notarized DMG (the app next to a link to Applications), and signs the update archive into the appcast. Everything stays in `build/release.noindex`, out of Spotlight's reach: try the DMG first.
3. `scripts/publish.sh` pushes the update files to the GitHub Pages repository, where installed copies find them, and attaches the DMG, as `PNotch.dmg`, to a release of this repository. The README's download button points at the latest one.

## One-time setup

Already done on the release Mac:

- **Developer ID Application certificate** for team CLFGDZUD7W: Xcode › Settings › Apple Accounts › *Manage Certificates* › **+**. It expires on 1 February 2027; releases signed before then keep opening, new ones need a renewed certificate.
- **Notarization credentials**, under the `PNotch` keychain profile, with an app-specific password from account.apple.com:
  ```sh
  xcrun notarytool store-credentials PNotch --apple-id <apple id> --team-id CLFGDZUD7W
  ```
- **Sparkle signing key**, made by `generate_keys` and kept in the keychain: back it up, it signs every update. Its public half is `SPARKLE_PUBLIC_ED_KEY` in `Configuration/Distribution.xcconfig`, next to `SPARKLE_FEED_URL`.
- **GitHub CLI** signed in to the account owning both repositories (`gh auth login`).

## Installing on this Mac

`scripts/install.sh` builds PNotch in Release for this Mac's processor, stripped of debug symbols (in `build/install.noindex`, apart from Xcode's builds), quits the running copy, replaces `/Applications/PNotch.app` and opens it. It's signed with the development certificate, like the builds from Xcode: for this Mac only, not to share.
