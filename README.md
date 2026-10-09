# PNotch

A notch app for the MacBook: a music player, a clipboard manager, a system monitor and a small robot companion living in the camera housing. Hover the notch and it unfolds under the menu bar: what's playing, your recent copies in a searchable list (text, rich text, code, links with previews, colors, images, files and contacts), how the Mac is doing, or what your robot is up to.

The interface is in English and French, following the system language.

## Features

### Music

- **Now playing** from any app that reports to the system: Music, Spotify, podcasts, video in a browser… Cover with the player's icon, title, artist, scrubbable progress, previous / play-pause / next, and a halo in the cover's color.
- **Live activity**: while music plays, the closed notch widens to show the cover and a bouncing equalizer.
- Since macOS 15.4 only Apple processes may read the system "Now Playing". PNotch uses [MediaRemoteAdapter](Vendor/MediaRemoteAdapter/README.md), loaded into `/usr/bin/perl`, like boring.notch does.

### System

- **Live metrics**: CPU (user and system), GPU, memory (colored by memory pressure), network download and upload, free storage, battery and time left (uptime on desktop Macs). Each with its last minute as a chart.
- Read with public APIs (Mach, sysctl, IOKit), sampled every second only while the page is on screen.
- A button opens Activity Monitor for a closer look.

### Clipboard

- **A list that drops from the notch**, as wide as the other pages, the header split around the camera housing. It shrinks around the results. Displays without a notch get a drawn one.
- **Typed previews**: colors show as swatches, code with its syntax colors, links with their page preview, images and files as thumbnails, vCards as contact avatars.
- **Direct paste**: choosing an item (click or <kbd>↩</kbd>) pastes it into the app you were using. Hold <kbd>⌥</kbd> to only copy it. Pasting needs the Accessibility permission (System Settings › Privacy & Security › Accessibility); without it PNotch copies and asks once.
- **Shortcut** (<kbd>⌃⌘V</kbd>, changeable in Settings): opens the list with the cursor in the search field. Press it again (or <kbd>↓</kbd>) to move to the next item, <kbd>↩</kbd> to use it.
- **Search** at the top of the list: every word you type must match (case and accents ignored) the content, the type or the source app, and matches are highlighted. Clicking the notch opens it with the cursor in the search; hovering never steals the keyboard. <kbd>esc</kbd> clears it.
- **Filters** next to the search: All, Images (including picture files copied from Finder) and Links.
- **Keyboard first**: <kbd>↑</kbd> <kbd>↓</kbd> to select (even while typing a search), <kbd>↩</kbd> to paste, <kbd>⌥↩</kbd> to only copy, <kbd>⇧↩</kbd> for plain text, <kbd>⌘P</kbd> to pin, <kbd>⌘⌫</kbd> to delete, <kbd>esc</kbd> to close. Right-click an item for the same actions.
- **Sneak peek**: copying something flashes the source app and the content type around the closed notch.
- **Private by default**: content flagged as confidential by password managers ([nspasteboard.org](http://nspasteboard.org)) is never recorded. History is stored locally in `~/Library/Application Support/com.pnotch.PNotch`.

### Companion

- **On every page**: the robot sits in the header, next to the buttons, with its accessories and its moods, and something to do on each page:
  - *Music*: headphones always on; it dances while a song plays (notes in the cover's color, a jump at each new song) and nods along, waiting, when paused.
  - *Clipboard*: it holds a clipboard and reads it, and looks puzzled when a search finds nothing.
  - *System*: it holds a plug wired to the processor, graphics, memory and network, data climbing each cable as fast as the metric is busy; every few seconds it tugs at them. Its antenna shows the processor's load.

  A click opens the Atelier, its home; a right-click pets it and has the page's shortcuts (play/pause, next track, clear the search, Activity Monitor). It can stay in the Atelier only (Settings › Companion).
- **A small robot** with its own page, drawn live in 2.5D: metallic shading, a glass visor, glowing eyes, and a highlight that follows your pointer like a light source. Its eyes follow the pointer too, and it blinks, breathes and floats.
- **Moods from the Mac**: it dances while music plays, sweats when the processor is busy or the Mac runs hot, dozes off late at night or when you're away, and keeps an eye on things the rest of the time.
- **Messenger**: when you copy something, it jumps and its face announces the news around the closed notch (Settings › Companion).
- **At home in the Atelier**, where it presents the modules (see below), with its wardrobe behind the paintbrush.
- **Attachment**: click it to pet it (hearts). Its page counts the days you've been together and the pets.
- **Customization** (paintbrush button): name, body color, eye color, and something to wear (headphones, crown, glasses, flower). Its name is also its tab's title.

### The Atelier and its modules

Each page of the notch is a module, plugged in from the **Atelier**, behind the « + » at the end of the tabs. That's Pixel's home: it presents every module on a shelf, explains the one you hover in a speech bubble, and plugs it in or unplugs it when you click (with a little jump). The plugged-in modules are the tabs, in order; past what fits next to the camera, they scroll and « + » stays put. Settings › Modules does the same with switches, sets their order and the page the notch opens on. A fresh install starts with Music, Clipboard and System.

## Requirements

- macOS 14 Sonoma or later
- Xcode 16 or later (the project uses folder-synchronized groups)

## Building

```sh
open PNotch.xcodeproj
```

Run the `PNotch` scheme. Swift packages ([Defaults](https://github.com/sindresorhus/Defaults), [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts), [Sparkle](https://sparkle-project.org)) are resolved by Xcode.

Development builds are signed with the team's *Apple Development* certificate (team `CLFGDZUD7W`, set in the project). A stable signature matters: macOS ties the Accessibility permission to it, so it survives rebuilds.

Tests use Swift Testing and always run in English:

```sh
xcodebuild test -project PNotch.xcodeproj -scheme PNotch -destination 'platform=macOS'
```

> When Xcode is open on the project, it holds SwiftPM's download locks: add `-packageCachePath <some folder>` to command-line builds so they don't wait for it.

### Manual test checklist

Before a release, on a notched MacBook:

1. Hover the notch: it opens on the expected page; leaving with the pointer closes it, typing in the search doesn't.
2. Click the notch: the cursor is in the search; <kbd>esc</kbd> clears it, then closes.
3. Copy text, a link, an image, a Finder file: each lands in the list with the right preview, the sneak peek shows around the closed notch.
4. Click an item (permission granted): it's pasted into the app in use; <kbd>⌥</kbd>-click only copies.
5. <kbd>⌃⌘V</kbd>: the list opens; pressing it again moves down; <kbd>↩</kbd> pastes.
6. Play music in Music, Spotify, then a browser: live activity, cover, scrubbing, play/pause, next.
7. System tab: values move, Activity Monitor opens.
8. Companion tab: the robot follows the pointer, dances with music, reacts to a click (hearts) and to a copy (jump, face around the closed notch); customization applies right away.
9. Settings › Tabs: hide and reorder tabs, change the start page.
10. Switch the system language between English and French.

## Localization

Strings live in `PNotch/Localizable.xcstrings` (English source, French translation). Xcode extracts new strings at build time; translate them in the catalog editor.

## Project layout

The structure follows [boring.notch](https://github.com/TheBoredTeam/boring.notch):

```
PNotch/
├── PNotchApp.swift            App entry point, menu bar extra and AppDelegate
├── AppIcon.icon               App icon (Icon Composer); layers generated by scripts/generate-icon-layers.swift
├── Localizable.xcstrings      English and French strings
├── ContentView.swift          Root notch view: shape, hover, open/close animation
├── PNotchViewCoordinator.swift App-wide UI state (sneak peeks, Settings)
├── MediaControllers/          Now Playing through MediaRemoteAdapter (stream, commands, parsing)
├── animations/                Springs and transitions
├── components/
│   ├── Notch/                 Window, window controller (keyboard, focus), shape, header and tabs
│   ├── Music/                 Player page, artwork, progress, controls, equalizer, live activity
│   ├── System/                Metric tiles, sparklines, system page
│   ├── Companion/             Robot renderer (Canvas), animator, live view, companion page and customization
│   ├── Clipboard/
│   │   ├── Models/            ClipboardItem, ClipboardContent, ClipboardHistory, filters
│   │   ├── Services/          Pasteboard monitor/reader/writer, classifier, persistence, previews
│   │   ├── ViewModels/        ClipboardStateViewModel
│   │   └── Views/             List, rows, search field, filter chips, item menu, sneak peek
│   └── Settings/              Settings window (General, Tabs, Clipboard, Music, Shortcuts, About)
├── enums/                     Notch states
├── extensions/                NSScreen notch geometry, Color helpers
├── helpers/                   Image processing, syntax highlighting, app icons, artwork colors, metric readers
├── managers/                  MusicManager, SystemMonitor, CompanionManager, UpdateManager (Sparkle)
├── models/                    PNotchViewModel, NotchGeometry, tabs configuration, PlaybackState, SystemMetrics, companion moods, Defaults keys
├── observers/                 NSEvent monitors
├── Shortcuts/                 Global keyboard shortcut names
├── sizing/                    Metrics
└── utils/                     Logging
Configuration/                 Distribution settings (Sparkle feed and key, empty until releases start)
scripts/                       Icon layer generator
PNotchTests/                   Swift Testing unit tests
Vendor/MediaRemoteAdapter/     Vendored adapter sources, built by the MediaRemoteAdapter target and embedded in the app
```

## Credits

- `NotchShape` is adapted from [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit) (MIT).
- Now Playing relies on [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) by Jonas van den Berg (BSD 3-Clause), vendored in `Vendor/MediaRemoteAdapter`.
- Updates by [Sparkle](https://sparkle-project.org) (MIT).
