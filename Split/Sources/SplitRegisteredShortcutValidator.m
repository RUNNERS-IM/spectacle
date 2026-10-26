#import "SplitRegisteredShortcutValidator.h"

#import "SplitShortcutManager.h"

@implementation SplitRegisteredShortcutValidator

- (BOOL)isShortcutValid:(SplitShortcut *)shortcut shortcutManager:(SplitShortcutManager *)shortcutManager
{
  return ![shortcutManager doesShortcutExist:shortcut];
}

@end
