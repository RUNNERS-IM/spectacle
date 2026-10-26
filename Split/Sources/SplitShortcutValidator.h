#import <Foundation/Foundation.h>

@class SplitShortcut;
@class SplitShortcutManager;

@protocol SplitShortcutValidator <NSObject>

- (BOOL)isShortcutValid:(SplitShortcut *)shortcut shortcutManager:(SplitShortcutManager *)shortcutManager;

@end
