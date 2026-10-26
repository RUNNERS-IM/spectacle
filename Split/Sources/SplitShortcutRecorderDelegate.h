#import <Foundation/Foundation.h>

@class SplitShortcut;
@class SplitShortcutRecorder;

@protocol SplitShortcutRecorderDelegate <NSObject>

- (void)shortcutRecorder:(SplitShortcutRecorder *)shortcutRecorder
   didReceiveNewShortcut:(SplitShortcut *)shortcut;

- (void)shortcutRecorder:(SplitShortcutRecorder *)shortcutRecorder
didClearExistingShortcut:(SplitShortcut *)shortcut;

@end
