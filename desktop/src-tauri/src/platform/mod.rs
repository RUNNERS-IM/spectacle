//! What each desktop has to offer Split: listening for shortcuts, telling where windows and
//! monitors are, and moving windows. Everything else (the math, history, arrange) is shared
//! in `split-core`.
//!
//! - Windows: `windows.rs` (Win32).
//! - Linux X11 session, any desktop: `linux_x11.rs` (EWMH + RandR + XGrabKey).
//! - Linux Wayland: apps may not move other apps' windows, so the desktop does it for us.
//!   GNOME: `linux_gnome.rs` talks to the extension in `desktop/linux/gnome-extension/`.
//!   KDE Plasma: `linux_kde.rs` answers the KWin script in `desktop/linux/kwin-script/`.

use std::sync::Arc;

use serde::Serialize;
use split_core::shortcuts::KeyCombo;
use split_core::{Action, Move, Outcome, Snapshot};

#[cfg(target_os = "linux")]
pub mod linux_gnome;
#[cfg(target_os = "linux")]
pub mod linux_kde;
#[cfg(target_os = "linux")]
pub mod linux_x11;
#[cfg(windows)]
pub mod windows;

/// Called from the platform's shortcut thread when a shortcut is pressed.
pub type OnShortcut = Arc<dyn Fn(Action) + Send + Sync>;

/// Works out where windows go; used where the desktop moves the windows itself (KDE Wayland).
pub type Planner = Arc<dyn Fn(Action, &Snapshot) -> Outcome + Send + Sync>;

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Status {
    /// "windows", "x11", "gnome", "kde" or "unsupported".
    pub kind: &'static str,
    /// Whether windows can be moved right now (for GNOME and KDE: whether the extension or
    /// script is running).
    pub ready: bool,
    /// The desktop name from XDG_CURRENT_DESKTOP, for the "unsupported" message.
    pub desktop: String,
    /// Whether Split decides the shortcuts (false on KDE, where KWin owns them).
    pub owns_shortcuts: bool,
    /// Whether Split may place its own highlight window (false on Wayland).
    pub can_show_overlay: bool,
}

pub trait Backend: Send + Sync {
    /// The active window, the monitors and, when `with_windows`, every ordinary window front to back.
    fn snapshot(&self, with_windows: bool) -> Result<Snapshot, String>;
    fn apply(&self, moves: &[Move]) -> Result<(), String>;
    /// Replaces every shortcut. Returns the actions whose shortcut could not be turned on
    /// because something else already has it.
    fn set_shortcuts(&self, bindings: &[(Action, KeyCombo)]) -> Vec<Action>;
    fn status(&self) -> Status;
    /// Gives the keyboard focus back to a window, after the highlight window was shown.
    fn activate(&self, _id: u64) {}
}

/// Used where Split cannot move windows; the settings window explains why.
pub struct Unsupported {
    pub desktop: String,
}

impl Backend for Unsupported {
    fn snapshot(&self, _with_windows: bool) -> Result<Snapshot, String> {
        Err(format!("unsupported desktop: {}", self.desktop))
    }

    fn apply(&self, _moves: &[Move]) -> Result<(), String> {
        Err(format!("unsupported desktop: {}", self.desktop))
    }

    fn set_shortcuts(&self, _bindings: &[(Action, KeyCombo)]) -> Vec<Action> {
        Vec::new()
    }

    fn status(&self) -> Status {
        Status {
            kind: "unsupported",
            ready: false,
            desktop: self.desktop.clone(),
            owns_shortcuts: true,
            can_show_overlay: false,
        }
    }
}

/// Which way Split reaches the windows in this session.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Session {
    Windows,
    X11,
    Gnome,
    Kde,
    Unsupported,
}

/// Picks the platform layer from XDG_SESSION_TYPE and XDG_CURRENT_DESKTOP.
pub fn detect_session(session_type: Option<&str>, current_desktop: Option<&str>, has_x_display: bool) -> Session {
    if cfg!(windows) {
        return Session::Windows;
    }
    let desktops: Vec<String> = current_desktop
        .unwrap_or_default()
        .split(':')
        .map(|d| d.trim().to_ascii_uppercase())
        .collect();
    let is = |name: &str| desktops.iter().any(|d| d == name);
    match session_type.map(str::to_ascii_lowercase).as_deref() {
        Some("wayland") if is("GNOME") => Session::Gnome,
        Some("wayland") if is("KDE") => Session::Kde,
        Some("wayland") => Session::Unsupported,
        Some("x11") if has_x_display => Session::X11,
        _ if has_x_display => Session::X11,
        _ => Session::Unsupported,
    }
}

pub fn current_desktop() -> String {
    std::env::var("XDG_CURRENT_DESKTOP").unwrap_or_else(|_| "unknown".into())
}

/// Builds the platform layer for this session.
pub fn create(on_shortcut: OnShortcut, planner: Planner) -> Arc<dyn Backend> {
    #[cfg(windows)]
    {
        let _ = planner;
        Arc::new(windows::WindowsBackend::start(on_shortcut))
    }
    #[cfg(target_os = "linux")]
    {
        let session_type = std::env::var("XDG_SESSION_TYPE").ok();
        let desktop = std::env::var("XDG_CURRENT_DESKTOP").ok();
        let has_x = std::env::var_os("DISPLAY").is_some();
        match detect_session(session_type.as_deref(), desktop.as_deref(), has_x) {
            Session::X11 => match linux_x11::X11Backend::start(on_shortcut) {
                Ok(backend) => Arc::new(backend),
                Err(error) => {
                    eprintln!("split: X11 is not reachable: {error}");
                    Arc::new(Unsupported { desktop: current_desktop() })
                }
            },
            Session::Gnome => Arc::new(linux_gnome::GnomeBackend::start(on_shortcut)),
            Session::Kde => Arc::new(linux_kde::KdeBackend::start(planner)),
            _ => Arc::new(Unsupported { desktop: current_desktop() }),
        }
    }
    #[cfg(not(any(windows, target_os = "linux")))]
    {
        let _ = (on_shortcut, planner);
        Arc::new(Unsupported { desktop: std::env::consts::OS.into() })
    }
}

/// How a shortcut is written on this platform, for example `Win+Alt+←` or `Super+Alt+←`.
pub fn display_shortcut(combo: &KeyCombo) -> String {
    let logo = if cfg!(windows) { "Win" } else { "Super" };
    let mut parts: Vec<String> = Vec::new();
    if combo.modifiers.logo {
        parts.push(logo.into());
    }
    if combo.modifiers.ctrl {
        parts.push("Ctrl".into());
    }
    if combo.modifiers.alt {
        parts.push("Alt".into());
    }
    if combo.modifiers.shift {
        parts.push("Shift".into());
    }
    parts.push(display_key(&combo.key));
    parts.join("+")
}

fn display_key(key: &str) -> String {
    match key {
        "left" => "←".into(),
        "right" => "→".into(),
        "up" => "↑".into(),
        "down" => "↓".into(),
        "space" => "Space".into(),
        "enter" => "Enter".into(),
        "tab" => "Tab".into(),
        "backspace" => "Backspace".into(),
        "delete" => "Delete".into(),
        "insert" => "Insert".into(),
        "home" => "Home".into(),
        "end" => "End".into(),
        "pageup" => "PageUp".into(),
        "pagedown" => "PageDown".into(),
        "minus" => "-".into(),
        "equal" => "=".into(),
        "bracketleft" => "[".into(),
        "bracketright" => "]".into(),
        "semicolon" => ";".into(),
        "quote" => "'".into(),
        "comma" => ",".into(),
        "period" => ".".into(),
        "slash" => "/".into(),
        "backslash" => "\\".into(),
        "grave" => "`".into(),
        other => other.to_uppercase(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    #[cfg(not(windows))]
    fn sessions() {
        assert_eq!(detect_session(Some("wayland"), Some("ubuntu:GNOME"), true), Session::Gnome);
        assert_eq!(detect_session(Some("wayland"), Some("KDE"), true), Session::Kde);
        assert_eq!(detect_session(Some("wayland"), Some("sway"), true), Session::Unsupported);
        assert_eq!(detect_session(Some("x11"), Some("XFCE"), true), Session::X11);
        assert_eq!(detect_session(None, None, false), Session::Unsupported);
    }
}
