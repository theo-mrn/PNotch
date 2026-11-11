# Contributing to PNotch

Thanks for your interest! Bug reports, ideas and pull requests are all welcome. For anything bigger than a fix, open an issue first so we can agree on the shape of it.

## Setup

- macOS 14 Sonoma or later
- Xcode 27 (Swift 6, folder-synchronized groups)

```sh
git clone https://github.com/theo-mrn/PNotch.git
cd PNotch
open PNotch.xcodeproj
```

Run the `PNotch` scheme. Xcode resolves the Swift packages: [Defaults](https://github.com/sindresorhus/Defaults), [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) and [Sparkle](https://sparkle-project.org).

**Signing.** The project is signed with the maintainer's team. Pick your own in *Signing & Capabilities*, and keep it: macOS ties the Accessibility permission (used for direct paste) to the signature, so a stable one keeps the permission across rebuilds. To build without any team, sign ad hoc as the CI does:

```sh
xcodebuild build -project PNotch.xcodeproj -scheme PNotch \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= CODE_SIGNING_REQUIRED=NO
```

> When Xcode is open on the project, it holds SwiftPM's download locks: add `-packageCachePath <some folder>` to command-line builds so they don't wait for it.

## Tests

Unit tests use Swift Testing and always run in English:

```sh
xcodebuild test -project PNotch.xcodeproj -scheme PNotch -destination 'platform=macOS'
```

Every pull request runs [the CI](.github/workflows/ci.yml): the tests, an optimized universal build, and a check that every string has a French translation.

## Translations

The interface is in English and French, following the system language. Strings live in `PNotch/Localizable.xcstrings` (English source, French translation). Xcode extracts new strings at build time; translate them in the catalog editor. `scripts/check-translations.py` lists any string left untranslated.

## Code style

- Swift 6 with main-actor isolation by default. Work that doesn't belong on the main thread is marked `@concurrent` or runs detached.
- Colors, spacing, radii, type and motion come from the tokens in `PNotch/design/Theme.swift`: dark system colors and one accent, no per-page colors.
- Comments explain why, in full sentences.
- New pages go through `NotchPage` and `NotchLayout`, with their views in `components/<Feature>/`.

## Project layout

```
PNotch/
├── PNotchApp.swift            App entry point, menu bar extra and AppDelegate
├── ContentView.swift          Root notch view: shape, hover, open and close, live activities
├── PNotchViewCoordinator.swift App-wide UI state (sneak peeks, Settings)
├── AppIcon.icon               App icon (Icon Composer): Pixel, drawn by the app's own renderer
├── Localizable.xcstrings      English and French strings
├── design/                    Design tokens (Theme) and organic motion
├── MediaControllers/          Now Playing through MediaRemoteAdapter
├── components/
│   ├── Notch/                 Window, keyboard and focus, shape, header and tabs
│   ├── Music/                 Player page, artwork, controls, equalizer, live activity
│   ├── Clipboard/             Models, services (pasteboard, classifier, persistence), view model, views
│   ├── System/                Metric tiles and charts
│   ├── ClaudeCode/            Sessions, permission requests, live activity
│   ├── Companion/             Pixel's renderer and animator, the Atelier, customization
│   ├── Timer/                 Focus sessions and stopwatch
│   ├── Reminders/             List, editor, natural-language entry, ringing alert
│   ├── Notes/                 Sheet, list and sticky-note layouts
│   └── Settings/              Settings window
├── managers/                  Music, system monitor, companion, Claude Code, focus, reminders, notes, updates
├── models/                    View model, notch geometry, modules, settings keys, feature models
├── helpers/                   Metric readers, formatters, syntax highlighting, Claude Code hook server and installer
├── enums/ extensions/ observers/ Shortcuts/ sizing/ utils/
Configuration/                 Distribution settings (Sparkle feed and key) and export options
scripts/                       Local install, release and publish, CI helpers
PNotchTests/                   Swift Testing unit tests
Vendor/MediaRemoteAdapter/     Vendored adapter, built by its own target and embedded in the app
```

## Manual checks before a release

On a MacBook with a notch:

1. Hover the notch: it opens on the expected page; leaving with the pointer closes it, typing in the search doesn't.
2. Click the notch on the clipboard: the cursor is in the search; <kbd>esc</kbd> clears it, then closes.
3. Copy text, a link, an image and a Finder file: each lands in the list with the right preview, and the sneak peek shows around the closed notch.
4. Click an item (permission granted): it's pasted into the app in use; <kbd>⌥</kbd>-click only copies.
5. <kbd>⌃⌘V</kbd>: the list opens; pressing it again moves down; <kbd>↩</kbd> pastes.
6. Play music in Music, Spotify, then a browser: live activity, cover, scrubbing, play and pause, next.
7. System: the values move; Activity Monitor opens.
8. Pixel follows the pointer, dances with music, reacts to a click and to a copy; customization applies right away. Clicking it opens the Atelier, where modules plug in and out.
9. Claude Code: connect from the page, start `claude` in Terminal and in VS Code. The star and the timer show while it works, the raised hand on a permission prompt, the sneak peek when it's done. Clicking a session brings back its app; disconnecting restores `~/.claude/settings.json`.
10. Timer, reminders and notes: start a session, let a reminder ring, write a note in each layout.
11. Settings › Modules: reorder modules and change the start page.
12. Switch the system language between English and French.

Releasing is described in [docs/RELEASING.md](docs/RELEASING.md).
