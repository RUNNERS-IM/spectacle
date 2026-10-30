# Split

**English** · [한국어](README.ko.md)

Move and resize macOS windows with keyboard shortcuts. No mouse required.

Split is a free, open-source window manager by RUNNERS-IM: a native Apple silicon app with notarized releases, auto-arrange, saved layouts and 18 languages.

## Install

1. Download `Split-<version>.dmg` from [Releases](https://github.com/RUNNERS-IM/split/releases), open it and drag Split to Applications. Split is signed and notarized, so it opens without a warning.
2. When Split starts it opens **System Settings → Privacy & Security → Accessibility** for you. Turn on the switch next to Split. Split cannot move windows of other apps without this permission, and its guide window closes by itself once access is granted.
3. If another copy of a Spectacle-style window manager is still running, Split offers to quit it so the two apps don't react to the same shortcuts.

Split runs natively on Apple silicon and Intel Macs with macOS 13 or later. Updates are installed from within the app.

With Homebrew:

```sh
brew tap runners-im/tap
brew trust runners-im/tap   # recent Homebrew asks you to trust third-party taps once
brew install --cask split
```

Split speaks Arabic, Chinese (Simplified), Dutch, English, Finnish, French, German, Hindi, Indonesian, Italian, Japanese, Korean, Polish, Portuguese, Russian, Spanish, Thai and Vietnamese. It follows the language set for your Mac.

## Default keyboard shortcuts

| Symbol | Key |
|:---:|:---|
| ⌘ | Command |
| ⌃ | Control |
| ⌥ | Option |
| ⇧ | Shift |

All shortcuts can be changed or cleared in Settings → Shortcuts.

### Basic window actions

- Center — ⌥⌘C (size is not changed)
- Fullscreen — ⌥⌘F
- Left half — ⌥⌘←
- Right half — ⌥⌘→
- Top half — ⌥⌘↑
- Bottom half — ⌥⌘↓
- Upper left — ⌃⌘←
- Lower left — ⌃⇧⌘←
- Upper right — ⌃⌘→
- Lower right — ⌃⇧⌘→

Pressing a half or corner shortcut repeatedly cycles the window between 1/2, 1/3 and 2/3 of that region.

### Auto arrange

- Arrange all windows — ⌥⌘A

Places up to 9 visible windows on the display with the frontmost window, most recently used first:

| Windows | Layout |
|:---:|:---|
| 1 | Full screen |
| 2 | Left and right halves |
| 3 | Left half, right side split top and bottom |
| 4 | 2 × 2 grid |
| 5 | 2 × 2 grid, the front window floating in the middle at 60% |
| 6 | 3 × 2 grid |
| 7–9 | 3 × 2 grid, the rest stacked in the middle at 60%, 30 points apart |

Minimized windows, windows in full screen and windows of hidden apps are left alone. One undo (⌥⌘Z) puts every arranged window back where it was. Hovering the menu item shows where each window will go.

### Thirds

- Next third — ⌃⌥→
- Previous third — ⌃⌥←

### Resize

- Make larger — ⌃⌥⇧→
- Make smaller — ⌃⌥⇧←

Split keeps the window touching the screen edges it already touches while resizing.

### Multiple displays

- Next display — ⌃⌥⌘→
- Previous display — ⌃⌥⌘←

### History

- Undo last window action — ⌥⌘Z
- Redo — ⌥⇧⌘Z

## Roadmap

Done:

- Native Apple silicon build, Swift Package Manager, Sparkle 2
- Developer ID signing, notarization and automatic updates (served through runners.im)
- A step-by-step Accessibility permission guide
- Homebrew tap
- New icon, a picture menu with a live preview, and a glow after each move
- Auto arrange (⌥⌘A)
- A new settings window and 18 languages
- 1.2: an Effects tab (strength, color, label, duration, position), space between windows (screen edges stay flush),
  full screen that toggles back, rearranging windows when monitors are plugged in or out,
  a shortcut list while ⌥⌘ is held, and short tips for new users

Issues and pull requests are welcome in this repository.

## Common issues

### Split asks for accessibility access

Split uses the macOS Accessibility protocol to move windows that belong to other applications. It cannot work until it is allowed in **System Settings → Privacy & Security → Accessibility**.

### A window does not resize as expected

Applications may set a minimum or maximum size for their windows. Split always respects those constraints, so a window with a minimum width of 1600 px cannot be fitted into a 1440 px half of the screen. It will be resized as close to the target as the application allows.

### Terminal windows behave oddly

Terminal and similar apps (iTerm2 and others) only allow sizes that show whole rows and columns. Split tries the exact size first and then shrinks the window step by step until it fits, which can look slightly jittery. The result is centered inside the intended region.

### Some applications cannot be controlled

Applications that build their interface in non-standard ways may not expose their windows through the Accessibility protocol. Split cannot move those windows.

## Building from source

Requires Xcode 26 or later. Dependencies come from Swift Package Manager and are fetched by Xcode.

```sh
open Split.xcodeproj
```

Press ⌘R to run, ⌘U to run the tests. Releases are built with `scripts/release.sh <version>`, which tests, signs with Developer ID, notarizes and writes the Sparkle appcast; `--publish` uploads to GitHub Releases.

## License

Split is distributed under the MIT License. See [LICENSE.md](LICENSE.md).

Split is based on Spectacle. Copyright (c) 2017 Eric Czarny. Modifications copyright (c) 2026 RUNNERS-IM.
