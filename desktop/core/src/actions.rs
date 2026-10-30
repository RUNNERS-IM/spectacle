//! The window actions. Names match the macOS app: `name()` is the shortcut name and the
//! translation key, `js_name()` is the action the JavaScript calculations register under.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum Action {
    MoveToCenter,
    MoveToFullscreen,
    MoveToLeftHalf,
    MoveToRightHalf,
    MoveToTopHalf,
    MoveToBottomHalf,
    MoveToUpperLeft,
    MoveToLowerLeft,
    MoveToUpperRight,
    MoveToLowerRight,
    MoveToNextDisplay,
    MoveToPreviousDisplay,
    MoveToNextThird,
    MoveToPreviousThird,
    MakeLarger,
    MakeSmaller,
    UndoLastMove,
    RedoLastMove,
    ArrangeWindows,
}

/// Settings and menu sections, in the order the macOS settings window shows them.
pub const SECTIONS: &[(&str, &[Action])] = &[
    ("SectionBasic", &[Action::MoveToCenter, Action::MoveToFullscreen]),
    (
        "SectionHalves",
        &[Action::MoveToLeftHalf, Action::MoveToRightHalf, Action::MoveToTopHalf, Action::MoveToBottomHalf],
    ),
    (
        "SectionCorners",
        &[Action::MoveToUpperLeft, Action::MoveToUpperRight, Action::MoveToLowerLeft, Action::MoveToLowerRight],
    ),
    ("SectionThirds", &[Action::MoveToNextThird, Action::MoveToPreviousThird]),
    ("SectionDisplays", &[Action::MoveToNextDisplay, Action::MoveToPreviousDisplay]),
    ("SectionSize", &[Action::MakeLarger, Action::MakeSmaller]),
    ("SectionHistory", &[Action::UndoLastMove, Action::RedoLastMove]),
    ("SectionArrange", &[Action::ArrangeWindows]),
];

impl Action {
    pub const ALL: [Action; 19] = [
        Action::MoveToCenter,
        Action::MoveToFullscreen,
        Action::MoveToLeftHalf,
        Action::MoveToRightHalf,
        Action::MoveToTopHalf,
        Action::MoveToBottomHalf,
        Action::MoveToUpperLeft,
        Action::MoveToLowerLeft,
        Action::MoveToUpperRight,
        Action::MoveToLowerRight,
        Action::MoveToNextDisplay,
        Action::MoveToPreviousDisplay,
        Action::MoveToNextThird,
        Action::MoveToPreviousThird,
        Action::MakeLarger,
        Action::MakeSmaller,
        Action::UndoLastMove,
        Action::RedoLastMove,
        Action::ArrangeWindows,
    ];

    pub fn name(self) -> &'static str {
        match self {
            Action::MoveToCenter => "MoveToCenter",
            Action::MoveToFullscreen => "MoveToFullscreen",
            Action::MoveToLeftHalf => "MoveToLeftHalf",
            Action::MoveToRightHalf => "MoveToRightHalf",
            Action::MoveToTopHalf => "MoveToTopHalf",
            Action::MoveToBottomHalf => "MoveToBottomHalf",
            Action::MoveToUpperLeft => "MoveToUpperLeft",
            Action::MoveToLowerLeft => "MoveToLowerLeft",
            Action::MoveToUpperRight => "MoveToUpperRight",
            Action::MoveToLowerRight => "MoveToLowerRight",
            Action::MoveToNextDisplay => "MoveToNextDisplay",
            Action::MoveToPreviousDisplay => "MoveToPreviousDisplay",
            Action::MoveToNextThird => "MoveToNextThird",
            Action::MoveToPreviousThird => "MoveToPreviousThird",
            Action::MakeLarger => "MakeLarger",
            Action::MakeSmaller => "MakeSmaller",
            Action::UndoLastMove => "UndoLastMove",
            Action::RedoLastMove => "RedoLastMove",
            Action::ArrangeWindows => "ArrangeWindows",
        }
    }

    pub fn from_name(name: &str) -> Option<Action> {
        Action::ALL.into_iter().find(|a| a.name() == name)
    }

    /// The name used by `windowPositionCalculationRegistry` in the JavaScript files.
    pub fn js_name(self) -> Option<&'static str> {
        Some(match self {
            Action::MoveToCenter => "SplitWindowActionCenter",
            Action::MoveToFullscreen => "SplitWindowActionFullscreen",
            Action::MoveToLeftHalf => "SplitWindowActionLeftHalf",
            Action::MoveToRightHalf => "SplitWindowActionRightHalf",
            Action::MoveToTopHalf => "SplitWindowActionTopHalf",
            Action::MoveToBottomHalf => "SplitWindowActionBottomHalf",
            Action::MoveToUpperLeft => "SplitWindowActionUpperLeft",
            Action::MoveToLowerLeft => "SplitWindowActionLowerLeft",
            Action::MoveToUpperRight => "SplitWindowActionUpperRight",
            Action::MoveToLowerRight => "SplitWindowActionLowerRight",
            Action::MoveToNextDisplay => "SplitWindowActionNextDisplay",
            Action::MoveToPreviousDisplay => "SplitWindowActionPreviousDisplay",
            Action::MoveToNextThird => "SplitWindowActionNextThird",
            Action::MoveToPreviousThird => "SplitWindowActionPreviousThird",
            Action::MakeLarger => "SplitWindowActionLarger",
            Action::MakeSmaller => "SplitWindowActionSmaller",
            Action::UndoLastMove | Action::RedoLastMove | Action::ArrangeWindows => return None,
        })
    }

    /// Actions that fill a fraction of the screen and so leave a gap around the window.
    pub fn uses_gap(self) -> bool {
        matches!(
            self,
            Action::MoveToFullscreen
                | Action::MoveToLeftHalf
                | Action::MoveToRightHalf
                | Action::MoveToTopHalf
                | Action::MoveToBottomHalf
                | Action::MoveToUpperLeft
                | Action::MoveToUpperRight
                | Action::MoveToLowerLeft
                | Action::MoveToLowerRight
                | Action::MoveToNextThird
                | Action::MoveToPreviousThird
        )
    }

    pub fn moves_to_display(self) -> bool {
        matches!(self, Action::MoveToNextDisplay | Action::MoveToPreviousDisplay)
    }
}
