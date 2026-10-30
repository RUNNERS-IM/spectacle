//! User settings, kept as `settings.json` in the app's config folder
//! (`%APPDATA%\im.runners.split` on Windows, `~/.config/im.runners.split` on Linux).

use std::collections::BTreeMap;
use std::path::PathBuf;

use serde::{Deserialize, Serialize};
use split_core::geometry::DEFAULT_GAP;
use split_core::shortcuts::{default_shortcut, KeyCombo};
use split_core::Action;

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Feedback {
    /// "off", "subtle" or "strong".
    pub style: String,
    /// "accent", "blue", "purple", "pink", "orange", "green" or "gray".
    pub color: String,
    pub show_shortcut: bool,
    /// "short", "normal" or "long".
    pub duration: String,
    /// "bottom", "top" or "center".
    pub position: String,
}

impl Default for Feedback {
    fn default() -> Self {
        Self {
            style: "subtle".into(),
            color: "accent".into(),
            show_shortcut: true,
            duration: "normal".into(),
            position: "bottom".into(),
        }
    }
}

impl Feedback {
    pub fn duration_ms(&self) -> u64 {
        match self.duration.as_str() {
            "short" => 600,
            "long" => 1800,
            _ => 1100,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Settings {
    /// Space between windows in points: 0, 8, 16 or 24.
    pub gap: f64,
    pub launch_at_login: bool,
    pub show_tray_icon: bool,
    pub feedback: Feedback,
    /// Action name → shortcut. A missing action uses the default; `None` means cleared.
    pub shortcuts: BTreeMap<String, Option<String>>,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            gap: DEFAULT_GAP,
            launch_at_login: false,
            show_tray_icon: true,
            feedback: Feedback::default(),
            shortcuts: BTreeMap::new(),
        }
    }
}

impl Settings {
    /// The shortcut text in effect for `action`, after defaults.
    pub fn shortcut_text(&self, action: Action) -> Option<String> {
        match self.shortcuts.get(action.name()) {
            Some(value) => value.clone(),
            None => default_shortcut(action).map(str::to_owned),
        }
    }

    /// Every action that has a usable shortcut.
    pub fn bindings(&self) -> Vec<(Action, KeyCombo)> {
        Action::ALL
            .into_iter()
            .filter_map(|action| Some((action, KeyCombo::parse(&self.shortcut_text(action)?)?)))
            .collect()
    }

    /// Keeps values the app knows; anything else goes back to its default.
    pub fn sanitized(mut self) -> Self {
        let defaults = Self::default();
        if !split_core::geometry::GAP_CHOICES.contains(&self.gap) {
            self.gap = defaults.gap;
        }
        self.shortcuts.retain(|name, value| {
            Action::from_name(name).is_some() && value.as_deref().is_none_or(|v| KeyCombo::parse(v).is_some())
        });
        for value in self.shortcuts.values_mut() {
            *value = value.as_deref().and_then(KeyCombo::parse).map(|c| c.to_text());
        }
        self
    }
}

pub fn path(config_dir: PathBuf) -> PathBuf {
    config_dir.join("settings.json")
}

/// Reads the settings, or `None` when there is no file yet (first launch).
pub fn load(file: &PathBuf) -> Option<Settings> {
    let text = std::fs::read_to_string(file).ok()?;
    Some(serde_json::from_str::<Settings>(&text).unwrap_or_default().sanitized())
}

pub fn save(file: &PathBuf, settings: &Settings) -> std::io::Result<()> {
    if let Some(parent) = file.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let text = serde_json::to_string_pretty(settings).expect("settings always serialize");
    // Why: writing next to the file and renaming means a crash mid-write never leaves half a file.
    let temp = file.with_extension("json.tmp");
    std::fs::write(&temp, text)?;
    std::fs::rename(temp, file)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn defaults_bind_every_action() {
        assert_eq!(Settings::default().bindings().len(), Action::ALL.len());
    }

    #[test]
    fn cleared_and_changed_shortcuts() {
        let mut settings = Settings::default();
        settings.shortcuts.insert("MoveToCenter".into(), None);
        settings.shortcuts.insert("MoveToFullscreen".into(), Some("super+ctrl+F".into()));
        settings.shortcuts.insert("Nonsense".into(), Some("ctrl+a".into()));
        let settings = settings.sanitized();
        assert_eq!(settings.shortcut_text(Action::MoveToCenter), None);
        assert_eq!(settings.shortcut_text(Action::MoveToFullscreen).as_deref(), Some("ctrl+super+f"));
        assert!(!settings.shortcuts.contains_key("Nonsense"));
    }
}
