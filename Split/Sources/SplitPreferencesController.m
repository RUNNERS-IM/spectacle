#import "SplitPreferencesController.h"

#import <QuartzCore/QuartzCore.h>

#import "SplitAccessibilityElement.h"
#import "SplitDefaultShortcutHelpers.h"
#import "SplitLoginItemHelper.h"
#import "SplitRegisteredShortcutValidator.h"
#import "SplitShortcut.h"
#import "SplitShortcutManager.h"
#import "SplitShortcutRecorder.h"
#import "SplitShortcutStorage.h"
#import "SplitShortcutValidation.h"
#import "SplitUtilities.h"
#import "SplitWindowPositionManager.h"

@implementation SplitPreferencesController
{
  SplitShortcutManager *_shortcutManager;
  SplitWindowPositionManager *_windowPositionManager;
  id<SplitShortcutStorage> _shortcutStorage;
  NSDictionary<NSString *, SplitShortcutRecorder *> *_shortcutRecorders;
}

- (instancetype)initWithShortcutManager:(SplitShortcutManager *)shortcutManager
                  windowPositionManager:(SplitWindowPositionManager *)windowPositionManager
                        shortcutStorage:(id<SplitShortcutStorage>)shortcutStorage
{
  if (self = [super initWithWindowNibName:@"SplitPreferencesWindow"]) {
    _shortcutManager = shortcutManager;
    _windowPositionManager = windowPositionManager;
    _shortcutStorage = shortcutStorage;
  }
  return self;
}

- (void)windowDidLoad
{
  NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
  NSInteger loginItemEnabledState = NSControlStateValueOff;
  BOOL isStatusItemEnabled = [NSUserDefaults.standardUserDefaults boolForKey:@"StatusItemEnabled"];
  _shortcutRecorders = @{
                         @"MoveToCenter": _moveToCenterShortcutRecorder,
                         @"MoveToFullscreen": _moveToFullscreenShortcutRecorder,
                         @"MoveToLeftHalf": _moveToLeftShortcutRecorder,
                         @"MoveToRightHalf": _moveToRightShortcutRecorder,
                         @"MoveToTopHalf": _moveToTopShortcutRecorder,
                         @"MoveToBottomHalf": _moveToBottomShortcutRecorder,
                         @"MoveToUpperLeft": _moveToUpperLeftShortcutRecorder,
                         @"MoveToLowerLeft": _moveToLowerLeftShortcutRecorder,
                         @"MoveToUpperRight": _moveToUpperRightShortcutRecorder,
                         @"MoveToLowerRight": _moveToLowerRightShortcutRecorder,
                         @"MoveToNextDisplay": _moveToNextDisplayShortcutRecorder,
                         @"MoveToPreviousDisplay": _moveToPreviousDisplayShortcutRecorder,
                         @"MoveToNextThird": _moveToNextThirdShortcutRecorder,
                         @"MoveToPreviousThird": _moveToPreviousThirdShortcutRecorder,
                         @"MakeLarger": _makeLargerShortcutRecorder,
                         @"MakeSmaller": _makeSmallerShortcutRecorder,
                         @"UndoLastMove": _undoLastMoveShortcutRecorder,
                         @"RedoLastMove": _redoLastMoveShortcutRecorder,
                         };
  [self loadRegisteredShortcuts];
  [notificationCenter addObserver:self
                         selector:@selector(loadRegisteredShortcuts)
                             name:@"SplitShortcutChangedNotification"
                           object:nil];
  [notificationCenter addObserver:self
                         selector:@selector(loadRegisteredShortcuts)
                             name:@"SplitRestoreDefaultShortcutsNotification"
                           object:nil];
  if ([SplitLoginItemHelper isLoginItemEnabledForBundle:NSBundle.mainBundle]) {
    loginItemEnabledState = NSControlStateValueOn;
  }
  self.loginItemEnabled.state = loginItemEnabledState;
  [self.statusItemEnabled selectItemWithTag:isStatusItemEnabled ? 0 : 1];
  self.window.title = [@"Split " stringByAppendingString:SplitUtilities.applicationVersion];
  self.footerView.wantsLayer = YES;
}

- (void)shortcutRecorder:(SplitShortcutRecorder *)shortcutRecorder
   didReceiveNewShortcut:(SplitShortcut *)shortcut
{
  [_shortcutManager updateShortcut:[shortcut copyWithShortcutAction:^(SplitShortcut *shortcut) {
    [self->_windowPositionManager moveFrontmostWindowElement:[SplitAccessibilityElement frontmostWindowElement]
                                                      action:shortcut.windowAction];
  }]];
  [[NSNotificationCenter defaultCenter] postNotificationName:@"SplitShortcutChangedNotification" object:self];
}

- (void)shortcutRecorder:(SplitShortcutRecorder *)shortcutRecorder
didClearExistingShortcut:(SplitShortcut *)shortcut
{
  [_shortcutManager clearShortcut:shortcut];
  [[NSNotificationCenter defaultCenter] postNotificationName:@"SplitShortcutChangedNotification" object:self];
}

- (void)loadRegisteredShortcuts
{
  for (NSString *shortcutName in _shortcutRecorders.allKeys) {
    SplitShortcutRecorder *shortcutRecorder = _shortcutRecorders[shortcutName];
    SplitShortcut *shortcut = [_shortcutManager shortcutForShortcutName:shortcutName];
    shortcutRecorder.shortcutName = shortcutName;
    shortcutRecorder.shortcut = shortcut;
    shortcutRecorder.delegate = self;
    shortcutRecorder.shortcutValidation =
    [[SplitShortcutValidation alloc] initWithShortcutManager:_shortcutManager
                                                      validators:@[
                                                                   [SplitRegisteredShortcutValidator new],
                                                                   ]];
  }
}

- (IBAction)swapFooterViews:(id)sender
{
  CATransition *transition = [CATransition animation];
  NSView *currentFooterView = self.footerView.subviews[0];
  NSView *nextFooterView = nil;
  transition.type = kCATransitionPush;
  if (currentFooterView == self.shortcutModifierLegendFooterView) {
    nextFooterView = self.optionsFooterView;
    transition.subtype = kCATransitionFromRight;
  } else {
    nextFooterView = self.shortcutModifierLegendFooterView;
    transition.subtype = kCATransitionFromLeft;
  }
  self.footerView.animations = @{@"subviews": transition};
  [self.footerView.animator replaceSubview:currentFooterView
                                      with:nextFooterView];
}

- (IBAction)restoreDefaults:(id)sender
{
  [SplitUtilities displayRestoreDefaultsAlertWithConfirmationCallback:^() {
    NSArray<SplitShortcut *> *shortcuts = SplitDefaultShortcutsWithAction(^(SplitShortcut *shortcut) {
      [self->_windowPositionManager moveFrontmostWindowElement:[SplitAccessibilityElement frontmostWindowElement]
                                                        action:shortcut.windowAction];
    });
    [self->_shortcutManager updateShortcuts:shortcuts];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SplitRestoreDefaultShortcutsNotification"
                                                        object:self];
  }];
}

- (IBAction)toggleLoginItem:(id)sender
{
  NSBundle *applicationBundle = NSBundle.mainBundle;
  if (self.loginItemEnabled.state == NSControlStateValueOn) {
    [SplitLoginItemHelper enableLoginItemForBundle:applicationBundle];
  } else {
    [SplitLoginItemHelper disableLoginItemForBundle:applicationBundle];
  }
}

- (IBAction)toggleStatusItem:(id)sender
{
  NSString *notificationName = @"SplitStatusItemEnabledNotification";
  BOOL isStatusItemEnabled = YES;
  __block BOOL statusItemStateChanged = YES;
  NSUserDefaults *userDefaults = NSUserDefaults.standardUserDefaults;
  if ([userDefaults boolForKey:@"StatusItemEnabled"] == ([[sender selectedItem] tag] == 0)) {
    return;
  }
  if ([sender selectedItem].tag != 0) {
    notificationName = @"SplitStatusItemDisabledNotification";
    isStatusItemEnabled = NO;
    if (![userDefaults boolForKey:@"BackgroundAlertSuppressed"]) {
      [SplitUtilities displayRunningInBackgroundAlertWithCallback:^(BOOL isConfirmed, BOOL isSuppressed) {
        if (!isConfirmed) {
          statusItemStateChanged = NO;
          [sender selectItemWithTag:0];
        }
        [userDefaults setBool:isSuppressed forKey:@"BackgroundAlertSuppressed"];
      }];
    }
  }
  if (statusItemStateChanged) {
    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:self];
    [userDefaults setBool:isStatusItemEnabled forKey:@"StatusItemEnabled"];
  }
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
