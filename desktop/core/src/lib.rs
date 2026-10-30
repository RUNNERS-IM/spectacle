//! The parts of Split that do not touch the operating system: which rectangle a window goes to,
//! how far apart windows sit, the auto-arrange layout, undo and redo, and shortcut names.
//!
//! Every platform layer (Windows, X11, GNOME, KDE) hands the same `Snapshot` in and gets the
//! same `Outcome` back, so the windows land on the same places as on macOS.

pub mod actions;
pub mod arrange;
pub mod calc;
pub mod engine;
pub mod geometry;
pub mod shortcuts;

pub use actions::Action;
pub use engine::{Engine, Feedback, Move, Outcome, Screen, Snapshot, WindowInfo};
pub use geometry::Rect;
