#import <Foundation/Foundation.h>

@class SplitShortcut;

NSNumber *SplitConvertShortcutKeyBindingToKeyCode(NSString *keyBinding);
NSNumber *SplitConvertShortcutKeyBindingToModifiers(NSString *keyBinding);

NSString *SplitConvertShortcutToKeyBinding(SplitShortcut *shortcut);
