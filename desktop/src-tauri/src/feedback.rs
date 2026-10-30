//! The highlight that shows where a window went, with the shortcut and action name (the
//! "Effects" tab). It is one transparent, click-through window on top of everything that the
//! settings page draws into (`src/Feedback.tsx`).

use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;

use serde::Serialize;
use split_core::Rect;
use tauri::{AppHandle, Emitter, Manager, PhysicalPosition, PhysicalSize, WebviewUrl, WebviewWindowBuilder};

use crate::settings::Feedback;

pub const LABEL: &str = "feedback";

/// What the page needs to draw one highlight.
#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Show {
    /// "off", "subtle" or "strong"; "off" draws only the label.
    pub style: String,
    pub color: String,
    /// The action name or a message such as "3 windows arranged".
    pub title: String,
    /// Empty when the shortcut is not shown.
    pub shortcut: String,
    pub position: String,
    pub duration_ms: u64,
}

pub fn create(app: &AppHandle) -> tauri::Result<()> {
    let builder = WebviewWindowBuilder::new(app, LABEL, WebviewUrl::App("index.html".into()));
    // Why: macOS is not a target of this app, and there transparency needs a private API feature.
    #[cfg(not(target_os = "macos"))]
    let builder = builder.transparent(true);
    let window = builder
        .title("Split")
        .decorations(false)
        .always_on_top(true)
        .skip_taskbar(true)
        .resizable(false)
        .focused(false)
        .shadow(false)
        .visible(false)
        .build()?;
    window.set_ignore_cursor_events(true)?;
    Ok(())
}

static GENERATION: AtomicU64 = AtomicU64::new(0);

/// Shows the highlight over `rect` (physical pixels) and hides it again after the duration.
/// `focus_back` is the window that had the keyboard focus, for desktops where showing a window
/// can take the focus.
pub fn show(app: &AppHandle, rect: Rect, settings: &Feedback, title: String, shortcut: String, focus_back: impl FnOnce()) {
    if settings.style == "off" && !settings.show_shortcut {
        return;
    }
    let Some(window) = app.get_webview_window(LABEL) else {
        return;
    };
    let show = Show {
        style: settings.style.clone(),
        color: settings.color.clone(),
        // "Show the shortcut" covers both the keys and the action name, as on macOS.
        title: if settings.show_shortcut { title } else { String::new() },
        shortcut: if settings.show_shortcut { shortcut } else { String::new() },
        position: settings.position.clone(),
        duration_ms: settings.duration_ms(),
    };
    let generation = GENERATION.fetch_add(1, Ordering::SeqCst) + 1;
    let _ = window.set_position(PhysicalPosition::new(rect.x.round() as i32, rect.y.round() as i32));
    let _ = window.set_size(PhysicalSize::new(rect.width.max(1.0).round() as u32, rect.height.max(1.0).round() as u32));
    let _ = window.emit_to(LABEL, "feedback", &show);

    #[cfg(windows)]
    {
        let _ = &focus_back;
        if let Ok(hwnd) = window.hwnd() {
            crate::platform::windows::WindowsBackend::show_overlay(hwnd.0 as isize);
        }
    }
    #[cfg(not(windows))]
    {
        let _ = window.show();
        focus_back();
    }

    let hide_after = Duration::from_millis(show.duration_ms + 250);
    std::thread::spawn(move || {
        std::thread::sleep(hide_after);
        // A newer highlight keeps the window; only the last one hides it.
        if GENERATION.load(Ordering::SeqCst) == generation {
            let _ = window.hide();
        }
    });
}
