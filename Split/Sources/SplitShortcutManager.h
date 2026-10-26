#import <Foundation/Foundation.h>

#import "SplitMacros.h"

@class SplitShortcut;

@protocol SplitShortcutStorage;

@interface SplitShortcutManager : NSObject

- (instancetype)initWithShortcutStorage:(id<SplitShortcutStorage>)shortcutStorage NS_DESIGNATED_INITIALIZER;

SPECTACLE_INIT_AND_NEW_UNAVAILABLE

- (void)manageShortcuts:(NSArray<SplitShortcut *> *)shortcuts;

- (void)updateShortcut:(SplitShortcut *)shortcut;
- (void)updateShortcuts:(NSArray<SplitShortcut *> *)shortcuts;

- (void)clearShortcut:(SplitShortcut *)shortcut;

- (NSArray<SplitShortcut *> *)shortcuts;
- (SplitShortcut *)shortcutForShortcutName:(NSString *)shortcutName;

- (BOOL)doesShortcutExist:(SplitShortcut *)shortcut;

- (void)registerShortcuts;
- (void)unregisterShortcuts;

@end
