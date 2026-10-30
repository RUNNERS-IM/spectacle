//! Shortcuts are stored as text such as `"alt+super+left"`: modifiers first (ctrl, alt, shift,
//! super, in that order), then one key. `super` is the Windows key on Windows and the Super
//! (logo) key on Linux; it stands where the macOS app uses ⌘.

use serde::{Deserialize, Serialize};

use crate::actions::Action;

/// The macOS defaults from `SplitDefaultShortcutHelpers.m` with ⌘ turned into `super`.
pub const DEFAULT_SHORTCUTS: &[(Action, &str)] = &[
    (Action::MoveToCenter, "alt+super+c"),
    (Action::MoveToFullscreen, "alt+super+f"),
    (Action::MoveToLeftHalf, "alt+super+left"),
    (Action::MoveToRightHalf, "alt+super+right"),
    (Action::MoveToTopHalf, "alt+super+up"),
    (Action::MoveToBottomHalf, "alt+super+down"),
    (Action::MoveToUpperLeft, "ctrl+super+left"),
    (Action::MoveToLowerLeft, "ctrl+shift+super+left"),
    (Action::MoveToUpperRight, "ctrl+super+right"),
    (Action::MoveToLowerRight, "ctrl+shift+super+right"),
    (Action::MoveToNextDisplay, "ctrl+alt+super+right"),
    (Action::MoveToPreviousDisplay, "ctrl+alt+super+left"),
    (Action::MoveToNextThird, "ctrl+alt+right"),
    (Action::MoveToPreviousThird, "ctrl+alt+left"),
    (Action::MakeLarger, "ctrl+alt+shift+right"),
    (Action::MakeSmaller, "ctrl+alt+shift+left"),
    (Action::UndoLastMove, "alt+super+z"),
    (Action::RedoLastMove, "alt+shift+super+z"),
    (Action::ArrangeWindows, "alt+super+a"),
];

pub fn default_shortcut(action: Action) -> Option<&'static str> {
    DEFAULT_SHORTCUTS.iter().find(|(a, _)| *a == action).map(|(_, s)| *s)
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct Modifiers {
    pub ctrl: bool,
    pub alt: bool,
    pub shift: bool,
    #[serde(rename = "super")]
    pub logo: bool,
}

/// One parsed shortcut. `key` is lower case: `a`–`z`, `0`–`9`, `f1`–`f24`, `left`, `right`,
/// `up`, `down`, `space`, `enter`, `tab`, `backspace`, `delete`, `insert`, `home`, `end`,
/// `pageup`, `pagedown`, `minus`, `equal`, `bracketleft`, `bracketright`, `semicolon`,
/// `quote`, `comma`, `period`, `slash`, `backslash`, `grave`.
#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub struct KeyCombo {
    pub modifiers: Modifiers,
    pub key: String,
}

const NAMED_KEYS: &[&str] = &[
    "left", "right", "up", "down", "space", "enter", "tab", "backspace", "delete", "insert", "home", "end",
    "pageup", "pagedown", "minus", "equal", "bracketleft", "bracketright", "semicolon", "quote", "comma",
    "period", "slash", "backslash", "grave",
];

pub fn is_known_key(key: &str) -> bool {
    let single = key.len() == 1 && key.chars().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit());
    let function = key
        .strip_prefix('f')
        .and_then(|n| n.parse::<u8>().ok())
        .is_some_and(|n| (1..=24).contains(&n));
    single || function || NAMED_KEYS.contains(&key)
}

impl KeyCombo {
    pub fn parse(text: &str) -> Option<KeyCombo> {
        let mut modifiers = Modifiers::default();
        let mut key = None;
        for part in text.split('+').map(|p| p.trim().to_ascii_lowercase()) {
            match part.as_str() {
                "ctrl" | "control" => modifiers.ctrl = true,
                "alt" | "option" => modifiers.alt = true,
                "shift" => modifiers.shift = true,
                "super" | "win" | "meta" | "cmd" => modifiers.logo = true,
                other if key.is_none() && is_known_key(other) => key = Some(other.to_owned()),
                _ => return None,
            }
        }
        let key = key?;
        // A shortcut without any modifier other than shift would swallow normal typing.
        if !(modifiers.ctrl || modifiers.alt || modifiers.logo) {
            return None;
        }
        Some(KeyCombo { modifiers, key })
    }

    /// The stored form, with modifiers in a fixed order so equal shortcuts compare equal.
    pub fn to_text(&self) -> String {
        let mut parts: Vec<&str> = Vec::new();
        if self.modifiers.ctrl {
            parts.push("ctrl");
        }
        if self.modifiers.alt {
            parts.push("alt");
        }
        if self.modifiers.shift {
            parts.push("shift");
        }
        if self.modifiers.logo {
            parts.push("super");
        }
        parts.push(&self.key);
        parts.join("+")
    }

    /// The accelerator text GNOME Shell understands, for example `<Control><Super>Left`.
    pub fn to_gtk_accelerator(&self) -> String {
        let mut text = String::new();
        if self.modifiers.ctrl {
            text.push_str("<Control>");
        }
        if self.modifiers.alt {
            text.push_str("<Alt>");
        }
        if self.modifiers.shift {
            text.push_str("<Shift>");
        }
        if self.modifiers.logo {
            text.push_str("<Super>");
        }
        text.push_str(&x11_keysym_name(&self.key));
        text
    }
}

/// The X11 / GTK key name for one of our key names.
pub fn x11_keysym_name(key: &str) -> String {
    match key {
        "left" => "Left".into(),
        "right" => "Right".into(),
        "up" => "Up".into(),
        "down" => "Down".into(),
        "space" => "space".into(),
        "enter" => "Return".into(),
        "tab" => "Tab".into(),
        "backspace" => "BackSpace".into(),
        "delete" => "Delete".into(),
        "insert" => "Insert".into(),
        "home" => "Home".into(),
        "end" => "End".into(),
        "pageup" => "Page_Up".into(),
        "pagedown" => "Page_Down".into(),
        "minus" => "minus".into(),
        "equal" => "equal".into(),
        "bracketleft" => "bracketleft".into(),
        "bracketright" => "bracketright".into(),
        "semicolon" => "semicolon".into(),
        "quote" => "apostrophe".into(),
        "comma" => "comma".into(),
        "period" => "period".into(),
        "slash" => "slash".into(),
        "backslash" => "backslash".into(),
        "grave" => "grave".into(),
        f if f.starts_with('f') && f.len() > 1 => f.to_uppercase(),
        other => other.into(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_default_parses_and_round_trips() {
        for (action, text) in DEFAULT_SHORTCUTS {
            let combo = KeyCombo::parse(text).unwrap_or_else(|| panic!("{action:?}"));
            assert_eq!(&combo.to_text(), text);
        }
        assert_eq!(DEFAULT_SHORTCUTS.len(), Action::ALL.len());
    }

    #[test]
    fn plain_letters_are_refused() {
        assert!(KeyCombo::parse("a").is_none());
        assert!(KeyCombo::parse("shift+a").is_none());
        assert!(KeyCombo::parse("ctrl+nonsense").is_none());
    }

    #[test]
    fn gnome_accelerators() {
        let combo = KeyCombo::parse("ctrl+shift+super+left").unwrap();
        assert_eq!(combo.to_gtk_accelerator(), "<Control><Shift><Super>Left");
    }
}
