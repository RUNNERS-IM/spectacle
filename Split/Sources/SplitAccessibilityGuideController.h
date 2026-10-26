#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// Shows a step-by-step window that explains how to grant Split the Accessibility
/// permission, opens System Settings on the right pane, and closes itself as soon as the
/// permission is granted.
@interface SplitAccessibilityGuideController : NSWindowController

@property (nonatomic, copy, nullable) void (^permissionGrantedHandler)(void);

+ (BOOL)isAccessibilityPermissionGranted;

/// Opens System Settings on Privacy & Security > Accessibility.
+ (void)openAccessibilitySettings;

- (instancetype)init;

/// Shows the guide and opens System Settings next to it.
- (void)showGuide;

@end

NS_ASSUME_NONNULL_END
