#import <Foundation/Foundation.h>

#import "SplitShortcut.h"

@protocol SplitShortcutStorage <NSObject>

- (NSArray<SplitShortcut *> *)loadShortcutsWithAction:(SplitShortcutAction)action;

- (void)storeShortcuts:(NSArray<SplitShortcut *> *)shortcuts;

@end
