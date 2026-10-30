//! Auto-arrange layout. Port of `SplitArrangeLayoutRects` in
//! `Split/Sources/SplitWindowArranger.m`:
//!
//! 1 full · 2 halves · 3 left half + right column of two · 4 a 2×2 grid ·
//! 5 a 2×2 grid with the front window floating in the middle at 60% ·
//! 6 a 3×2 grid · 7 to 9 a 3×2 grid with the rest stacked in the middle at 60%, 30 px apart.

use crate::geometry::Rect;

/// The most windows auto-arrange places. Windows after this stay where they are.
pub const MAXIMUM_WINDOW_COUNT: usize = 9;
/// Windows narrower or shorter than this are not arranged (tool palettes, tiny popups).
pub const MINIMUM_WINDOW_SIDE: f64 = 80.0;

const FLOATING_SCALE: f64 = 0.6;
const STACK_OFFSET: f64 = 30.0;

fn grid_cell(frame: Rect, columns: usize, rows: usize, column: usize, row: usize) -> Rect {
    let mut width = (frame.width / columns as f64).floor();
    let mut height = (frame.height / rows as f64).floor();
    let x = frame.x + width * column as f64;
    let y = frame.y + height * row as f64;
    // The last column and row take what rounding left over so the grid fills the screen.
    if column == columns - 1 {
        width = frame.max_x() - x;
    }
    if row == rows - 1 {
        height = frame.max_y() - y;
    }
    Rect::new(x, y, width, height)
}

fn floating_rect(frame: Rect, stack_index: usize) -> Rect {
    let width = (frame.width * FLOATING_SCALE).round();
    let height = (frame.height * FLOATING_SCALE).round();
    let x = (frame.mid_x() - width / 2.0).round() + STACK_OFFSET * stack_index as f64;
    let y = (frame.mid_y() - height / 2.0).round() + STACK_OFFSET * stack_index as f64;
    Rect::new(x, y, width, height)
}

/// Where each window goes when `count` windows are arranged inside `frame` (top-left based).
/// The first rect is for the most recently used window.
pub fn layout_rects(count: usize, frame: Rect) -> Vec<Rect> {
    let count = count.min(MAXIMUM_WINDOW_COUNT);
    let mut rects = Vec::with_capacity(count);
    match count {
        0 => {}
        1 => rects.push(frame),
        2 => {
            rects.push(grid_cell(frame, 2, 1, 0, 0));
            rects.push(grid_cell(frame, 2, 1, 1, 0));
        }
        3 => {
            rects.push(grid_cell(frame, 2, 1, 0, 0));
            rects.push(grid_cell(frame, 2, 2, 1, 0));
            rects.push(grid_cell(frame, 2, 2, 1, 1));
        }
        4 | 5 => {
            if count == 5 {
                rects.push(floating_rect(frame, 0));
            }
            for row in 0..2 {
                for column in 0..2 {
                    rects.push(grid_cell(frame, 2, 2, column, row));
                }
            }
        }
        _ => {
            for row in 0..2 {
                for column in 0..3 {
                    rects.push(grid_cell(frame, 3, 2, column, row));
                }
            }
            for index in 6..count {
                rects.push(floating_rect(frame, index - 6));
            }
        }
    }
    rects
}

#[cfg(test)]
mod tests {
    use super::*;

    const FRAME: Rect = Rect::new(0.0, 0.0, 1921.0, 1041.0);

    #[test]
    fn counts_match_the_mac_layouts() {
        for count in 0..=12 {
            assert_eq!(layout_rects(count, FRAME).len(), count.min(MAXIMUM_WINDOW_COUNT));
        }
    }

    #[test]
    fn three_windows_are_one_big_and_two_stacked() {
        let rects = layout_rects(3, FRAME);
        assert_eq!(rects[0], Rect::new(0.0, 0.0, 960.0, 1041.0));
        assert_eq!(rects[1], Rect::new(960.0, 0.0, 961.0, 520.0));
        assert_eq!(rects[2], Rect::new(960.0, 520.0, 961.0, 521.0));
    }

    #[test]
    fn five_windows_float_the_front_one() {
        let rects = layout_rects(5, FRAME);
        assert_eq!(rects[0], Rect::new(384.0, 208.0, 1153.0, 625.0));
        assert_eq!(rects[4], Rect::new(960.0, 520.0, 961.0, 521.0));
    }
}
