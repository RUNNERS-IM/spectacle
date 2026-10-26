#import <Cocoa/Cocoa.h>

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

@end

NS_ASSUME_NONNULL_END
