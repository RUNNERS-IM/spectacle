#import <Cocoa/Cocoa.h>

@class SplitWindowArranger;

NS_ASSUME_NONNULL_BEGIN

/// The shapes offered as chips at the top of the status menu. Each one arranges the windows of
/// one monitor at once, the most recently used window going into the first cell.
typedef NSString *SplitLayoutShape NS_TYPED_ENUM;
extern SplitLayoutShape const SplitLayoutShapeHalves;    // two halves side by side
extern SplitLayoutShape const SplitLayoutShapeThirds;    // three columns
extern SplitLayoutShape const SplitLayoutShapeMainAndTwo; // 60% left, two stacked on the right
extern SplitLayoutShape const SplitLayoutShapeGrid;      // 2 × 2
extern SplitLayoutShape const SplitLayoutShapeSingle;    // the front window fills the screen

/// Every shape, in the order the menu shows them.
NSArray<SplitLayoutShape> *SplitLayoutShapes(void);

/// Cells of `shape` as fractions of a screen (0…1, top-left based), first cell first.
NSArray<NSValue *> *SplitLayoutShapeFractions(SplitLayoutShape shape);

/// A window remembered in a saved layout.
@interface SplitSavedWindow : NSObject
@property (nonatomic, copy) NSString *bundleIdentifier;
@property (nonatomic, copy) NSString *title;
/// Which window of that app it was, front to back, for when titles changed.
@property (nonatomic, assign) NSUInteger indexInApp;
/// Top-left based, like the Accessibility API.
@property (nonatomic, assign) CGRect rect;
@property (nonatomic, copy) NSString *displayID;
@end

/// A named arrangement of every visible window, saved with the monitors it was made on.
@interface SplitSavedLayout : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSArray<NSString *> *displayIDs;
/// Put back by itself when exactly these monitors are connected again.
@property (nonatomic, assign) BOOL restoresForDisplays;
@property (nonatomic, copy) NSArray<SplitSavedWindow *> *windows;
@end

/// Saved layouts, kept in "Application Support/Split/Layouts.json".
@interface SplitLayoutStore : NSObject

@property (class, nonatomic, readonly) SplitLayoutStore *sharedStore;

@property (nonatomic, readonly) NSArray<SplitSavedLayout *> *layouts;

/// Records where every visible window is now. With `restoresForDisplays`, any other layout
/// that restores for the same monitors stops doing so, so only one answers each combination.
- (SplitSavedLayout *)saveCurrentLayoutNamed:(NSString *)name restoresForDisplays:(BOOL)restoresForDisplays;

- (void)removeLayout:(SplitSavedLayout *)layout;

/// The layout to put back by itself when exactly `displayIDs` are connected, or nil.
- (nullable SplitSavedLayout *)layoutRestoringForDisplays:(NSSet<NSString *> *)displayIDs;

@end

/// Moves the visible windows of `screen` into `shape`. One undo puts them back.
/// Returns how many windows moved.
NSUInteger SplitApplyLayoutShape(SplitLayoutShape shape, NSScreen *screen, SplitWindowArranger *arranger);

/// Moves every window that is open now back to where `layout` had it, matching by app and
/// title (then by order within the app). Windows on monitors that are not connected stay.
/// One undo puts them back. Returns how many windows moved.
NSUInteger SplitRestoreLayout(SplitSavedLayout *layout, SplitWindowArranger *arranger);

NS_ASSUME_NONNULL_END
