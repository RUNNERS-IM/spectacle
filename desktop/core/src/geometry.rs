//! Rectangles in top-left based screen coordinates (y grows downward), which is what Windows,
//! X11, GNOME Shell and KWin all use.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct Rect {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

impl Rect {
    pub const fn new(x: f64, y: f64, width: f64, height: f64) -> Self {
        Self { x, y, width, height }
    }

    pub fn max_x(&self) -> f64 {
        self.x + self.width
    }

    pub fn max_y(&self) -> f64 {
        self.y + self.height
    }

    pub fn mid_x(&self) -> f64 {
        self.x + self.width / 2.0
    }

    pub fn mid_y(&self) -> f64 {
        self.y + self.height / 2.0
    }

    pub fn area(&self) -> f64 {
        self.width.max(0.0) * self.height.max(0.0)
    }

    pub fn is_empty(&self) -> bool {
        self.width <= 0.0 || self.height <= 0.0
    }

    pub fn contains_point(&self, x: f64, y: f64) -> bool {
        x >= self.x && x < self.max_x() && y >= self.y && y < self.max_y()
    }

    pub fn contains_rect(&self, other: &Rect) -> bool {
        other.x >= self.x && other.y >= self.y && other.max_x() <= self.max_x() && other.max_y() <= self.max_y()
    }

    pub fn intersection(&self, other: &Rect) -> Option<Rect> {
        let x = self.x.max(other.x);
        let y = self.y.max(other.y);
        let max_x = self.max_x().min(other.max_x());
        let max_y = self.max_y().min(other.max_y());
        (max_x > x && max_y > y).then(|| Rect::new(x, y, max_x - x, max_y - y))
    }

    /// The same rectangle mirrored around y = 0. macOS hands the JavaScript calculations
    /// bottom-left based rectangles; mirroring turns ours into that and back again. Every
    /// calculation only adds, subtracts and rounds sizes, so where y = 0 sits does not matter.
    pub fn flipped(&self) -> Rect {
        Rect::new(self.x, -(self.y + self.height), self.width, self.height)
    }

    pub fn rounded(&self) -> Rect {
        Rect::new(self.x.round(), self.y.round(), self.width.round(), self.height.round())
    }
}

/// Apps such as terminals round their size to whole characters, so a window counts as still
/// where Split put it when every edge is within this distance.
pub const MATCH_TOLERANCE: f64 = 24.0;

pub fn roughly_equal(a: &Rect, b: &Rect) -> bool {
    (a.x - b.x).abs() <= MATCH_TOLERANCE
        && (a.y - b.y).abs() <= MATCH_TOLERANCE
        && (a.max_x() - b.max_x()).abs() <= MATCH_TOLERANCE
        && (a.max_y() - b.max_y()).abs() <= MATCH_TOLERANCE
}

/// Space between windows in points, as on macOS: none, narrow, normal, wide.
pub const GAP_CHOICES: [f64; 4] = [0.0, 8.0, 16.0, 24.0];
pub const DEFAULT_GAP: f64 = 8.0;

/// Shrinks `rect` by half of `gap` on every side that faces another window, so two neighbours
/// end up `gap` apart. Sides on the edge of `visible_frame` stay on the edge.
/// Port of `SplitRectWithGap` in `Split/Sources/SplitWindowArranger.m`.
pub fn rect_with_gap(rect: Rect, visible_frame: Rect, gap: f64) -> Rect {
    if gap <= 0.0 {
        return rect;
    }
    let half = gap / 2.0;
    let left = if (rect.x - visible_frame.x).abs() <= 1.0 { 0.0 } else { half };
    let right = if (rect.max_x() - visible_frame.max_x()).abs() <= 1.0 { 0.0 } else { half };
    let top = if (rect.y - visible_frame.y).abs() <= 1.0 { 0.0 } else { half };
    let bottom = if (rect.max_y() - visible_frame.max_y()).abs() <= 1.0 { 0.0 } else { half };
    let result = Rect::new(
        (rect.x + left).round(),
        (rect.y + top).round(),
        (rect.width - left - right).round(),
        (rect.height - top - bottom).round(),
    );
    if result.width > 0.0 && result.height > 0.0 {
        result
    } else {
        rect
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn gap_keeps_screen_edges_flush() {
        let screen = Rect::new(0.0, 0.0, 1920.0, 1040.0);
        let left = rect_with_gap(Rect::new(0.0, 0.0, 960.0, 1040.0), screen, 16.0);
        assert_eq!(left, Rect::new(0.0, 0.0, 952.0, 1040.0));
        let right = rect_with_gap(Rect::new(960.0, 0.0, 960.0, 1040.0), screen, 16.0);
        assert_eq!(right, Rect::new(968.0, 0.0, 952.0, 1040.0));
    }

    #[test]
    fn flipping_twice_is_identity() {
        let r = Rect::new(10.0, 20.0, 300.0, 400.0);
        assert_eq!(r.flipped().flipped(), r);
    }
}
