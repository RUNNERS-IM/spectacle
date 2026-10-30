#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// The small "Pro" pill shown next to the name of a paid feature. Clicking it opens the
/// Split Pro sheet on the pill's window. Paid features stay open to everyone until buying
/// opens, so the pill only tells; it never locks anything.
NSButton *SplitProPill(void);

/// `title` followed by the pill, for menu items, where the pill can be seen but not clicked.
NSAttributedString *SplitTitleWithProPill(NSString *title, NSFont *font);

/// Shows what Split Pro adds and what it costs, as a sheet on `window`, or in a window of its
/// own when `window` is nil. Buying, signing in and restoring are not open yet.
void SplitShowProSheet(NSWindow *_Nullable window);

NS_ASSUME_NONNULL_END
