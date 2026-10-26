#import <Cocoa/Cocoa.h>

/// A user-facing string from App.strings in the current language (English when missing).
NSString *SplitLocalized(NSString *key);

@interface SplitUtilities : NSObject

+ (NSString *)applicationVersion;

+ (void)registerDefaultsForBundle:(NSBundle *)bundle;

+ (void)displayRunningInBackgroundAlertWithCallback:(void (^)(BOOL, BOOL))callback;
+ (void)displayRestoreDefaultsAlertWithConfirmationCallback:(void (^)(void))callback;


@end
