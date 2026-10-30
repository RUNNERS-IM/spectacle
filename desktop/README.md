# Split (Windows and Linux)

**English** · [한국어](README.ko.md)

The Windows and Linux version of Split: move and resize the focused window with keyboard shortcuts. The macOS app lives at the top of this repository ([README](../README.md)); this folder (`desktop/`) is only about Windows and Linux.

Where a window goes is worked out by running the macOS app's own JavaScript files (`Split/Resources/Window Position Calculations/*.js`), so halves, thirds, corners and resizing land exactly where they do on a Mac.

> This is an early test version. Installers are only attached to GitHub Actions runs; nothing is on the Releases page yet.

## Terms

- **Tray (notification area)**: the row of small icons at the right end of the Windows taskbar or in the Linux top bar. Split has no window of its own most of the time; it lives there.
- **X11 / Wayland**: the two ways Linux draws windows. On X11 an app may move other apps' windows; Wayland forbids it for security. On Wayland a small helper has to run inside the desktop (GNOME or KDE) instead.
- **GNOME extension**: a small add-on that runs inside the GNOME desktop. Split's extension moves windows when the Split app asks.
- **KWin script**: a small add-on that runs inside KDE Plasma's window manager (KWin). Split's script takes the shortcuts, asks the Split app where the window goes, and moves it.
- **Super key**: the key with the Windows logo. Split uses it where the macOS version uses ⌘.

## Install

### Windows

1. Run `split-desktop-<version>-windows-x64-setup.exe` (or the `.msi`).
2. The installer is not code signed yet, so SmartScreen warns the first time. Choose **More info → Run anyway**.
3. Settings open on the first launch; after that Split only has an icon in the tray.

Built for 64-bit Windows 10 and 11.

### Linux

Pick the file for your distribution:

- Ubuntu, Debian: `sudo apt install ./split-desktop-<version>-linux-amd64.deb`
- Fedora, openSUSE: `sudo dnf install ./split-desktop-<version>-linux-x86_64.rpm`
- Anything else: make `split-desktop-<version>-linux-x86_64.AppImage` executable (`chmod +x`) and open it.

The tray icon needs AppIndicator support. On GNOME that is the "AppIndicator and KStatusNotifierItem Support" extension (on by default in Ubuntu). Shortcuts work without the icon, and opening Split again brings up settings.

#### Which session you are in

Split reads `XDG_SESSION_TYPE` and `XDG_CURRENT_DESKTOP` when it starts. Settings → General → **Window control** shows what it found.

| Session | What you need |
|:---|:---|
| X11 (GNOME on Xorg, KDE on X11, Xfce, Cinnamon, MATE, …) | Nothing; it just works. |
| Wayland + GNOME 45 or later | The Split GNOME extension |
| Wayland + KDE Plasma (5.27, 6) | The Split KWin script |
| Other Wayland desktops (sway, Hyprland, …) | Not supported yet; settings say so. |

#### Wayland + GNOME: install the extension

Download `split-gnome-extension-<version>.zip`, then:

```sh
gnome-extensions install --force split-gnome-extension-<version>.zip
# log out and back in, then
gnome-extensions enable split@runners.im
```

From a checkout, copy `desktop/linux/gnome-extension/split@runners.im` into `~/.local/share/gnome-shell/extensions/`.

GNOME already uses `Super+Alt+←/→` and `Ctrl+Alt+←/→` to switch workspaces, so Split cannot have those keys and the Shortcuts tab marks them in red. Change them in Split, or free them in GNOME:

```sh
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-left "['<Super>Page_Up']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-right "['<Super>Page_Down']"
```

#### Wayland + KDE Plasma: install the KWin script

Download `split-kwin-script-<version>.kwinscript`, then:

```sh
kpackagetool6 --type KWin/Script --install split-kwin-script-<version>.kwinscript   # kpackagetool5 on Plasma 5
```

Turn Split on in **System Settings → Window Management → KWin Scripts**. On KDE, KWin owns the shortcuts: change them in **System Settings → Shortcuts → KWin** (search for "Split"). Keep the Split app running; the script asks it where windows go.

## Default shortcuts

The same as on macOS, with the Win (Windows) or Super (Linux) key where the Mac uses ⌘. Change or clear any of them in Settings → Shortcuts (on KDE Wayland, in System Settings).

| Action | Windows | Linux | macOS |
|:---|:---|:---|:---|
| Center | Win+Alt+C | Super+Alt+C | ⌥⌘C |
| Full Screen | Win+Alt+F | Super+Alt+F | ⌥⌘F |
| Left Half | Win+Alt+← | Super+Alt+← | ⌥⌘← |
| Right Half | Win+Alt+→ | Super+Alt+→ | ⌥⌘→ |
| Top Half | Win+Alt+↑ | Super+Alt+↑ | ⌥⌘↑ |
| Bottom Half | Win+Alt+↓ | Super+Alt+↓ | ⌥⌘↓ |
| Top Left | Win+Ctrl+← | Super+Ctrl+← | ⌃⌘← |
| Bottom Left | Win+Ctrl+Shift+← | Super+Ctrl+Shift+← | ⌃⇧⌘← |
| Top Right | Win+Ctrl+→ | Super+Ctrl+→ | ⌃⌘→ |
| Bottom Right | Win+Ctrl+Shift+→ | Super+Ctrl+Shift+→ | ⌃⇧⌘→ |
| Next Display | Win+Ctrl+Alt+→ | Super+Ctrl+Alt+→ | ⌃⌥⌘→ |
| Previous Display | Win+Ctrl+Alt+← | Super+Ctrl+Alt+← | ⌃⌥⌘← |
| Next Third | Ctrl+Alt+→ | Ctrl+Alt+→ | ⌃⌥→ |
| Previous Third | Ctrl+Alt+← | Ctrl+Alt+← | ⌃⌥← |
| Larger | Ctrl+Alt+Shift+→ | Ctrl+Alt+Shift+→ | ⌃⌥⇧→ |
| Smaller | Ctrl+Alt+Shift+← | Ctrl+Alt+Shift+← | ⌃⌥⇧← |
| Undo | Win+Alt+Z | Super+Alt+Z | ⌥⌘Z |
| Redo | Win+Alt+Shift+Z | Super+Alt+Shift+Z | ⌥⇧⌘Z |
| Arrange All Windows | Win+Alt+A | Super+Alt+A | ⌥⌘A |

Pressing a half again goes 1/2 → 2/3 → 1/3, and pressing full screen again restores the old size, as on the Mac. Arrange places up to 9 visible windows on the current screen at once; one undo puts them all back.

**Clashing shortcuts**: Windows uses `Win+Ctrl+←/→` to switch virtual desktops, so the default Top Left and Top Right shortcuts may be taken; the Shortcuts tab then says the keys could not be turned on. Pick other keys for them.

## Settings

- **General**: open at login, show in the tray, space between windows (none, narrow, normal, wide = 0, 8, 16, 24), window control status
- **Effects**: briefly highlight the moved window (off, subtle, bold), color, show the shortcut, duration, label position. On Wayland apps can't place their own windows, so the highlight does not show.
- **Shortcuts**: click to change, × to clear, restore defaults

Settings are saved as `settings.json` in `%APPDATA%\im.runners.split\` on Windows and `~/.config/im.runners.split/` on Linux.

## Building from source

You need Node.js 22, pnpm and Rust (stable). On Linux also install the packages Tauri needs:

```sh
sudo apt install libwebkit2gtk-4.1-dev libayatana-appindicator3-dev librsvg2-dev libxdo-dev libssl-dev patchelf  # Ubuntu
```

```sh
cd desktop
pnpm install
cargo test -p split-core          # window math, arrange and undo tests (runs on macOS too)
pnpm tauri dev                    # run while developing
pnpm tauri build                  # installers → target.noindex/release/bundle/
```

Build output goes to `target.noindex/`; Spotlight skips folders whose name ends in `.noindex`.

### Layout

```
desktop/
├── core/                 shared logic, no OS calls: runs the macOS JS, gaps, arrange, undo, shortcut text
├── src-tauri/            the Tauri app (Rust): tray, settings file, move highlight
│   └── src/platform/     per OS: windows.rs, linux_x11.rs, linux_gnome.rs, linux_kde.rs
├── src/                  the settings window (React + TypeScript)
├── locales/              screen text (ko.json, en.json), read by both Rust and TypeScript
└── linux/
    ├── gnome-extension/  GNOME (Wayland) extension
    └── kwin-script/      KDE Plasma (Wayland) KWin script
```

CI is `.github/workflows/desktop.yml`: every PR that changes `desktop/` builds Windows (nsis, msi) and Linux (deb, rpm, AppImage) and attaches the files to the run.

## Issues and feedback

Please use [GitHub Issues](https://github.com/RUNNERS-IM/split/issues). **Help and Feedback** in the tray menu opens this page.

## License

MIT. See [LICENSE.md](../LICENSE.md) at the top of the repository.
