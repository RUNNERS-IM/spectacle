#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// On-screen feedback for window actions:
/// - a translucent blue preview of where a window will go (while hovering a menu item),
/// - a short glow on the destination after a window moves,
/// - a small heads-up label with the shortcut that was used.
/// Rectangles are in the top-left based coordinates the Accessibility API uses.
@interface SplitWindowFeedback : NSObject

/// Whether the glow and the shortcut label are shown after a move (user default "MoveFeedbackEnabled").
@property (class, nonatomic, readonly) BOOL moveFeedbackEnabled;

- (void)showPreviewForRect:(CGRect)rect;
- (void)hidePreview;

- (void)showMoveFeedbackForRect:(CGRect)rect title:(NSString *)title shortcut:(nullable NSString *)shortcut;

@end

/// Small template images that show where a window goes, for the status menu.
NSImage *_Nullable SplitMenuImageForShortcutName(NSString *shortcutName);

NS_ASSUME_NONNULL_END
