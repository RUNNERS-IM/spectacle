#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// On-screen feedback for window actions:
/// - a translucent blue preview of where a window will go (while hovering a menu item),
/// - a short glow on the destination after a window moves,
/// - a small heads-up label with the shortcut that was used.
/// Rectangles are in the top-left based coordinates the Accessibility API uses.
@interface SplitWindowFeedback : NSObject

typedef NS_ENUM(NSInteger, SplitMoveFeedbackStyle) {
  SplitMoveFeedbackStyleOff = 0,
  SplitMoveFeedbackStyleSubtle = 1,
  SplitMoveFeedbackStyleStrong = 2,
};

typedef NS_ENUM(NSInteger, SplitMoveFeedbackDuration) {
  SplitMoveFeedbackDurationShort = 0,
  SplitMoveFeedbackDurationNormal = 1,
  SplitMoveFeedbackDurationLong = 2,
};

typedef NS_ENUM(NSInteger, SplitMoveFeedbackLabelPosition) {
  SplitMoveFeedbackLabelPositionBottom = 0,
  SplitMoveFeedbackLabelPositionTop = 1,
  SplitMoveFeedbackLabelPositionCenter = 2,
};

/// User default keys for the Effects tab.
extern NSString *const SplitMoveFeedbackStyleKey;
extern NSString *const SplitMoveFeedbackColorKey;
extern NSString *const SplitMoveFeedbackShowsShortcutKey;
extern NSString *const SplitMoveFeedbackDurationKey;
extern NSString *const SplitMoveFeedbackLabelPositionKey;

/// Color names for SplitMoveFeedbackColorKey, in the order the Effects tab shows them.
/// "accent" follows the accent color chosen in System Settings.
NSArray<NSString *> *SplitMoveFeedbackColorNames(void);
NSColor *SplitMoveFeedbackColorForName(NSString *name);

/// How the glow and the shortcut label look after a move. Users who turned the old
/// "MoveFeedbackEnabled" switch off start at Off; everyone else starts at Subtle.
@property (class, nonatomic, readonly) SplitMoveFeedbackStyle moveFeedbackStyle;
@property (class, nonatomic, readonly) BOOL moveFeedbackEnabled;
@property (class, nonatomic, readonly) NSString *moveFeedbackColorName;
@property (class, nonatomic, readonly) BOOL moveFeedbackShowsShortcut;
@property (class, nonatomic, readonly) SplitMoveFeedbackDuration moveFeedbackDuration;
@property (class, nonatomic, readonly) SplitMoveFeedbackLabelPosition moveFeedbackLabelPosition;

- (void)showPreviewForRect:(CGRect)rect;
- (void)hidePreview;

- (void)showMoveFeedbackForRect:(CGRect)rect title:(NSString *)title shortcut:(nullable NSString *)shortcut;

/// Several outlines at once, for auto-arrange.
- (void)showPreviewForRects:(NSArray<NSValue *> *)rects;
- (void)showMoveFeedbackForRects:(NSArray<NSValue *> *)rects title:(NSString *)title shortcut:(nullable NSString *)shortcut;

/// Only the heads-up label, for example when there was nothing to arrange.
- (void)showLabel:(NSString *)title shortcut:(nullable NSString *)shortcut;

/// The label with a smaller second line under it (a tip for new users, or how to undo).
- (void)showLabel:(NSString *)title shortcut:(nullable NSString *)shortcut tip:(nullable NSString *)tip;
- (void)showMoveFeedbackForRect:(CGRect)rect title:(NSString *)title shortcut:(nullable NSString *)shortcut tip:(nullable NSString *)tip;
- (void)showMoveFeedbackForRects:(NSArray<NSValue *> *)rects title:(NSString *)title shortcut:(nullable NSString *)shortcut tip:(nullable NSString *)tip;

@end

/// A see-through card that lists every Split shortcut with its picture, shown while ⌥⌘ is
/// held for a second (user default "ShortcutSheetEnabled", on when never set) or from the menu.
@interface SplitShortcutSheet : NSObject

@property (class, nonatomic, readonly) BOOL holdToShowEnabled;

/// `sections` as SplitShortcutSections() returns them; `keysForName` gives the current
/// shortcut text for a shortcut name.
- (instancetype)initWithSections:(NSArray<NSArray *> *)sections
                     keysForName:(NSString *_Nullable (^)(NSString *shortcutName))keysForName;

/// Starts watching for ⌥⌘ being held.
- (void)startWatchingModifiers;

/// Shows the card until the next key press or click.
- (void)show;
- (void)hide;

@end

/// Small template images that show where a window goes, for the status menu.
NSImage *_Nullable SplitMenuImageForShortcutName(NSString *shortcutName);

/// A template image of a small screen with `fractions` (0…1, top-left based) filled in.
NSImage *SplitMiniScreenImage(NSArray<NSValue *> *fractions, NSSize size);

NS_ASSUME_NONNULL_END
