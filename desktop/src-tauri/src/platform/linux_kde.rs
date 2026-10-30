//! KDE Plasma on Wayland. A KWin script (`desktop/linux/kwin-script/`) owns the shortcuts and
//! moves the windows; KWin scripts can call D-Bus but cannot be called, so the script asks this
//! app where windows go:
//!
//! `im.runners.Split` at `/im/runners/Split`, interface `im.runners.Split`:
//! `Plan(s action, s stateJson) → s outcomeJson`. The state is a `Snapshot` in which window ids
//! are positions in the script's own list; the outcome lists the moves to make.

use split_core::shortcuts::KeyCombo;
use split_core::{Action, Move, Outcome, Snapshot};
use zbus::blocking::Connection;

use super::{Backend, Planner, Status};

pub const NAME: &str = "im.runners.Split";
pub const PATH: &str = "/im/runners/Split";

struct PlanService {
    planner: Planner,
}

#[zbus::interface(name = "im.runners.Split")]
impl PlanService {
    /// Where the windows go for `action`, given what the KWin script sees on screen.
    fn plan(&self, action: &str, state: &str) -> String {
        let outcome = match (Action::from_name(action), serde_json::from_str::<Snapshot>(state)) {
            (Some(action), Ok(snapshot)) => (self.planner)(action, &snapshot),
            _ => Outcome { moves: Vec::new(), feedback: split_core::Feedback::Failed },
        };
        serde_json::to_string(&outcome).unwrap_or_else(|_| "{}".into())
    }
}

pub struct KdeBackend {
    connection: Option<Connection>,
}

impl KdeBackend {
    pub fn start(planner: Planner) -> Self {
        let connection = zbus::blocking::connection::Builder::session()
            .and_then(|b| b.name(NAME))
            .and_then(|b| b.serve_at(PATH, PlanService { planner }))
            .and_then(|b| b.build())
            .map_err(|e| eprintln!("split: cannot offer {NAME} on D-Bus: {e}"))
            .ok();
        Self { connection }
    }

    fn script_loaded(&self) -> bool {
        let Some(connection) = &self.connection else {
            return false;
        };
        connection
            .call_method(Some("org.kde.KWin"), "/Scripting", Some("org.kde.kwin.Scripting"), "isScriptLoaded", &("split",))
            .ok()
            .and_then(|reply| reply.body().deserialize::<bool>().ok())
            .unwrap_or(false)
    }
}

impl Backend for KdeBackend {
    fn snapshot(&self, _with_windows: bool) -> Result<Snapshot, String> {
        Err("on KDE Plasma (Wayland) the KWin script reads the windows".into())
    }

    fn apply(&self, _moves: &[Move]) -> Result<(), String> {
        Err("on KDE Plasma (Wayland) the KWin script moves the windows".into())
    }

    fn set_shortcuts(&self, _bindings: &[(Action, KeyCombo)]) -> Vec<Action> {
        // KWin owns the shortcuts; people change them in System Settings › Shortcuts › KWin.
        Vec::new()
    }

    fn status(&self) -> Status {
        Status {
            kind: "kde",
            ready: self.script_loaded(),
            desktop: super::current_desktop(),
            owns_shortcuts: false,
            can_show_overlay: false,
        }
    }
}
