#import <Cocoa/Cocoa.h>

@class SplitWindowArranger;

NS_ASSUME_NONNULL_BEGIN

/// The "Layouts" section at the top of the status menu, laid out like the Display module in
/// Control Center: the monitors to choose from, shape chips that arrange the chosen monitor at
/// once, layouts saved earlier, and "Save Current Layout…".
@interface SplitLayoutMenu : NSObject

/// `moved` runs after windows were moved, with how many moved.
- (instancetype)initWithArranger:(SplitWindowArranger *)arranger moved:(void (^)(NSUInteger count))moved;

/// Adds the section to the top of `menu`.
- (void)installInMenu:(NSMenu *)menu;

/// Rebuilds the monitor list and the saved layouts; call when the menu is about to open.
- (void)refresh;

@end

NS_ASSUME_NONNULL_END
