#import "SplitShortcutHolder.h"

#import "SplitShortcut.h"

@implementation SplitShortcutHolder

- (instancetype)initWithShortcutID:(EventHotKeyID)shortcutID
{
  return [self initWithShortcutID:shortcutID shortcut:nil shortcutRef:nil];
}

- (instancetype)initWithShortcutID:(EventHotKeyID)shortcutID
                          shortcut:(SplitShortcut *)shortcut
{
  return [self initWithShortcutID:shortcutID shortcut:shortcut shortcutRef:nil];
}

- (instancetype)initWithShortcutID:(EventHotKeyID)shortcutID
                          shortcut:(SplitShortcut *)shortcut
                       shortcutRef:(EventHotKeyRef)shortcutRef
{
  if (self = [super init]) {
    _shortcutID = shortcutID;
    _shortcut = shortcut;
    _shortcutRef = shortcutRef;
  }
  return self;
}

- (instancetype)copyWithShortcut:(SplitShortcut *)shortcut
{
  return [[SplitShortcutHolder alloc] initWithShortcutID:_shortcutID
                                                    shortcut:shortcut
                                                 shortcutRef:_shortcutRef];
}

- (instancetype)copyWithShortcutRef:(EventHotKeyRef)shortcutRef
{
  return [[SplitShortcutHolder alloc] initWithShortcutID:_shortcutID
                                                    shortcut:_shortcut
                                                 shortcutRef:shortcutRef];
}

- (instancetype)copyWithClearedShortcut
{
  SplitShortcut *clearedShortcut = [[SplitShortcut alloc] initWithShortcutName:_shortcut.shortcutName
                                                                       shortcutKeyCode:-1
                                                                     shortcutModifiers:0];
  return [[SplitShortcutHolder alloc] initWithShortcutID:_shortcutID
                                                    shortcut:clearedShortcut
                                                 shortcutRef:nil];
}

@end
