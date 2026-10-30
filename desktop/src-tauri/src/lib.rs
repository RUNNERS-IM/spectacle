//! Split for Windows and Linux: a tray app that moves the focused window with keyboard
//! shortcuts, like the macOS app in the same repository.
//!
//! Flow of one shortcut: the platform layer hears the keys → `perform` asks it what is on
//! screen → `split_core::Engine` works out where windows go (with the macOS JavaScript math)
//! → the platform layer moves them → `feedback` shows where they went.

mod feedback;
mod i18n;
mod platform;
mod settings;

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::sync::mpsc;
use std::sync::{Arc, Mutex, OnceLock};

use i18n::t;
use platform::{Backend, Status};
use serde::Serialize;
use settings::Settings;
use split_core::actions::SECTIONS;
use split_core::shortcuts::{default_shortcut, KeyCombo};
use split_core::{Action, Engine, Feedback, Rect};
use tauri::menu::{AboutMetadataBuilder, Menu, MenuItem, PredefinedMenuItem};
use tauri::tray::{TrayIcon, TrayIconBuilder};
use tauri::{AppHandle, Manager, RunEvent, State, WindowEvent};
use tauri_plugin_autostart::{MacosLauncher, ManagerExt as _};
use tauri_plugin_opener::OpenerExt;

const TRAY_ID: &str = "split";
const SETTINGS_LABEL: &str = "settings";
const WEBSITE_URL: &str = "https://github.com/RUNNERS-IM/split";
const RELEASES_URL: &str = "https://github.com/RUNNERS-IM/split/releases";
const ISSUES_URL: &str = "https://github.com/RUNNERS-IM/split/issues";

struct AppState {
    settings: Mutex<Settings>,
    settings_file: PathBuf,
    engine: Mutex<Engine>,
    backend: OnceLock<Arc<dyn Backend>>,
    /// Actions whose shortcut could not be turned on because something else holds the keys.
    failures: Mutex<Vec<Action>>,
    refusing_app: Mutex<Option<String>>,
}

impl AppState {
    fn backend(&self) -> &Arc<dyn Backend> {
        self.backend.get().expect("the platform layer starts in setup")
    }
}

fn korean() -> bool {
    sys_locale::get_locale().is_some_and(|l| l.starts_with("ko"))
}

fn help_url() -> &'static str {
    if korean() {
        "https://github.com/RUNNERS-IM/split/blob/master/desktop/README.ko.md"
    } else {
        "https://github.com/RUNNERS-IM/split/blob/master/desktop/README.md"
    }
}

fn shortcut_label(settings: &Settings, action: Action) -> String {
    settings
        .shortcut_text(action)
        .and_then(|text| KeyCombo::parse(&text))
        .map(|combo| platform::display_shortcut(&combo))
        .unwrap_or_default()
}

/// Runs one action on the focused window (or all windows, for arrange).
fn perform(app: &AppHandle, action: Action) {
    let state = app.state::<AppState>();
    let backend = state.backend();
    let with_windows = action == Action::ArrangeWindows;
    let snapshot = match backend.snapshot(with_windows) {
        Ok(snapshot) => snapshot,
        Err(error) => {
            eprintln!("split: {}: {error}", action.name());
            return;
        }
    };
    let settings = state.settings.lock().unwrap().clone();
    let outcome = state.engine.lock().unwrap().plan(action, &snapshot, settings.gap);
    let active_app = snapshot.active.as_ref().map(|w| w.app.clone()).filter(|app| !app.is_empty());
    if let Err(error) = backend.apply(&outcome.moves) {
        eprintln!("split: {}: {error}", action.name());
        // Why: shown in settings so a shortcut that does nothing has a reason, as on macOS.
        if active_app.is_some() {
            *state.refusing_app.lock().unwrap() = active_app;
        }
        return;
    }
    {
        let mut refusing = state.refusing_app.lock().unwrap();
        if refusing.is_some() && *refusing == active_app {
            *refusing = None;
        }
    }
    if !backend.status().can_show_overlay {
        return;
    }
    let shortcut = shortcut_label(&settings, action);
    let screen_of = |rect: &Rect| split_core::engine::screen_containing(rect, &snapshot.screens).map(|s| s.work_area);
    let (rect, title) = match outcome.feedback {
        Feedback::Failed => return,
        Feedback::Moved => match outcome.moves.first() {
            Some(item) => (item.rect, t(&format!("action.{}", action.name()), &[])),
            None => return,
        },
        Feedback::Arranged(count) => {
            let Some(area) = outcome.moves.first().and_then(|m| screen_of(&m.rect)) else { return };
            (area, t("feedback.arrangedCount", &[("count", &count.to_string())]))
        }
        Feedback::NothingToArrange => {
            let Some(area) = snapshot.active.as_ref().and_then(|w| screen_of(&w.rect)).or_else(|| {
                split_core::engine::screens_in_consistent_order(&snapshot.screens).first().map(|s| s.work_area)
            }) else {
                return;
            };
            (area, t("feedback.nothingToArrange", &[]))
        }
        Feedback::ArrangeUndone => {
            let Some(area) = outcome.moves.first().and_then(|m| screen_of(&m.rect)) else { return };
            (area, t("feedback.arrangeUndone", &[]))
        }
    };
    let mut overlay_settings = settings.feedback.clone();
    if !matches!(outcome.feedback, Feedback::Moved) {
        // Arrange messages are a label in the middle of the screen, without a frame.
        overlay_settings.style = "off".into();
        overlay_settings.show_shortcut = true;
        overlay_settings.position = "center".into();
    }
    let focus_back = snapshot.active.as_ref().map(|w| w.id);
    let backend = backend.clone();
    feedback::show(app, rect, &overlay_settings, title, shortcut, move || {
        if let Some(id) = focus_back {
            backend.activate(id);
        }
    });
}

/// Turns the shortcuts in `settings` on, and remembers which ones could not be.
fn register_shortcuts(state: &AppState) {
    let bindings = state.settings.lock().unwrap().bindings();
    let failed = state.backend().set_shortcuts(&bindings);
    *state.failures.lock().unwrap() = failed;
}

fn build_menu(app: &AppHandle, settings: &Settings) -> tauri::Result<Menu<tauri::Wry>> {
    // Why: Split, Prompt and Monitor share this menu order: app features, then about, updates,
    // settings and help together, then quit on its own.
    let about = PredefinedMenuItem::about(
        app,
        Some(&t("menu.about", &[])),
        Some(
            AboutMetadataBuilder::new()
                .name(Some("Split"))
                .version(Some(app.package_info().version.to_string()))
                .copyright(Some("© 2026 RUNNERS. All rights reserved."))
                .website(Some(WEBSITE_URL))
                .build(),
        ),
    )?;
    let updates = MenuItem::with_id(app, "updates", t("menu.checkUpdates", &[]), true, None::<&str>)?;
    let mut action_items = Vec::new();
    for (_, actions) in SECTIONS {
        for action in *actions {
            let mut label = t(&format!("action.{}", action.name()), &[]);
            // Windows draws the text after a tab as the right-aligned shortcut column.
            if cfg!(windows) {
                let shortcut = shortcut_label(settings, *action);
                if !shortcut.is_empty() {
                    label = format!("{label}\t{shortcut}");
                }
            }
            action_items.push(MenuItem::with_id(app, format!("action:{}", action.name()), label, true, None::<&str>)?);
        }
    }
    let settings_item = MenuItem::with_id(app, "settings", t("menu.settings", &[]), true, None::<&str>)?;
    let help = MenuItem::with_id(app, "help", t("menu.help", &[]), true, None::<&str>)?;
    let quit = MenuItem::with_id(app, "quit", t("menu.quit", &[]), true, None::<&str>)?;
    let separators = [PredefinedMenuItem::separator(app)?, PredefinedMenuItem::separator(app)?];
    let mut items: Vec<&dyn tauri::menu::IsMenuItem<tauri::Wry>> = Vec::new();
    for item in &action_items {
        items.push(item);
    }
    items.push(&separators[0]);
    items.push(&about);
    items.push(&updates);
    items.push(&settings_item);
    items.push(&help);
    items.push(&separators[1]);
    items.push(&quit);
    Menu::with_items(app, &items)
}

fn build_tray(app: &AppHandle, settings: &Settings) -> tauri::Result<TrayIcon> {
    let menu = build_menu(app, settings)?;
    let mut tray = TrayIconBuilder::with_id(TRAY_ID).tooltip(t("tray.tooltip", &[])).menu(&menu);
    if let Some(icon) = app.default_window_icon() {
        tray = tray.icon(icon.clone());
    }
    tray.on_menu_event(|app, event| {
        let id = event.id.as_ref();
        if let Some(action) = id.strip_prefix("action:").and_then(Action::from_name) {
            let app = app.clone();
            // Why: moving windows waits on other apps; the menu thread must not wait with it.
            std::thread::spawn(move || perform(&app, action));
            return;
        }
        match id {
            "updates" => open_url(app, RELEASES_URL),
            "settings" => show_settings(app),
            "help" => open_url(app, help_url()),
            "quit" => app.exit(0),
            _ => {}
        }
    })
    .build(app)
}

fn open_url(app: &AppHandle, url: &str) {
    let _ = app.opener().open_url(url, None::<&str>);
}

fn show_settings(app: &AppHandle) {
    if let Some(window) = app.get_webview_window(SETTINGS_LABEL) {
        let _ = window.show();
        let _ = window.unminimize();
        let _ = window.set_focus();
    }
}

/// Everything the settings page shows.
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct ViewState {
    settings: Settings,
    defaults: BTreeMap<&'static str, &'static str>,
    sections: Vec<(&'static str, Vec<&'static str>)>,
    status: Status,
    failures: Vec<&'static str>,
    /// The app whose window Split last failed to move, if it has not moved since.
    refusing_app: Option<String>,
    version: String,
    platform: &'static str,
}

fn view_state(app: &AppHandle, state: &AppState) -> ViewState {
    ViewState {
        settings: state.settings.lock().unwrap().clone(),
        defaults: Action::ALL.into_iter().filter_map(|a| Some((a.name(), default_shortcut(a)?))).collect(),
        sections: SECTIONS.iter().map(|(key, actions)| (*key, actions.iter().map(|a| a.name()).collect())).collect(),
        status: state.backend().status(),
        failures: state.failures.lock().unwrap().iter().map(|a| a.name()).collect(),
        refusing_app: state.refusing_app.lock().unwrap().clone(),
        version: app.package_info().version.to_string(),
        platform: if cfg!(windows) { "windows" } else { "linux" },
    }
}

#[tauri::command]
fn get_state(app: AppHandle, state: State<'_, AppState>) -> ViewState {
    view_state(&app, &state)
}

#[tauri::command]
fn save_settings(app: AppHandle, state: State<'_, AppState>, settings: Settings) -> Result<ViewState, String> {
    let settings = settings.sanitized();
    let previous = std::mem::replace(&mut *state.settings.lock().unwrap(), settings.clone());
    settings::save(&state.settings_file, &settings).map_err(|e| e.to_string())?;
    if previous.shortcuts != settings.shortcuts {
        register_shortcuts(&state);
    }
    if previous.launch_at_login != settings.launch_at_login {
        let autolaunch = app.autolaunch();
        let result = if settings.launch_at_login { autolaunch.enable() } else { autolaunch.disable() };
        result.map_err(|e| e.to_string())?;
    }
    if let Some(tray) = app.tray_by_id(TRAY_ID) {
        let _ = tray.set_visible(settings.show_tray_icon);
        if let Ok(menu) = build_menu(&app, &settings) {
            let _ = tray.set_menu(Some(menu));
        }
    }
    Ok(view_state(&app, &state))
}

#[tauri::command]
fn restore_default_shortcuts(app: AppHandle, state: State<'_, AppState>) -> Result<ViewState, String> {
    let mut settings = state.settings.lock().unwrap().clone();
    settings.shortcuts.clear();
    save_settings(app, state, settings)
}

/// While a shortcut is being recorded, Split lets go of its own keys so they reach the page.
#[tauri::command]
fn set_recording(state: State<'_, AppState>, recording: bool) {
    if recording {
        state.backend().set_shortcuts(&[]);
    } else {
        register_shortcuts(&state);
    }
}

/// Plays the highlight around the settings window with the current settings.
#[tauri::command]
fn preview_feedback(app: AppHandle, state: State<'_, AppState>) {
    let Some(window) = app.get_webview_window(SETTINGS_LABEL) else {
        return;
    };
    let (Ok(position), Ok(size)) = (window.outer_position(), window.outer_size()) else {
        return;
    };
    let rect = Rect::new(position.x as f64, position.y as f64, size.width as f64, size.height as f64);
    let settings = state.settings.lock().unwrap().clone();
    let shortcut = shortcut_label(&settings, Action::MoveToCenter);
    feedback::show(&app, rect, &settings.feedback, t("action.MoveToCenter", &[]), shortcut, || {});
    let _ = window.set_focus();
}

#[tauri::command]
fn open_link(app: AppHandle, kind: String) {
    let url = match kind.as_str() {
        "help" => help_url(),
        "releases" => RELEASES_URL,
        "issues" => ISSUES_URL,
        _ => WEBSITE_URL,
    };
    open_url(&app, url);
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let app = tauri::Builder::default()
        // Why: opening Split a second time is how people get back to settings when the tray icon is hidden.
        .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| show_settings(app)))
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_autostart::init(MacosLauncher::LaunchAgent, None))
        .invoke_handler(tauri::generate_handler![
            get_state,
            save_settings,
            restore_default_shortcuts,
            set_recording,
            preview_feedback,
            open_link
        ])
        .on_window_event(|window, event| {
            // Closing settings only hides it; Split keeps running in the tray.
            if let WindowEvent::CloseRequested { api, .. } = event {
                if window.label() == SETTINGS_LABEL {
                    api.prevent_close();
                    let _ = window.hide();
                }
            }
        })
        .setup(|app| {
            let config_dir = app.path().app_config_dir()?;
            let settings_file = settings::path(config_dir);
            let loaded = settings::load(&settings_file);
            let first_launch = loaded.is_none();
            let settings = loaded.unwrap_or_default();
            app.manage(AppState {
                settings: Mutex::new(settings.clone()),
                settings_file,
                engine: Mutex::new(Engine::new()),
                backend: OnceLock::new(),
                failures: Mutex::new(Vec::new()),
                refusing_app: Mutex::new(None),
            });

            // One worker runs actions in the order the keys were pressed, off the key thread.
            let (sender, receiver) = mpsc::channel::<Action>();
            let handle = app.handle().clone();
            std::thread::Builder::new()
                .name("split-actions".into())
                .spawn(move || {
                    for action in receiver {
                        perform(&handle, action);
                    }
                })?;
            let on_shortcut: platform::OnShortcut = Arc::new(move |action| {
                let _ = sender.send(action);
            });
            let handle = app.handle().clone();
            let planner: platform::Planner = Arc::new(move |action, snapshot| {
                let state = handle.state::<AppState>();
                let gap = state.settings.lock().unwrap().gap;
                let mut engine = state.engine.lock().unwrap();
                engine.plan(action, snapshot, gap)
            });
            let state = app.state::<AppState>();
            let _ = state.backend.set(platform::create(on_shortcut, planner));
            register_shortcuts(&state);

            let tray = build_tray(app.handle(), &settings)?;
            tray.set_visible(settings.show_tray_icon)?;
            feedback::create(app.handle())?;

            if let Some(window) = app.get_webview_window(SETTINGS_LABEL) {
                window.set_title(&t("settings.title", &[]))?;
                if first_launch {
                    window.show()?;
                    window.set_focus()?;
                }
            }
            Ok(())
        })
        .build(tauri::generate_context!())
        .expect("error while building Split");

    app.run(|_app, event| {
        // Split lives in the tray, so hiding the last window must not quit it.
        if let RunEvent::ExitRequested { api, code: None, .. } = event {
            api.prevent_exit();
        }
    });
}
