//! Runs the macOS app's window position calculations (`Split/Resources/Window Position
//! Calculations/*.js`) in QuickJS. The files are compiled in from where the macOS app keeps
//! them, so there is one copy of the math for every platform.

use rquickjs::{Context, Runtime};

use crate::actions::Action;
use crate::geometry::Rect;

macro_rules! calculation_scripts {
    ($($file:literal),* $(,)?) => {
        &[$(($file, include_str!(concat!(
            "../../../Split/Resources/Window Position Calculations/", $file
        )))),*]
    };
}

/// Every file the macOS bundle loads from "Window Position Calculations". Each file only
/// refers to the others inside functions, so the order does not matter.
pub const SCRIPTS: &[(&str, &str)] = calculation_scripts![
    "SplitWindowCalculationHelpers.js",
    "SplitCenterWindowCalculation.js",
    "SplitNextOrPreviousDisplay.js",
    "SplitNextOrPreviousThirds.js",
    "SplitWindowSizeAdjuster.js",
    "SplitBottomHalfWindowCalculation.js",
    "SplitFullscreenWindowCalculation.js",
    "SplitLargerWindowCalculation.js",
    "SplitLeftHalfWindowCalculation.js",
    "SplitLowerLeftWindowCalculation.js",
    "SplitLowerRightWindowCalculation.js",
    "SplitNextDisplayWindowCalculation.js",
    "SplitNextThirdWindowCalculation.js",
    "SplitPreviousDisplayWindowCalculation.js",
    "SplitPreviousThirdWindowCalculation.js",
    "SplitRightHalfWindowCalculation.js",
    "SplitSmallerWindowCalculation.js",
    "SplitTopHalfWindowCalculation.js",
    "SplitUpperLeftWindowCalculation.js",
    "SplitUpperRightWindowCalculation.js",
];

/// What `SplitWindowPositionCalculator.m` puts into the JavaScriptCore context: the registry
/// and the CoreGraphics helpers the scripts call.
const PRELUDE: &str = r#"
var __splitCalculations = {};
var windowPositionCalculationRegistry = {
    registerWindowPositionCalculationWithAction: function (calculation, action) {
        __splitCalculations[action] = calculation;
    }
};
function CGRectGetMinX(r) { return r.x; }
function CGRectGetMinY(r) { return r.y; }
function CGRectGetMidX(r) { return r.x + r.width / 2; }
function CGRectGetMidY(r) { return r.y + r.height / 2; }
function CGRectGetMaxX(r) { return r.x + r.width; }
function CGRectGetMaxY(r) { return r.y + r.height; }
function CGRectContainsRect(a, b) {
    return b.x >= a.x && b.y >= a.y && b.x + b.width <= a.x + a.width && b.y + b.height <= a.y + a.height;
}
function CGRectEqualToRect(a, b) {
    return a.x === b.x && a.y === b.y && a.width === b.width && a.height === b.height;
}
"#;

#[derive(Debug)]
pub struct CalcError(pub String);

impl std::fmt::Display for CalcError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.0)
    }
}

impl std::error::Error for CalcError {}

/// Where `action` puts a window. All rectangles are top-left based; they are mirrored into the
/// bottom-left based coordinates the scripts were written for and back.
///
/// Returns `Ok(None)` for actions without a calculation (undo, redo, arrange).
///
/// Why a new QuickJS context per call: it takes about a millisecond, and keeping no engine
/// around means the caller can hold `Engine` on any thread.
pub fn calculate(
    action: Action,
    window: Rect,
    source_visible_frame: Rect,
    destination_visible_frame: Rect,
) -> Result<Option<Rect>, CalcError> {
    let Some(js_name) = action.js_name() else {
        return Ok(None);
    };
    let to_json = |r: Rect| serde_json::to_string(&r.flipped()).expect("a rect always serializes");
    let call = format!(
        "JSON.stringify(__splitCalculations[{name}]({w}, {s}, {d}))",
        name = serde_json::to_string(js_name).expect("a name always serializes"),
        w = to_json(window),
        s = to_json(source_visible_frame),
        d = to_json(destination_visible_frame),
    );
    let runtime = Runtime::new().map_err(|e| CalcError(e.to_string()))?;
    let context = Context::full(&runtime).map_err(|e| CalcError(e.to_string()))?;
    let json: String = context.with(|ctx| -> Result<String, CalcError> {
        let describe = |error: rquickjs::Error, file: &str| {
            let thrown = ctx.catch();
            let detail = thrown
                .as_exception()
                .and_then(|e| e.message())
                .unwrap_or_else(|| error.to_string());
            CalcError(format!("{file}: {detail}"))
        };
        ctx.eval::<(), _>(PRELUDE).map_err(|e| describe(e, "prelude"))?;
        for (file, source) in SCRIPTS {
            ctx.eval::<(), _>(*source).map_err(|e| describe(e, file))?;
        }
        ctx.eval::<String, _>(call.as_str()).map_err(|e| describe(e, js_name))
    })?;
    let rect: Rect = serde_json::from_str(&json).map_err(|e| CalcError(format!("{js_name}: {e}: {json}")))?;
    Ok(Some(rect.flipped()))
}

#[cfg(test)]
mod tests {
    use super::*;

    const SCREEN: Rect = Rect::new(0.0, 0.0, 1920.0, 1040.0);

    fn calc(action: Action, window: Rect) -> Rect {
        calculate(action, window, SCREEN, SCREEN).unwrap().unwrap()
    }

    #[test]
    fn halves_cycle_through_two_thirds_and_one_third() {
        let half = calc(Action::MoveToLeftHalf, Rect::new(100.0, 100.0, 800.0, 600.0));
        assert_eq!(half, Rect::new(0.0, 0.0, 960.0, 1040.0));
        let two_thirds = calc(Action::MoveToLeftHalf, half);
        assert_eq!(two_thirds, Rect::new(0.0, 0.0, 1280.0, 1040.0));
        let one_third = calc(Action::MoveToLeftHalf, two_thirds);
        assert_eq!(one_third, Rect::new(0.0, 0.0, 640.0, 1040.0));
    }

    #[test]
    fn top_and_bottom_follow_a_downward_y_axis() {
        let top = calc(Action::MoveToTopHalf, Rect::new(100.0, 100.0, 800.0, 600.0));
        assert_eq!(top, Rect::new(0.0, 0.0, 1920.0, 520.0));
        let bottom = calc(Action::MoveToBottomHalf, Rect::new(100.0, 100.0, 800.0, 600.0));
        assert_eq!(bottom, Rect::new(0.0, 520.0, 1920.0, 520.0));
        let upper_right = calc(Action::MoveToUpperRight, Rect::new(100.0, 100.0, 800.0, 600.0));
        assert_eq!(upper_right, Rect::new(960.0, 0.0, 960.0, 520.0));
        let lower_left = calc(Action::MoveToLowerLeft, Rect::new(100.0, 100.0, 800.0, 600.0));
        assert_eq!(lower_left, Rect::new(0.0, 520.0, 960.0, 520.0));
    }

    #[test]
    fn center_and_fullscreen() {
        let centered = calc(Action::MoveToCenter, Rect::new(0.0, 0.0, 800.0, 600.0));
        assert_eq!(centered, Rect::new(560.0, 220.0, 800.0, 600.0));
        assert_eq!(calc(Action::MoveToFullscreen, Rect::new(0.0, 0.0, 800.0, 600.0)), SCREEN);
    }

    #[test]
    fn thirds_go_left_to_right_then_top_to_bottom() {
        let first = calc(Action::MoveToNextThird, Rect::new(100.0, 100.0, 800.0, 600.0));
        assert_eq!(first, Rect::new(0.0, 0.0, 640.0, 1040.0));
        let second = calc(Action::MoveToNextThird, first);
        assert_eq!(second, Rect::new(640.0, 0.0, 640.0, 1040.0));
        let third = calc(Action::MoveToNextThird, second);
        assert_eq!(third, Rect::new(1280.0, 0.0, 640.0, 1040.0));
        let top_row = calc(Action::MoveToNextThird, third);
        assert_eq!(top_row, Rect::new(0.0, 0.0, 1920.0, 346.0));
    }

    #[test]
    fn next_display_centers_a_window_that_fits() {
        let other = Rect::new(1920.0, 0.0, 1280.0, 1000.0);
        let moved = calculate(Action::MoveToNextDisplay, Rect::new(0.0, 0.0, 800.0, 600.0), SCREEN, other)
            .unwrap()
            .unwrap();
        assert_eq!(moved, Rect::new(2160.0, 200.0, 800.0, 600.0));
    }

    #[test]
    fn larger_grows_by_thirty_points() {
        let larger = calc(Action::MakeLarger, Rect::new(500.0, 200.0, 800.0, 600.0));
        assert_eq!(larger, Rect::new(485.0, 185.0, 830.0, 630.0));
    }

    #[test]
    fn undo_has_no_calculation() {
        assert!(calculate(Action::UndoLastMove, SCREEN, SCREEN, SCREEN).unwrap().is_none());
    }
}
