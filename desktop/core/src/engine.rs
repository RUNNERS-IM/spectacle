//! Turns "this shortcut was pressed, and this is what is on screen" into "move these windows
//! here". Port of `SplitWindowPositionManager.m`, `SplitScreenDetector.m`, `SplitHistory.m`
//! and the arrange part of `SplitWindowArranger.m`.

use std::collections::{HashMap, VecDeque};

use serde::{Deserialize, Serialize};

use crate::actions::Action;
use crate::arrange::{layout_rects, MAXIMUM_WINDOW_COUNT, MINIMUM_WINDOW_SIDE};
use crate::calc::calculate;
use crate::geometry::{rect_with_gap, roughly_equal, Rect};

/// One monitor. Both rects are top-left based in the coordinates the platform moves windows in.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct Screen {
    /// The whole monitor.
    pub frame: Rect,
    /// The monitor without taskbars, panels and docks.
    pub work_area: Rect,
    /// Pixels per point, so gaps look the same on high-density screens. 1 when unknown.
    #[serde(default = "one")]
    pub scale: f64,
    /// The main monitor; it comes first when monitors are put in order.
    #[serde(default)]
    pub primary: bool,
}

fn one() -> f64 {
    1.0
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct WindowInfo {
    /// Whatever the platform uses to find the window again (HWND, X11 window id, …).
    pub id: u64,
    /// Where the visible frame of the window is, without invisible borders or shadows.
    pub rect: Rect,
    /// Which app owns it; undo and redo keep one history per app, as on macOS.
    #[serde(default)]
    pub app: String,
}

/// What is on screen when a shortcut is pressed.
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct Snapshot {
    /// The window that has the keyboard focus.
    pub active: Option<WindowInfo>,
    pub screens: Vec<Screen>,
    /// Ordinary visible windows on the current desktop, front to back. Only needed for arrange.
    #[serde(default)]
    pub windows: Vec<WindowInfo>,
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct Move {
    pub id: u64,
    pub rect: Rect,
}

/// What to tell the user afterwards.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "kind", content = "count")]
pub enum Feedback {
    /// Nothing could move (no window, already there, only one monitor…). macOS beeps.
    Failed,
    Moved,
    Arranged(usize),
    NothingToArrange,
    ArrangeUndone,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Outcome {
    pub moves: Vec<Move>,
    pub feedback: Feedback,
}

impl Outcome {
    fn failed() -> Self {
        Self { moves: Vec::new(), feedback: Feedback::Failed }
    }
}

/// Undo history of one app, at most 50 places. Same behaviour as `SplitHistory.m`: adding a
/// place after an undo drops the places that redo would have gone to.
#[derive(Default)]
struct History {
    items: VecDeque<Move>,
    current: usize,
}

const HISTORY_LIMIT: usize = 50;

impl History {
    fn is_empty(&self) -> bool {
        self.items.is_empty()
    }

    fn add(&mut self, item: Move) {
        if !self.items.is_empty() {
            self.items.truncate(self.current + 1);
        }
        self.items.push_back(item);
        if self.items.len() > HISTORY_LIMIT {
            self.items.pop_front();
        }
        self.current = self.items.len() - 1;
    }

    fn previous(&mut self) -> Option<Move> {
        if self.items.is_empty() || self.current == 0 {
            return None;
        }
        self.current -= 1;
        self.items.get(self.current).copied()
    }

    fn next(&mut self) -> Option<Move> {
        if self.current + 1 >= self.items.len() {
            return None;
        }
        self.current += 1;
        self.items.get(self.current).copied()
    }
}

#[derive(Default)]
pub struct Engine {
    histories: HashMap<String, History>,
    /// Window → (rect before full screen, full screen rect), so pressing full screen again restores it.
    fullscreen_restore: HashMap<u64, (Rect, Rect)>,
    /// Window → (rect with the gap, the same rect without it). Halves and thirds cycle by
    /// comparing the window with exact fractions of the screen, so the calculation is given
    /// the rect without the gap.
    gapless: HashMap<u64, (Rect, Rect)>,
    /// Where each window of the last auto-arrange was before, so one undo puts all of them back.
    last_arrangement: Vec<Move>,
}

/// Screens in the order macOS uses for next and previous display: the main monitor first, then
/// the others from top to bottom and, after that, from right to left.
/// Port of `screensInConsistentOrder:` in `SplitScreenDetector.m`.
pub fn screens_in_consistent_order(screens: &[Screen]) -> Vec<Screen> {
    let mut ordered = screens.to_vec();
    let primary_first = |a: &Screen, b: &Screen| b.primary.cmp(&a.primary);
    ordered.sort_by(|a, b| {
        primary_first(a, b).then_with(|| a.frame.max_y().total_cmp(&b.frame.max_y()))
    });
    ordered.sort_by(|a, b| primary_first(a, b).then_with(|| b.frame.x.total_cmp(&a.frame.x)));
    ordered
}

/// The screen holding all of `rect`, else the one holding most of it, else the main one.
pub fn screen_containing(rect: &Rect, screens: &[Screen]) -> Option<Screen> {
    let main = screens.iter().find(|s| s.primary).or(screens.first()).copied();
    let mut best = main;
    let mut best_share = 0.0;
    for screen in screens {
        if screen.frame.contains_rect(rect) {
            return Some(*screen);
        }
        let share = screen.frame.intersection(rect).map_or(0.0, |i| i.area() / rect.area().max(1.0));
        if share > best_share {
            best_share = share;
            best = Some(*screen);
        }
    }
    best
}

fn neighbour_screen(source: &Screen, action: Action, ordered: &[Screen]) -> Option<Screen> {
    if ordered.len() <= 1 {
        return None;
    }
    let index = ordered.iter().position(|s| s.frame == source.frame)?;
    let count = ordered.len();
    let next = match action {
        Action::MoveToNextDisplay => (index + 1) % count,
        Action::MoveToPreviousDisplay => (index + count - 1) % count,
        _ => index,
    };
    Some(ordered[next])
}

impl Engine {
    pub fn new() -> Self {
        Self::default()
    }

    /// Where the windows go for `action`. `gap` is the space between windows in points; each
    /// screen's `scale` turns it into pixels.
    pub fn plan(&mut self, action: Action, snapshot: &Snapshot, gap: f64) -> Outcome {
        match action {
            Action::ArrangeWindows => self.arrange(snapshot, gap),
            Action::UndoLastMove if !self.last_arrangement.is_empty() => {
                let moves = std::mem::take(&mut self.last_arrangement);
                Outcome { moves, feedback: Feedback::ArrangeUndone }
            }
            Action::UndoLastMove | Action::RedoLastMove => {
                self.last_arrangement.clear();
                let Some(active) = &snapshot.active else {
                    return Outcome::failed();
                };
                let history = self.histories.entry(active.app.clone()).or_default();
                let item = if action == Action::UndoLastMove { history.previous() } else { history.next() };
                match item {
                    Some(item) => Outcome { moves: vec![item], feedback: Feedback::Moved },
                    None => Outcome::failed(),
                }
            }
            _ => {
                self.last_arrangement.clear();
                self.move_active(action, snapshot, gap)
            }
        }
    }

    fn move_active(&mut self, action: Action, snapshot: &Snapshot, gap: f64) -> Outcome {
        let Some(active) = &snapshot.active else {
            return Outcome::failed();
        };
        if active.rect.is_empty() {
            return Outcome::failed();
        }
        let ordered = screens_in_consistent_order(&snapshot.screens);
        let Some(source) = screen_containing(&active.rect, &ordered) else {
            return Outcome::failed();
        };
        let destination = if action.moves_to_display() {
            match neighbour_screen(&source, action, &ordered) {
                Some(screen) => screen,
                None => return Outcome::failed(),
            }
        } else {
            source
        };

        let history = self.histories.entry(active.app.clone()).or_default();
        if history.is_empty() {
            history.add(Move { id: active.id, rect: active.rect });
        }

        let restore = self.fullscreen_restore.remove(&active.id);
        if action == Action::MoveToFullscreen {
            if let Some((before, fullscreen)) = restore {
                if roughly_equal(&active.rect, &fullscreen) {
                    let item = Move { id: active.id, rect: before };
                    history.add(item);
                    return Outcome { moves: vec![item], feedback: Feedback::Moved };
                }
            }
        }

        let mut window_rect = active.rect;
        if let Some((with_gap, without_gap)) = self.gapless.remove(&active.id) {
            if roughly_equal(&window_rect, &with_gap) {
                window_rect = without_gap;
            }
        }

        let target = match calculate(action, window_rect, source.work_area, destination.work_area) {
            Ok(Some(rect)) => rect,
            _ => return Outcome::failed(),
        };
        if target == window_rect {
            return Outcome::failed();
        }
        let mut target = target;
        let pixels = gap * destination.scale;
        if pixels > 0.0 && action.uses_gap() {
            let gapless = target;
            target = rect_with_gap(target, destination.work_area, pixels);
            self.gapless.insert(active.id, (target, gapless));
        }
        let target = target.rounded();
        let item = Move { id: active.id, rect: target };
        history.add(item);
        if action == Action::MoveToFullscreen {
            self.fullscreen_restore.insert(active.id, (active.rect, target));
        }
        Outcome { moves: vec![item], feedback: Feedback::Moved }
    }

    fn arrange(&mut self, snapshot: &Snapshot, gap: f64) -> Outcome {
        let ordered = screens_in_consistent_order(&snapshot.screens);
        let main = ordered.first().copied();
        // The screen that holds the middle of the active window, or the main one.
        let screen = snapshot
            .active
            .as_ref()
            .and_then(|w| ordered.iter().find(|s| s.frame.contains_point(w.rect.mid_x(), w.rect.mid_y())).copied())
            .or(main);
        let Some(screen) = screen else {
            return Outcome { moves: Vec::new(), feedback: Feedback::NothingToArrange };
        };
        let windows: Vec<&WindowInfo> = snapshot
            .windows
            .iter()
            .filter(|w| w.rect.width >= MINIMUM_WINDOW_SIDE && w.rect.height >= MINIMUM_WINDOW_SIDE)
            .filter(|w| screen.frame.contains_point(w.rect.mid_x(), w.rect.mid_y()))
            .take(MAXIMUM_WINDOW_COUNT)
            .collect();
        if windows.is_empty() {
            return Outcome { moves: Vec::new(), feedback: Feedback::NothingToArrange };
        }
        let frame = screen.work_area;
        let pixels = gap * screen.scale;
        let moves: Vec<Move> = layout_rects(windows.len(), frame)
            .into_iter()
            .zip(&windows)
            .map(|(rect, window)| Move { id: window.id, rect: rect_with_gap(rect, frame, pixels).rounded() })
            .collect();
        self.last_arrangement = windows.iter().map(|w| Move { id: w.id, rect: w.rect }).collect();
        let count = moves.len();
        Outcome { moves, feedback: Feedback::Arranged(count) }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn screen(x: f64, primary: bool) -> Screen {
        Screen {
            frame: Rect::new(x, 0.0, 1920.0, 1080.0),
            work_area: Rect::new(x, 0.0, 1920.0, 1040.0),
            scale: 1.0,
            primary,
        }
    }

    fn snapshot(rect: Rect) -> Snapshot {
        Snapshot {
            active: Some(WindowInfo { id: 7, rect, app: "editor".into() }),
            screens: vec![screen(0.0, true), screen(1920.0, false)],
            windows: Vec::new(),
        }
    }

    #[test]
    fn halves_keep_cycling_with_a_gap() {
        let mut engine = Engine::new();
        let first = engine.plan(Action::MoveToLeftHalf, &snapshot(Rect::new(100.0, 100.0, 800.0, 600.0)), 16.0);
        assert_eq!(first.moves[0].rect, Rect::new(0.0, 0.0, 952.0, 1040.0));
        let second = engine.plan(Action::MoveToLeftHalf, &snapshot(first.moves[0].rect), 16.0);
        assert_eq!(second.moves[0].rect, Rect::new(0.0, 0.0, 1272.0, 1040.0));
    }

    #[test]
    fn fullscreen_twice_restores() {
        let mut engine = Engine::new();
        let start = Rect::new(100.0, 100.0, 800.0, 600.0);
        let full = engine.plan(Action::MoveToFullscreen, &snapshot(start), 0.0);
        assert_eq!(full.moves[0].rect, Rect::new(0.0, 0.0, 1920.0, 1040.0));
        let back = engine.plan(Action::MoveToFullscreen, &snapshot(full.moves[0].rect), 0.0);
        assert_eq!(back.moves[0].rect, start);
    }

    #[test]
    fn undo_and_redo_walk_the_history() {
        let mut engine = Engine::new();
        let start = Rect::new(100.0, 100.0, 800.0, 600.0);
        let half = engine.plan(Action::MoveToRightHalf, &snapshot(start), 0.0).moves[0].rect;
        let undo = engine.plan(Action::UndoLastMove, &snapshot(half), 0.0);
        assert_eq!(undo.moves[0].rect, start);
        let redo = engine.plan(Action::RedoLastMove, &snapshot(start), 0.0);
        assert_eq!(redo.moves[0].rect, half);
        assert_eq!(engine.plan(Action::RedoLastMove, &snapshot(half), 0.0).feedback, Feedback::Failed);
    }

    #[test]
    fn next_display_wraps_around() {
        let mut engine = Engine::new();
        let moved = engine.plan(Action::MoveToNextDisplay, &snapshot(Rect::new(0.0, 0.0, 800.0, 600.0)), 0.0);
        assert_eq!(moved.moves[0].rect, Rect::new(2480.0, 220.0, 800.0, 600.0));
        let back = engine.plan(Action::MoveToNextDisplay, &snapshot(moved.moves[0].rect), 0.0);
        assert_eq!(back.moves[0].rect, Rect::new(560.0, 220.0, 800.0, 600.0));
    }

    #[test]
    fn arrange_then_one_undo_puts_everything_back() {
        let mut engine = Engine::new();
        let mut snap = snapshot(Rect::new(100.0, 100.0, 800.0, 600.0));
        snap.windows = vec![
            WindowInfo { id: 1, rect: Rect::new(100.0, 100.0, 800.0, 600.0), app: "a".into() },
            WindowInfo { id: 2, rect: Rect::new(300.0, 200.0, 700.0, 500.0), app: "b".into() },
            WindowInfo { id: 3, rect: Rect::new(2000.0, 200.0, 700.0, 500.0), app: "c".into() },
            WindowInfo { id: 4, rect: Rect::new(10.0, 10.0, 40.0, 40.0), app: "d".into() },
        ];
        let arranged = engine.plan(Action::ArrangeWindows, &snap, 0.0);
        assert_eq!(arranged.feedback, Feedback::Arranged(2));
        assert_eq!(arranged.moves[0], Move { id: 1, rect: Rect::new(0.0, 0.0, 960.0, 1040.0) });
        let undone = engine.plan(Action::UndoLastMove, &snap, 0.0);
        assert_eq!(undone.feedback, Feedback::ArrangeUndone);
        assert_eq!(undone.moves.len(), 2);
    }

    #[test]
    fn primary_screen_comes_first() {
        let ordered = screens_in_consistent_order(&[screen(-1920.0, false), screen(0.0, true), screen(1920.0, false)]);
        assert!(ordered[0].primary);
        assert_eq!(ordered[1].frame.x, 1920.0);
    }
}
