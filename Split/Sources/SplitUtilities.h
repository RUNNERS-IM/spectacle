#import <Cocoa/Cocoa.h>

/// A user-facing string from App.strings in the current language (English when missing).
NSString *SplitLocalized(NSString *key);

/// A Lucide icon from the asset catalog ("lucide-<name>"), as a template image of the given point size.
NSImage *SplitIcon(NSString *name, CGFloat size);

@interface SplitUtilities : NSObject

+ (NSString *)applicationVersion;

+ (void)registerDefaultsForBundle:(NSBundle *)bundle;

+ (void)displayRunningInBackgroundAlertWithCallback:(void (^)(BOOL, BOOL))callback;
+ (void)displayRestoreDefaultsAlertWithConfirmationCallback:(void (^)(void))callback;


@end
