#import <Carbon/Carbon.h>

#import "SplitMacros.h"

@class SplitShortcut;

@interface SplitShortcutHolder : NSObject

@property (nonatomic, readonly, assign) EventHotKeyID shortcutID;
@property (nonatomic, readonly, strong) SplitShortcut *shortcut;
@property (nonatomic, readonly, assign) EventHotKeyRef shortcutRef;

- (instancetype)initWithShortcutID:(EventHotKeyID)shortcutID;

- (instancetype)initWithShortcutID:(EventHotKeyID)shortcutID
                          shortcut:(SplitShortcut *)shortcut;

- (instancetype)initWithShortcutID:(EventHotKeyID)shortcutID
                          shortcut:(SplitShortcut *)shortcut
                       shortcutRef:(EventHotKeyRef)shortcutRef NS_DESIGNATED_INITIALIZER;

SPECTACLE_INIT_AND_NEW_UNAVAILABLE

- (instancetype)copyWithShortcut:(SplitShortcut *)shortcut;
- (instancetype)copyWithShortcutRef:(EventHotKeyRef)shortcutRef;
- (instancetype)copyWithClearedShortcut;

@end
