#import "SplitDefaultShortcutHelpers.h"

#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>

static NSArray<SplitShortcut *> *builtinDefaultShortcuts(void);

NSArray<SplitShortcut *> *SplitDefaultShortcutsWithAction(SplitShortcutAction action)
{
  NSMutableArray<SplitShortcut *> *defaultShortcuts = [NSMutableArray new];
  for (SplitShortcut *defaultShortcut in builtinDefaultShortcuts()) {
    [defaultShortcuts addObject:[defaultShortcut copyWithShortcutAction:action]];
  }
  return defaultShortcuts;
}

static NSArray<SplitShortcut *> *builtinDefaultShortcuts(void)
{
  return @[
           [[SplitShortcut alloc] initWithShortcutName:@"MoveToCenter"          shortcutKeyBinding:@"alt+cmd+c"],
           [[SplitShortcut alloc] initWithShortcutName:@"MoveToFullscreen"      shortcutKeyBinding:@"alt+cmd+f"],
           [[SplitShortcut alloc] initWithShortcutName:@"MoveToLeftHalf"        shortcutKeyBinding:@"alt+cmd+left"],
           [[SplitShortcut alloc] initWithShortcutName:@"MoveToRightHalf"       shortcutKeyBinding:@"alt+cmd+right"],
           [[SplitShortcut alloc] initWithShortcutName:@"MoveToTopHalf"         shortcutKeyBinding:@"alt+cmd+up"],
           [[SplitShortcut alloc] initWithShortcutName:@"MoveToBottomHalf"      shortcutKeyBinding:@"alt+cmd+down"],
           [[SplitShortcut alloc] initWithShortcutName:@"MoveToUpperLeft"       shortcutKeyBinding:@"ctrl+cmd+left"],
           [[SplitShortcut alloc] initWithShortcutName:@"MoveToLowerLeft"       shortcutKeyBinding:@"ctrl+shift+cmd+left"],
           [[SplitShortcut alloc] initWithShortcutName:@"MoveToUpperRight"      shortcutKeyBinding:@"ctrl+cmd+right"],
           [[SplitShortcut alloc] initWithShortcutName:@"MoveToLowerRight"      shortcutKeyBinding:@"ctrl+shift+cmd+right"],
           [[SplitShortcut alloc] initWithShortcutName:@"MoveToNextDisplay"     shortcutKeyBinding:@"ctrl+alt+cmd+right"],
           [[SplitShortcut alloc] initWithShortcutName:@"MoveToPreviousDisplay" shortcutKeyBinding:@"ctrl+alt+cmd+left"],
           [[SplitShortcut alloc] initWithShortcutName:@"MoveToNextThird"       shortcutKeyBinding:@"ctrl+alt+right"],
           [[SplitShortcut alloc] initWithShortcutName:@"MoveToPreviousThird"   shortcutKeyBinding:@"ctrl+alt+left"],
           [[SplitShortcut alloc] initWithShortcutName:@"MakeLarger"            shortcutKeyBinding:@"ctrl+alt+shift+right"],
           [[SplitShortcut alloc] initWithShortcutName:@"MakeSmaller"           shortcutKeyBinding:@"ctrl+alt+shift+left"],
           [[SplitShortcut alloc] initWithShortcutName:@"UndoLastMove"          shortcutKeyBinding:@"alt+cmd+z"],
           [[SplitShortcut alloc] initWithShortcutName:@"RedoLastMove"          shortcutKeyBinding:@"alt+shift+cmd+z"],
           [[SplitShortcut alloc] initWithShortcutName:@"ArrangeWindows"        shortcutKeyBinding:@"alt+cmd+a"],
           ];
}
