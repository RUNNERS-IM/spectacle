#import <Foundation/Foundation.h>

#import "SplitMacros.h"

@class SplitShortcut;
@class SplitShortcutManager;

@protocol SplitShortcutValidator;

@interface SplitShortcutValidation : NSObject

- (instancetype)initWithShortcutManager:(SplitShortcutManager *)shortcutManager
                             validators:(NSArray<id<SplitShortcutValidator>> *)validators NS_DESIGNATED_INITIALIZER;

SPECTACLE_INIT_AND_NEW_UNAVAILABLE

- (BOOL)isShortcutValid:(SplitShortcut *)shortcut error:(NSError **)error;

@end
