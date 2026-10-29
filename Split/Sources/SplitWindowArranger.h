#import <Cocoa/Cocoa.h>

@class SplitAccessibilityElement;

NS_ASSUME_NONNULL_BEGIN

/// The most windows auto-arrange places. Windows after this stay where they are.
extern const NSUInteger kSplitArrangeMaximumWindowCount;

/// Where each window goes when `count` windows are arranged inside `visibleFrame`.
/// Both use top-left based coordinates (the ones the Accessibility API uses). The first rect is
/// for the most recently used window. Returns at most kSplitArrangeMaximumWindowCount rects.
///
/// 1 full · 2 halves · 3 left half + right column of two · 4 a 2×2 grid ·
/// 5 a 2×2 grid with the front window floating in the middle at 60% ·
/// 6 a 3×2 grid · 7 to 9 a 3×2 grid with the rest stacked in the middle at 60%, 30 pt apart.
NSArray<NSValue *> *SplitArrangeLayoutRects(NSUInteger count, CGRect visibleFrame);

/// User default for the space between windows, in points (0, 8, 16 or 24; 8 when never set).
extern NSString *const SplitWindowGapKey;
CGFloat SplitWindowGap(void);

/// Shrinks `rect` by half of `gap` on every side that faces another window, so two neighbours
/// end up `gap` apart. Sides on the edge of `visibleFrame` stay on the edge. Works in either
/// coordinate system as long as both rects use the same one.
CGRect SplitRectWithGap(CGRect rect, CGRect visibleFrame, CGFloat gap);

/// A window found on screen, with its Accessibility element and where it was (top-left based).
@interface SplitArrangedWindow : NSObject
@property (nonatomic, strong) SplitAccessibilityElement *element;
@property (nonatomic, assign) CGRect originalRect;
@end

/// Ordinary windows on the current desktop, front to back. With `screen` nil, windows on every
/// screen are returned in one front-to-back list.
NSArray<SplitArrangedWindow *> *SplitVisibleWindows(NSScreen *_Nullable screen);

/// A screen's visible frame (without menu bar and Dock) in top-left based coordinates.
CGRect SplitTopLeftVisibleFrame(NSScreen *screen);

/// Arranges the visible windows on the screen that holds the frontmost window
/// ("auto-arrange", ⌥⌘A by default) and remembers where they were so one undo puts all of
/// them back.
@interface SplitWindowArranger : NSObject

/// Moves the windows. Returns the rectangles they were moved to (top-left based), or an empty
/// array when there was nothing to arrange.
- (NSArray<NSValue *> *)arrangeWindows;

/// Where the windows would go, without moving anything (for the menu preview).
- (NSArray<NSValue *> *)plannedRects;

/// Whether the last arrangement can still be undone.
@property (nonatomic, readonly) BOOL canUndo;

/// Puts every window from the last arrangement back. Returns NO when there is nothing to undo.
- (BOOL)undoLastArrangement;

/// Forgets the last arrangement, for example after another window action.
- (void)forgetLastArrangement;

/// Moves each window to the rect at the same index and remembers the old places, so one undo
/// puts all of them back (used when monitors change).
- (void)moveWindows:(NSArray<SplitArrangedWindow *> *)windows toRects:(NSArray<NSValue *> *)rects;

@end

/// Keeps a record of which monitor and where each visible window is, and when monitors are
/// plugged in or out (user default "RearrangeOnDisplayChange", on when never set):
/// - windows from a monitor that went away move to the monitors left, which are re-arranged,
/// - windows that used to be on a monitor that came back go back to their old place,
/// - a monitor never seen before gets a share of the windows by screen area, the most recently
///   used windows going to the main monitor, and every monitor is re-arranged.
/// Only windows on the current desktop are touched. One undo puts everything back.
@interface SplitDisplayChangeArranger : NSObject

@property (class, nonatomic, readonly) BOOL enabled;

/// `completion` gets how many windows moved and whether they went back to remembered places.
- (instancetype)initWithArranger:(SplitWindowArranger *)arranger
                      completion:(void (^)(NSUInteger movedCount, BOOL restored))completion;

- (void)start;

/// Records the windows now, for example right after Split moved one.
- (void)recordSoon;

@end

NS_ASSUME_NONNULL_END
