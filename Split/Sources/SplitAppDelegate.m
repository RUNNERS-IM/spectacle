#import "SplitAppDelegate.h"

// The App Store build (SPLIT_APP_STORE) is updated by the App Store and must not ship Sparkle.
#if !SPLIT_APP_STORE
#import <Sparkle/Sparkle.h>
#endif

#import "SplitAccessibilityElement.h"
#import "SplitAccessibilityGuideController.h"
#import "SplitDefaultShortcutHelpers.h"
#import "SplitLegacyPreferencesMigrator.h"
#import "SplitMigratingShortcutStorage.h"
#import "SplitPreferencesController.h"
#import "SplitScreenDetector.h"
#import "SplitShortcutJSONStorage.h"
#import "SplitShortcutManager.h"
#import "SplitShortcutTranslations.h"
#import "SplitShortcutUserDefaultsStorage.h"
#import "SplitUtilities.h"
#import "SplitWindowPositionCalculator.h"
#import "SplitWindowPositionManager.h"
#import "SplitWindowFeedback.h"

@implementation SplitAppDelegate
{
  NSDictionary<NSString *, NSMenuItem *> *_shortcutMenuItems;
  NSStatusItem *_statusItem;
  id<SplitShortcutStorage> _shortcutStorage;
  SplitShortcutManager *_shortcutManager;
  SplitWindowPositionManager *_windowPositionManager;
  SplitPreferencesController *_preferencesController;
  SplitWindowFeedback *_windowFeedback;
#if !SPLIT_APP_STORE
  SPUStandardUpdaterController *_updaterController;
#endif
  SplitAccessibilityGuideController *_accessibilityGuideController;
  NSTimer *_disableShortcutsForAnHourTimer;
  NSSet<NSString *> *_blacklistedApplications;
  NSMutableSet<NSString *> *_disabledApplications;
  BOOL _shortcutsAreDisabledForAnHour;
}

/// Unit tests launch the app as their host. Skip everything that talks to the user or to the
/// system (permission guide, System Settings, Sparkle, login item, alerts) so the test runner can
/// connect; on a fresh CI machine those otherwise block the launch.
static BOOL SplitIsRunningUnitTests(void)
{
  return NSProcessInfo.processInfo.environment[@"XCTestConfigurationFilePath"] != nil
      || NSClassFromString(@"XCTestCase") != nil;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
  if (SplitIsRunningUnitTests()) {
    return;
  }
  NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
  NSNotificationCenter *workspaceNotificationCenter = [NSWorkspace sharedWorkspace].notificationCenter;
  [notificationCenter addObserver:self
                         selector:@selector(enableStatusItem)
                             name:@"SplitStatusItemEnabledNotification"
                           object:nil];
  [notificationCenter addObserver:self
                         selector:@selector(disableStatusItem)
                             name:@"SplitStatusItemDisabledNotification"
                           object:nil];
  [notificationCenter addObserver:self
                         selector:@selector(updateShortcutMenuItems)
                             name:@"SplitShortcutChangedNotification"
                           object:nil];
  [notificationCenter addObserver:self
                         selector:@selector(updateShortcutMenuItems)
                             name:@"SplitRestoreDefaultShortcutsNotification"
                           object:nil];
  [notificationCenter addObserver:self
                         selector:@selector(menuDidSendAction:)
                             name:NSMenuDidSendActionNotification
                           object:nil];
  [notificationCenter addObserver:self
                         selector:@selector(inputSourceSelectionDidChange)
                             name:NSTextInputContextKeyboardSelectionDidChangeNotification
                           object:nil];
  [workspaceNotificationCenter addObserver:self
                                  selector:@selector(applicationDidActivate:)
                                      name:NSWorkspaceDidActivateApplicationNotification
                                    object:nil];
  [workspaceNotificationCenter addObserver:self
                                  selector:@selector(applicationDidDeactivate:)
                                      name:NSWorkspaceDidDeactivateApplicationNotification
                                    object:nil];
  [SplitUtilities registerDefaultsForBundle:[NSBundle mainBundle]];
  [SplitLegacyPreferencesMigrator migrateIfNeeded];
  _shortcutMenuItems = @{
                         @"MoveToCenter": _moveToCenterShortcutMenuItem,
                         @"MoveToFullscreen": _moveToFullscreenShortcutMenuItem,
                         @"MoveToLeftHalf": _moveToLeftShortcutMenuItem,
                         @"MoveToRightHalf": _moveToRightShortcutMenuItem,
                         @"MoveToTopHalf": _moveToTopShortcutMenuItem,
                         @"MoveToBottomHalf": _moveToBottomShortcutMenuItem,
                         @"MoveToUpperLeft": _moveToUpperLeftShortcutMenuItem,
                         @"MoveToLowerLeft": _moveToLowerLeftShortcutMenuItem,
                         @"MoveToUpperRight": _moveToUpperRightShortcutMenuItem,
                         @"MoveToLowerRight": _moveToLowerRightShortcutMenuItem,
                         @"MoveToNextDisplay": _moveToNextDisplayShortcutMenuItem,
                         @"MoveToPreviousDisplay": _moveToPreviousDisplayShortcutMenuItem,
                         @"MoveToNextThird": _moveToNextThirdShortcutMenuItem,
                         @"MoveToPreviousThird": _moveToPreviousThirdShortcutMenuItem,
                         @"MakeLarger": _makeLargerShortcutMenuItem,
                         @"MakeSmaller": _makeSmallerShortcutMenuItem,
                         @"UndoLastMove": _undoLastMoveShortcutMenuItem,
                         @"RedoLastMove": _redoLastMoveShortcutMenuItem,
                         };
  NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
  _blacklistedApplications = [NSSet setWithArray:[userDefaults objectForKey:@"BlacklistedApplications"]];
  _disabledApplications = [NSMutableSet setWithArray:[userDefaults objectForKey:@"DisabledApplications"]];
  _shortcutStorage = [[SplitMigratingShortcutStorage alloc] initWithShortcutStorage:[SplitShortcutUserDefaultsStorage new]
                                                                   migrationDestination:[SplitShortcutJSONStorage new]];
  _shortcutManager = [[SplitShortcutManager alloc] initWithShortcutStorage:_shortcutStorage];
  SplitWindowPositionCalculator *windowPositionCalculator = [[SplitWindowPositionCalculator alloc] initWithErrorHandler:^(NSString *errorMessage) {
    NSAlert *alert = [NSAlert new];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = @"Encountered an unexpected error";
    alert.informativeText = errorMessage;
    [alert runModal];
  }];
  _windowPositionManager = [[SplitWindowPositionManager alloc] initWithScreenDetector:[SplitScreenDetector new]
                                                                 windowPositionCalculator:windowPositionCalculator
                                                                          sharedWorkspace:[NSWorkspace sharedWorkspace]];
  _preferencesController = [[SplitPreferencesController alloc] initWithShortcutManager:_shortcutManager
                                                                     windowPositionManager:_windowPositionManager
                                                                           shortcutStorage:_shortcutStorage];
  _shortcutsAreDisabledForAnHour = NO;
  [self manageShortcuts];
  [self disableShortcutsIfFrontmostApplicationIsBlacklistedOrDisabled];
  BOOL automaticallyChecksForUpdates = [userDefaults boolForKey:@"AutomaticUpdateCheckEnabled"];
  BOOL statusItemEnabled = [userDefaults boolForKey:@"StatusItemEnabled"];
  if (statusItemEnabled) {
    [self enableStatusItem];
  }
#if SPLIT_APP_STORE
  (void)automaticallyChecksForUpdates;
  self.checkForUpdatesMenuItem.hidden = YES;
#else
  _updaterController = [[SPUStandardUpdaterController alloc] initWithStartingUpdater:YES
                                                                     updaterDelegate:nil
                                                                  userDriverDelegate:nil];
  _updaterController.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates;
#endif
  [self updateShortcutMenuItems];
  _windowFeedback = [SplitWindowFeedback new];
  [self decorateStatusMenu];
  // Ask after launch has finished; an alert run from inside applicationDidFinishLaunching
  // returned its first button straight away without the user touching it (macOS 26.1).
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [self offerToQuitLegacySplit];
  });
  if (![SplitAccessibilityGuideController isAccessibilityPermissionGranted]) {
    _accessibilityGuideController = [SplitAccessibilityGuideController new];
    [_accessibilityGuideController showGuide];
  }
}

- (void)offerToQuitLegacySplit
{
  NSArray<NSRunningApplication *> *legacyApplications = [SplitLegacyPreferencesMigrator runningLegacyApplications];
  if (legacyApplications.count == 0) {
    return;
  }
  NSBundle *bundle = NSBundle.mainBundle;
  NSAlert *alert = [NSAlert new];
  alert.alertStyle = NSAlertStyleWarning;
  alert.messageText = [bundle localizedStringForKey:@"LegacyRunningTitle" value:nil table:@"Migration"];
  alert.informativeText = [bundle localizedStringForKey:@"LegacyRunningBody" value:nil table:@"Migration"];
  // The safe choice is the default so a stray Return never quits the other app.
  [alert addButtonWithTitle:[bundle localizedStringForKey:@"LegacyRunningKeep" value:nil table:@"Migration"]];
  [alert addButtonWithTitle:[bundle localizedStringForKey:@"LegacyRunningQuit" value:nil table:@"Migration"]];
  [NSApp activateIgnoringOtherApps:YES];
  if ([alert runModal] == NSAlertSecondButtonReturn) {
    for (NSRunningApplication *application in legacyApplications) {
      [application terminate];
    }
  }
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)application hasVisibleWindows:(BOOL)visibleWindows
{
  [self showPreferencesWindow:self];

  return YES;
}

- (IBAction)checkForUpdates:(id)sender
{
#if !SPLIT_APP_STORE
  [_updaterController checkForUpdates:sender];
#endif
}

- (IBAction)showPreferencesWindow:(id)sender
{
  [_preferencesController showWindow:sender];
}

- (IBAction)moveFrontmostWindowToFullscreen:(id)sender
{
  [self performWindowAction:kSplitWindowActionFullscreen];
}

- (IBAction)moveFrontmostWindowToCenter:(id)sender
{
  [self performWindowAction:kSplitWindowActionCenter];
}

- (IBAction)moveFrontmostWindowToLeftHalf:(id)sender
{
  [self performWindowAction:kSplitWindowActionLeftHalf];
}

- (IBAction)moveFrontmostWindowToRightHalf:(id)sender
{
  [self performWindowAction:kSplitWindowActionRightHalf];
}

- (IBAction)moveFrontmostWindowToTopHalf:(id)sender
{
  [self performWindowAction:kSplitWindowActionTopHalf];
}

- (IBAction)moveFrontmostWindowToBottomHalf:(id)sender
{
  [self performWindowAction:kSplitWindowActionBottomHalf];
}

- (IBAction)moveFrontmostWindowToUpperLeft:(id)sender
{
  [self performWindowAction:kSplitWindowActionUpperLeft];
}

- (IBAction)moveFrontmostWindowToLowerLeft:(id)sender
{
  [self performWindowAction:kSplitWindowActionLowerLeft];
}

- (IBAction)moveFrontmostWindowToUpperRight:(id)sender
{
  [self performWindowAction:kSplitWindowActionUpperRight];
}

- (IBAction)moveFrontmostWindowToLowerRight:(id)sender
{
  [self performWindowAction:kSplitWindowActionLowerRight];
}

- (IBAction)moveFrontmostWindowToNextDisplay:(id)sender
{
  [self performWindowAction:kSplitWindowActionNextDisplay];
}

- (IBAction)moveFrontmostWindowToPreviousDisplay:(id)sender
{
  [self performWindowAction:kSplitWindowActionPreviousDisplay];
}

- (IBAction)moveFrontmostWindowToNextThird:(id)sender
{
  [self performWindowAction:kSplitWindowActionNextThird];
}

- (IBAction)moveFrontmostWindowToPreviousThird:(id)sender
{
  [self performWindowAction:kSplitWindowActionPreviousThird];
}

- (IBAction)makeFrontmostWindowLarger:(id)sender
{
  [self performWindowAction:kSplitWindowActionLarger];
}

- (IBAction)makeFrontmostWindowSmaller:(id)sender
{
  [self performWindowAction:kSplitWindowActionSmaller];
}

- (IBAction)undoLastWindowAction:(id)sender
{
  [_windowPositionManager undoLastWindowAction];
}

- (IBAction)redoLastWindowAction:(id)sender
{
  [_windowPositionManager redoLastWindowAction];
}

- (IBAction)disableOrEnableShortcutsForAnHour:(id)sender
{
  NSInteger newMenuItemState = NSControlStateValueMixed;
  if (_shortcutsAreDisabledForAnHour) {
    _shortcutsAreDisabledForAnHour = NO;
    [_disableShortcutsForAnHourTimer invalidate];
    [self enableShortcutsIfPermitted];
    newMenuItemState = NSControlStateValueOff;
  } else {
    _shortcutsAreDisabledForAnHour = YES;
    _disableShortcutsForAnHourTimer = [NSTimer scheduledTimerWithTimeInterval:3600
                                                                       target:self
                                                                     selector:@selector(disableOrEnableShortcutsForAnHour:)
                                                                     userInfo:nil
                                                                      repeats:NO];
    [_shortcutManager unregisterShortcuts];
    newMenuItemState = NSControlStateValueOn;
  }
  self.disableShortcutsForAnHourMenuItem.state = newMenuItemState;
}

- (IBAction)disableOrEnableShortcutsForApplication:(id)sender
{
  NSRunningApplication *frontmostApplication = [NSWorkspace sharedWorkspace].frontmostApplication;
  if ([_disabledApplications containsObject:frontmostApplication.bundleIdentifier]) {
    [_disabledApplications removeObject:frontmostApplication.bundleIdentifier];
    [self enableShortcutsIfPermitted];
    self.disableShortcutsForApplicationMenuItem.state = NSControlStateValueOff;
  } else {
    [_disabledApplications addObject:frontmostApplication.bundleIdentifier];
    [_shortcutManager unregisterShortcuts];
    self.disableShortcutsForApplicationMenuItem.state = NSControlStateValueOn;
  }
  [NSUserDefaults.standardUserDefaults setObject:_disabledApplications.allObjects forKey:@"DisabledApplications"];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)manageShortcuts
{
  SplitShortcutAction action = ^(SplitShortcut *shortcut) {
    [self performWindowAction:shortcut.windowAction];
  };
  NSArray<SplitShortcut *> *shortcuts = [_shortcutStorage loadShortcutsWithAction:action];
  if (shortcuts.count != 0) {
    [_shortcutManager manageShortcuts:shortcuts];
  } else {
    [_shortcutManager manageShortcuts:SplitDefaultShortcutsWithAction(action)];
  }
}

- (void)enableStatusItem
{
  _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
  NSImage *statusImage = [NSBundle.mainBundle imageForResource:@"Split Status Item"];
  [statusImage setTemplate:YES];
  _statusItem.button.image = statusImage;
  _statusItem.menu = _statusItemMenu;
  _statusItem.button.toolTip = [@"Split " stringByAppendingString:SplitUtilities.applicationVersion];
}

- (void)disableStatusItem
{
  [NSStatusBar.systemStatusBar removeStatusItem:_statusItem];
}

- (void)updateShortcutMenuItems
{
  for (NSString *shortcutName in _shortcutMenuItems.allKeys) {
    NSMenuItem *shortcutMenuItem = _shortcutMenuItems[shortcutName];
    SplitShortcut *shortcut = [_shortcutManager shortcutForShortcutName:shortcutName];
    if (shortcut) {
      shortcutMenuItem.keyEquivalent = [SplitTranslateKeyCode(shortcut.shortcutKeyCode) lowercaseString];
      shortcutMenuItem.keyEquivalentModifierMask = SplitConvertModifiersToCocoaIfNecessary(shortcut.shortcutModifiers);
    } else {
      shortcutMenuItem.keyEquivalent = @"";
      shortcutMenuItem.keyEquivalentModifierMask = 0;
    }
  }
}

- (void)enableShortcutsIfPermitted
{
  NSRunningApplication *frontmostApplication = [NSWorkspace sharedWorkspace].frontmostApplication;
  // Do not enable shortcuts if they should remain disabled for an hour.
  if (_shortcutsAreDisabledForAnHour) {
    return;
  }
  // Do not enable shortcuts if the application is blacklisted or disabled.
  if ([_blacklistedApplications containsObject:frontmostApplication.bundleIdentifier]
      || [_disabledApplications containsObject:frontmostApplication.bundleIdentifier]) {
    return;
  }
  [_shortcutManager registerShortcuts];
  [[NSNotificationCenter defaultCenter] postNotificationName:@"SplitShortcutChangedNotification" object:self];
}

- (void)disableShortcutsIfFrontmostApplicationIsBlacklistedOrDisabled
{
  NSRunningApplication *frontmostApplication = [NSWorkspace sharedWorkspace].frontmostApplication;
  // Do not disable shortcuts if the application is not blacklisted or disabled.
  if (![_blacklistedApplications containsObject:frontmostApplication.bundleIdentifier]
      && ![_disabledApplications containsObject:frontmostApplication.bundleIdentifier]) {
    return;
  }
  [_shortcutManager unregisterShortcuts];
}

- (void)applicationDidActivate:(NSNotification *)notification
{
  NSRunningApplication *application = notification.userInfo[NSWorkspaceApplicationKey];
  if ([_blacklistedApplications containsObject:application.bundleIdentifier]
      || [_disabledApplications containsObject:application.bundleIdentifier]) {
    [_shortcutManager unregisterShortcuts];
  }
}

- (void)applicationDidDeactivate:(NSNotification *)notification
{
  NSRunningApplication *application = notification.userInfo[NSWorkspaceApplicationKey];
  if ([_blacklistedApplications containsObject:application.bundleIdentifier]
      || [_disabledApplications containsObject:application.bundleIdentifier]) {
    [self enableShortcutsIfPermitted];
  }
}

#pragma mark - Window actions with feedback

/// Shortcut names (as used by the status menu and the shortcut storage) and their window actions.
static NSDictionary<NSString *, SplitWindowAction *> *SplitWindowActionsByShortcutName(void)
{
  static NSDictionary *actions;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    actions = @{
      @"MoveToCenter": kSplitWindowActionCenter,
      @"MoveToFullscreen": kSplitWindowActionFullscreen,
      @"MoveToLeftHalf": kSplitWindowActionLeftHalf,
      @"MoveToRightHalf": kSplitWindowActionRightHalf,
      @"MoveToTopHalf": kSplitWindowActionTopHalf,
      @"MoveToBottomHalf": kSplitWindowActionBottomHalf,
      @"MoveToUpperLeft": kSplitWindowActionUpperLeft,
      @"MoveToLowerLeft": kSplitWindowActionLowerLeft,
      @"MoveToUpperRight": kSplitWindowActionUpperRight,
      @"MoveToLowerRight": kSplitWindowActionLowerRight,
      @"MoveToNextDisplay": kSplitWindowActionNextDisplay,
      @"MoveToPreviousDisplay": kSplitWindowActionPreviousDisplay,
      @"MoveToNextThird": kSplitWindowActionNextThird,
      @"MoveToPreviousThird": kSplitWindowActionPreviousThird,
      @"MakeLarger": kSplitWindowActionLarger,
      @"MakeSmaller": kSplitWindowActionSmaller,
      @"UndoLastMove": kSplitWindowActionUndo,
      @"RedoLastMove": kSplitWindowActionRedo,
    };
  });
  return actions;
}

- (NSString *)shortcutNameForWindowAction:(SplitWindowAction *)action
{
  return [SplitWindowActionsByShortcutName() allKeysForObject:action].firstObject;
}

/// Every window action from the keyboard or the status menu goes through here so that the
/// glow and shortcut label appear the same way for both.
- (void)performWindowAction:(SplitWindowAction *)action
{
  // Without Accessibility access nothing can move; show the guide again instead of failing silently.
  if (![SplitAccessibilityGuideController isAccessibilityPermissionGranted]) {
    if (!_accessibilityGuideController.window.isVisible) {
      _accessibilityGuideController = [SplitAccessibilityGuideController new];
      [_accessibilityGuideController showGuide];
    }
    return;
  }
  SplitAccessibilityElement *element = [SplitAccessibilityElement frontmostWindowElement];
  CGRect target = [_windowPositionManager targetRectForFrontmostWindowElement:element action:action];
  [_windowPositionManager moveFrontmostWindowElement:element action:action];
  if (CGRectIsNull(target)) {
    return;
  }
  NSString *shortcutName = [self shortcutNameForWindowAction:action];
  NSString *title = _shortcutMenuItems[shortcutName].title ?: @"";
  NSString *keys = [_shortcutManager shortcutForShortcutName:shortcutName].displayString;
  [_windowFeedback showMoveFeedbackForRect:target title:title shortcut:keys];
}

- (void)decorateStatusMenu
{
  for (NSString *shortcutName in _shortcutMenuItems) {
    _shortcutMenuItems[shortcutName].image = SplitMenuImageForShortcutName(shortcutName);
  }
  for (NSMenuItem *item in _statusItemMenu.itemArray) {
    NSString *symbol = nil;
    if (item.action == @selector(showPreferencesWindow:)) {
      symbol = @"gearshape";
    } else if (item.submenu && item.submenu == self.disableShortcutsForAnHourMenuItem.menu) {
      symbol = @"pause.circle";
    }
    if (symbol && !item.image) {
      item.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil];
    }
  }
}

#pragma mark - NSMenuDelegate (preview)

- (void)menu:(NSMenu *)menu willHighlightItem:(NSMenuItem *)item
{
  NSString *shortcutName = [_shortcutMenuItems allKeysForObject:item].firstObject;
  SplitWindowAction *action = shortcutName ? SplitWindowActionsByShortcutName()[shortcutName] : nil;
  if (!action || SplitIsUndoWindowAction(action) || SplitIsRedoWindowAction(action)) {
    [_windowFeedback hidePreview];
    return;
  }
  CGRect target = [_windowPositionManager targetRectForFrontmostWindowElement:[SplitAccessibilityElement frontmostWindowElement]
                                                                       action:action];
  [_windowFeedback showPreviewForRect:target];
}

- (void)menuDidClose:(NSMenu *)menu
{
  [_windowFeedback hidePreview];
}

- (void)menuWillOpen:(NSMenu *)menu
{
  NSRunningApplication *frontmostApplication = [NSWorkspace sharedWorkspace].frontmostApplication;
  self.disableShortcutsForApplicationMenuItem.hidden = NO;
  if ([_blacklistedApplications containsObject:frontmostApplication.bundleIdentifier]) {
    self.disableShortcutsForApplicationMenuItem.hidden = YES;
  } else {
    self.disableShortcutsForApplicationMenuItem.title =
      [NSString stringWithFormat:NSLocalizedString(@"MenuItemTitleDisableShortcutsForApplication", @"The menu item title that displays the application to disable shortcuts for"), frontmostApplication.localizedName];
  }
  if ([_disabledApplications containsObject:frontmostApplication.bundleIdentifier]) {
    self.disableShortcutsForApplicationMenuItem.state = NSControlStateValueOn;
  } else {
    self.disableShortcutsForApplicationMenuItem.state = NSControlStateValueOff;
  }
}

- (void)menuDidSendAction:(NSNotification *)notification
{
  NSMenuItem *menuItem = notification.userInfo[@"MenuItem"];
  if (menuItem.tag == -1) {
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
  }
}

- (void)inputSourceSelectionDidChange
{
  [_preferencesController loadRegisteredShortcuts];
  [self updateShortcutMenuItems];
}

@end
