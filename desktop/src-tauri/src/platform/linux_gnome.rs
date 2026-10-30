//! GNOME on Wayland. Only GNOME Shell itself may move windows there, so the Split GNOME
//! extension (`desktop/linux/gnome-extension/`) does the reading, moving and key grabbing, and
//! this side talks to it over the session D-Bus:
//!
//! - `GetState(b withWindows) → s`: JSON `Snapshot` (active window, monitors, windows).
//! - `MoveWindow(t id, i x, i y, i w, i h) → b` and `MoveActiveWindow(i x, i y, i w, i h) → b`.
//! - `GetWorkAreas() → s`: JSON list of monitors with their work areas.
//! - `SetShortcuts(s json) → s`: grabs `{"MoveToLeftHalf": "<Alt><Super>Left", …}` and returns
//!   the JSON list of action names whose keys something else already holds.
//! - signal `Activated(s action)` when one of those shortcuts is pressed.

use std::sync::{Arc, Mutex};
use std::time::Duration;

use split_core::shortcuts::KeyCombo;
use split_core::{Action, Move, Snapshot};
use zbus::blocking::{Connection, MessageIterator};

use super::{Backend, OnShortcut, Status};

pub const NAME: &str = "im.runners.Split.Shell";
pub const PATH: &str = "/im/runners/Split/Shell";
pub const INTERFACE: &str = "im.runners.Split.Shell";

pub struct GnomeBackend {
    connection: Option<Connection>,
    bindings: Arc<Mutex<Vec<(Action, KeyCombo)>>>,
}

fn accelerators(bindings: &[(Action, KeyCombo)]) -> String {
    let map: serde_json::Map<String, serde_json::Value> = bindings
        .iter()
        .map(|(action, combo)| (action.name().to_owned(), combo.to_gtk_accelerator().into()))
        .collect();
    serde_json::Value::Object(map).to_string()
}

fn call<R>(connection: &Connection, method: &str, body: &(impl serde::Serialize + zbus::zvariant::DynamicType)) -> Result<R, String>
where
    R: serde::de::DeserializeOwned + zbus::zvariant::Type,
{
    let reply = connection
        .call_method(Some(NAME), PATH, Some(INTERFACE), method, body)
        .map_err(|e| e.to_string())?;
    reply.body().deserialize::<R>().map_err(|e| e.to_string())
}

fn name_owner(connection: &Connection) -> Option<String> {
    let reply = connection
        .call_method(
            Some("org.freedesktop.DBus"),
            "/org/freedesktop/DBus",
            Some("org.freedesktop.DBus"),
            "GetNameOwner",
            &(NAME,),
        )
        .ok()?;
    reply.body().deserialize::<String>().ok()
}

fn send_shortcuts(connection: &Connection, bindings: &[(Action, KeyCombo)]) -> Vec<Action> {
    match call::<String>(connection, "SetShortcuts", &(accelerators(bindings),)) {
        Ok(json) => serde_json::from_str::<Vec<String>>(&json)
            .unwrap_or_default()
            .iter()
            .filter_map(|name| Action::from_name(name))
            .collect(),
        Err(_) => Vec::new(),
    }
}

impl GnomeBackend {
    pub fn start(on_shortcut: OnShortcut) -> Self {
        let connection = Connection::session().map_err(|e| eprintln!("split: no session D-Bus: {e}")).ok();
        let bindings: Arc<Mutex<Vec<(Action, KeyCombo)>>> = Arc::default();
        if let Some(connection) = &connection {
            // Shortcut presses arrive as signals from the extension.
            let listener = connection.clone();
            std::thread::Builder::new()
                .name("split-gnome-signals".into())
                .spawn(move || {
                    let rule = zbus::MatchRule::builder()
                        .msg_type(zbus::message::Type::Signal)
                        .interface(INTERFACE)
                        .and_then(|b| b.member("Activated"))
                        .map(|b| b.build());
                    let iterator = rule.and_then(|rule| MessageIterator::for_match_rule(rule, &listener, None));
                    let Ok(iterator) = iterator.map_err(|e| eprintln!("split: cannot listen to the GNOME extension: {e}")) else {
                        return;
                    };
                    for message in iterator.flatten() {
                        if let Ok(name) = message.body().deserialize::<String>() {
                            if let Some(action) = Action::from_name(&name) {
                                on_shortcut(action);
                            }
                        }
                    }
                })
                .expect("failed to start the GNOME signal thread");

            // Why: when the extension is turned on or GNOME Shell restarts, it forgets the keys,
            // so they are sent again whenever the extension's D-Bus owner changes.
            let watcher = connection.clone();
            let watched = bindings.clone();
            std::thread::Builder::new()
                .name("split-gnome-watch".into())
                .spawn(move || {
                    let mut last_owner = None;
                    loop {
                        let owner = name_owner(&watcher);
                        if owner.is_some() && owner != last_owner {
                            let current = watched.lock().unwrap().clone();
                            send_shortcuts(&watcher, &current);
                        }
                        last_owner = owner;
                        std::thread::sleep(Duration::from_secs(3));
                    }
                })
                .expect("failed to start the GNOME watch thread");
        }
        Self { connection, bindings }
    }

    fn connection(&self) -> Result<&Connection, String> {
        self.connection.as_ref().ok_or_else(|| "no session D-Bus".to_owned())
    }
}

impl Backend for GnomeBackend {
    fn snapshot(&self, with_windows: bool) -> Result<Snapshot, String> {
        let json: String = call(self.connection()?, "GetState", &(with_windows,))?;
        serde_json::from_str(&json).map_err(|e| e.to_string())
    }

    fn apply(&self, moves: &[Move]) -> Result<(), String> {
        let connection = self.connection()?;
        for item in moves {
            let r = item.rect.rounded();
            let body = (item.id, r.x as i32, r.y as i32, r.width as i32, r.height as i32);
            let moved: bool = call(connection, "MoveWindow", &body)?;
            if !moved {
                return Err(format!("GNOME Shell did not move window {}", item.id));
            }
        }
        Ok(())
    }

    fn set_shortcuts(&self, bindings: &[(Action, KeyCombo)]) -> Vec<Action> {
        *self.bindings.lock().unwrap() = bindings.to_vec();
        match &self.connection {
            Some(connection) if name_owner(connection).is_some() => send_shortcuts(connection, bindings),
            _ => Vec::new(),
        }
    }

    fn status(&self) -> Status {
        Status {
            kind: "gnome",
            ready: self.connection.as_ref().is_some_and(|c| name_owner(c).is_some()),
            desktop: super::current_desktop(),
            owns_shortcuts: true,
            can_show_overlay: false,
        }
    }
}
