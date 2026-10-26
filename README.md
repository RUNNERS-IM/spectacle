# Spectacle

**English** · [한국어](README.ko.md)

Move and resize macOS windows with keyboard shortcuts. No mouse required.

Spectacle was created by [Eric Czarny](https://github.com/eczarny) and reached version 1.2 in 2016. The original repository ([eczarny/spectacle](https://github.com/eczarny/spectacle)) is archived. This fork is maintained by [RUNNERS-IM](https://github.com/RUNNERS-IM) and is where new releases, bug fixes and features now happen.

## Install

1. Download `Spectacle-1.2.pkg` from [Releases](https://github.com/RUNNERS-IM/spectacle/releases) and double-click it. If macOS says the installer is from an unidentified developer, right-click the file and choose **Open**.
2. On Apple silicon Macs, macOS may ask to install Rosetta the first time Spectacle launches. Allow it. A native Apple silicon build is on the roadmap below.
3. Open **System Settings → Privacy & Security → Accessibility** and turn on Spectacle. Spectacle cannot move windows of other apps without this permission.

Homebrew installation (`brew install --cask runners-im/tap/spectacle`) is planned.

## Default keyboard shortcuts

| Symbol | Key |
|:---:|:---|
| ⌘ | Command |
| ⌃ | Control |
| ⌥ | Option |
| ⇧ | Shift |

All shortcuts can be changed or cleared in Preferences.

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

### Thirds

- Next third — ⌃⌥→
- Previous third — ⌃⌥←

### Resize

- Make larger — ⌃⌥⇧→
- Make smaller — ⌃⌥⇧←

Spectacle keeps the window touching the screen edges it already touches while resizing.

### Multiple displays

- Next display — ⌃⌥⌘→
- Previous display — ⌃⌥⌘←

### History

- Undo last window action — ⌥⌘Z
- Redo — ⌥⇧⌘Z

## Roadmap

Planned for the next releases, in this order:

1. Native Apple silicon build, Swift Package Manager instead of Carthage, Sparkle 2
2. Developer ID signing, notarization and automatic updates served from runners.im
3. Homebrew tap
4. New ratios (1/4, 2/3) and a grid picker in the menu bar
5. Command line tool and URL scheme (`spectacle left`, `spectacle://center`) for Raycast, Shortcuts and scripts
6. Export and import of settings as JSON
7. Auto arrange: one shortcut (⌥⌘A) lays out every open window on the current display by count
8. Drag to snap at screen edges
9. Modernized preferences window with localization

Issues and pull requests are welcome in this repository.

## Common issues

### Spectacle asks for accessibility access

Spectacle uses the macOS Accessibility protocol to move windows that belong to other applications. It cannot work until it is allowed in **System Settings → Privacy & Security → Accessibility**.

### A window does not resize as expected

Applications may set a minimum or maximum size for their windows. Spectacle always respects those constraints, so a window with a minimum width of 1600 px cannot be fitted into a 1440 px half of the screen. It will be resized as close to the target as the application allows.

### Terminal windows behave oddly

Terminal and similar apps (iTerm2 and others) only allow sizes that show whole rows and columns. Spectacle tries the exact size first and then shrinks the window step by step until it fits, which can look slightly jittery. The result is centered inside the intended region.

### Some applications cannot be controlled

Applications that build their interface in non-standard ways may not expose their windows through the Accessibility protocol. Spectacle cannot move those windows.

## Building from source

The current project still uses [Carthage](https://github.com/Carthage/Carthage):

```sh
carthage bootstrap --platform Mac
open Spectacle.xcodeproj
```

Press ⌘R in Xcode to run. Migration to Swift Package Manager is the first item on the roadmap, after which Carthage will no longer be needed.

## License

Spectacle is distributed under the MIT License. See [LICENSE.md](LICENSE.md).

Copyright (c) 2017 Eric Czarny. Modifications copyright (c) 2026 RUNNERS-IM.
