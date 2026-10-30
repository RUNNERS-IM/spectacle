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
#import "SplitWindowArranger.h"

@implementation SplitAppDelegate
{
  NSDictionary<NSString *, NSMenuItem *> *_shortcutMenuItems;
  NSStatusItem *_statusItem;
  NSTimer *_statusItemTimer;
  id<SplitShortcutStorage> _shortcutStorage;
  SplitShortcutManager *_shortcutManager;
  SplitWindowPositionManager *_windowPositionManager;
  SplitPreferencesController *_preferencesController;
  SplitWindowFeedback *_windowFeedback;
  SplitWindowArranger *_windowArranger;
  SplitDisplayChangeArranger *_displayChangeArranger;
  SplitShortcutSheet *_shortcutSheet;
  NSMenuItem *_arrangeWindowsMenuItem;
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
                         @"ArrangeWindows": [self insertArrangeWindowsMenuItem],
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
    alert.messageText = SplitLocalized(@"UnexpectedError");
    alert.informativeText = errorMessage;
    [alert runModal];
  }];
  _windowPositionManager = [[SplitWindowPositionManager alloc] initWithScreenDetector:[SplitScreenDetector new]
                                                                 windowPositionCalculator:windowPositionCalculator
                                                                          sharedWorkspace:[NSWorkspace sharedWorkspace]];
  _preferencesController = [[SplitPreferencesController alloc] initWithShortcutManager:_shortcutManager
                                                                     windowPositionManager:_windowPositionManager
                                                                           shortcutStorage:_shortcutStorage];
  __weak typeof(self) weakSelf = self;
  _preferencesController.windowActionHandler = ^(SplitWindowAction *action) {
    [weakSelf performWindowAction:action];
  };
  [notificationCenter addObserver:self
                         selector:@selector(automaticUpdateCheckChanged)
                             name:SplitAutomaticUpdateCheckChangedNotification
                           object:nil];
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
  _windowArranger = [SplitWindowArranger new];
  _displayChangeArranger = [[SplitDisplayChangeArranger alloc] initWithArranger:_windowArranger completion:^(NSUInteger movedCount, BOOL restored) {
    [weakSelf showDisplayChangeFeedbackForCount:movedCount restored:restored];
  }];
  [_displayChangeArranger start];
  SplitShortcutManager *shortcutManager = _shortcutManager;
  _shortcutSheet = [[SplitShortcutSheet alloc] initWithSections:SplitShortcutSections() keysForName:^NSString *(NSString *shortcutName) {
    return [shortcutManager shortcutForShortcutName:shortcutName].displayString;
  }];
  [_shortcutSheet startWatchingModifiers];
  [self insertShortcutSheetMenuItem];
  [self localizeStatusMenu];
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
  [self performWindowAction:kSplitWindowActionUndo];
}

- (IBAction)redoLastWindowAction:(id)sender
{
  [self performWindowAction:kSplitWindowActionRedo];
}

- (IBAction)arrangeWindows:(id)sender
{
  [self performWindowAction:kSplitWindowActionArrange];
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
    [_shortcutManager manageShortcuts:SplitShortcutsAddingNewDefaults(shortcuts, action)];
  } else {
    [_shortcutManager manageShortcuts:SplitDefaultShortcutsWithAction(action)];
  }
}

/// Shortcuts saved by an older version do not know about actions added since (auto-arrange in
/// 1.1). Add those with their default keys, unless the key is already taken.
static NSArray<SplitShortcut *> *SplitShortcutsAddingNewDefaults(NSArray<SplitShortcut *> *saved, SplitShortcutAction action)
{
  NSMutableArray<SplitShortcut *> *result = [saved mutableCopy];
  NSMutableSet<NSString *> *names = [NSMutableSet new];
  NSMutableSet<NSString *> *bindings = [NSMutableSet new];
  for (SplitShortcut *shortcut in saved) {
    [names addObject:shortcut.shortcutName];
    if (shortcut.shortcutKeyBinding) {
      [bindings addObject:shortcut.shortcutKeyBinding];
    }
  }
  for (SplitShortcut *shortcut in SplitDefaultShortcutsWithAction(action)) {
    if ([names containsObject:shortcut.shortcutName]) {
      continue;
    }
    if (shortcut.shortcutKeyBinding && [bindings containsObject:shortcut.shortcutKeyBinding]) {
      [result addObject:[[SplitShortcut alloc] initWithShortcutName:shortcut.shortcutName shortcutKeyBinding:nil shortcutAction:action]];
    } else {
      [result addObject:shortcut];
    }
  }
  return result;
}

- (void)automaticUpdateCheckChanged
{
#if !SPLIT_APP_STORE
  _updaterController.updater.automaticallyChecksForUpdates = [NSUserDefaults.standardUserDefaults boolForKey:@"AutomaticUpdateCheckEnabled"];
#endif
}

#pragma mark - Status item

/// The menu bar icon is a screen outline with a pane inside that slowly slides wider and narrower.
/// Drawn on a 24-unit grid, scaled to an 18pt template image so macOS tints it for light and dark menu bars.
static const NSTimeInterval SplitStatusItemCycle = 6.0;
static const NSTimeInterval SplitStatusItemFrameInterval = 1.0 / 15.0;

static NSImage *SplitStatusItemImage(CGFloat paneWidth)
{
  NSImage *image = [NSImage imageWithSize:NSMakeSize(18, 18) flipped:YES drawingHandler:^BOOL(NSRect rect) {
    NSAffineTransform *transform = [NSAffineTransform transform];
    [transform scaleBy:18.0 / 24.0];
    [transform concat];
    [NSColor.blackColor set];
    NSBezierPath *screen = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(2.5, 4.5, 19, 15) xRadius:3 yRadius:3];
    screen.lineWidth = 2;
    [screen stroke];
    [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(4.5, 6.5, paneWidth, 11) xRadius:1 yRadius:1] fill];
    return YES;
  }];
  [image setTemplate:YES];
  return image;
}

/// Pane width at a point in the cycle: 7 → 12 → 7 → 4 → 7, easing in and out between each stop.
static CGFloat SplitStatusItemPaneWidth(NSTimeInterval time)
{
  static const CGFloat stops[] = {7, 12, 7, 4, 7};
  NSTimeInterval progress = fmod(time, SplitStatusItemCycle) / SplitStatusItemCycle * 4;
  NSInteger segment = MIN((NSInteger)progress, 3);
  CGFloat t = progress - segment;
  CGFloat eased = (1 - cos(M_PI * t)) / 2;
  return stops[segment] + (stops[segment + 1] - stops[segment]) * eased;
}

- (void)enableStatusItem
{
  _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
  _statusItem.button.image = SplitStatusItemImage(SplitStatusItemPaneWidth(0));
  _statusItem.menu = _statusItemMenu;
  _statusItem.button.toolTip = [@"Split " stringByAppendingString:SplitUtilities.applicationVersion];
  NSTimeInterval start = NSDate.timeIntervalSinceReferenceDate;
  __weak NSStatusItem *statusItem = _statusItem;
  _statusItemTimer = [NSTimer timerWithTimeInterval:SplitStatusItemFrameInterval repeats:YES block:^(NSTimer *timer) {
    statusItem.button.image = SplitStatusItemImage(SplitStatusItemPaneWidth(NSDate.timeIntervalSinceReferenceDate - start));
  }];
  _statusItemTimer.tolerance = SplitStatusItemFrameInterval / 2;
  // Common modes keep the pane moving while the status menu is open.
  [NSRunLoop.mainRunLoop addTimer:_statusItemTimer forMode:NSRunLoopCommonModes];
}

- (void)disableStatusItem
{
  [_statusItemTimer invalidate];
  _statusItemTimer = nil;
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
      @"ArrangeWindows": kSplitWindowActionArrange,
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
  NSString *shortcutName = [self shortcutNameForWindowAction:action];
  NSString *title = SplitLocalized(shortcutName ?: @"");
  NSString *keys = [_shortcutManager shortcutForShortcutName:shortcutName].displayString;
  if (SplitIsArrangeWindowAction(action)) {
    NSArray<NSValue *> *rects = [_windowArranger arrangeWindows];
    if (rects.count == 0) {
      NSBeep();
      if (SplitWindowFeedback.moveFeedbackEnabled) {
        [_windowFeedback showLabel:SplitLocalized(@"NothingToArrange") shortcut:keys];
      }
      return;
    }
    title = [NSString localizedStringWithFormat:SplitLocalized(@"ArrangedCount"), (long)rects.count];
    [_windowFeedback showMoveFeedbackForRects:rects title:title shortcut:keys tip:[self nextTipForAction:action]];
    [_displayChangeArranger recordSoon];
    return;
  }
  // One undo after auto-arrange puts every window back, not just the frontmost one.
  if (SplitIsUndoWindowAction(action) && _windowArranger.canUndo) {
    [_windowArranger undoLastArrangement];
    if (SplitWindowFeedback.moveFeedbackEnabled) {
      [_windowFeedback showLabel:SplitLocalized(@"ArrangeUndone") shortcut:keys];
    }
    return;
  }
  [_windowArranger forgetLastArrangement];
  SplitAccessibilityElement *element = [SplitAccessibilityElement frontmostWindowElement];
  CGRect target = [_windowPositionManager targetRectForFrontmostWindowElement:element action:action];
  [_windowPositionManager moveFrontmostWindowElement:element action:action];
  if (CGRectIsNull(target)) {
    return;
  }
  [_windowFeedback showMoveFeedbackForRect:target title:title shortcut:keys tip:[self nextTipForAction:action]];
  [_displayChangeArranger recordSoon];
}

#pragma mark - Tips and monitor changes

/// Tips shown once each, one per move, while the label is on; the one that fits the action that
/// was just used comes first. Returns nil once every tip has been shown.
- (NSString *)nextTipForAction:(SplitWindowAction *)action
{
  if (!SplitWindowFeedback.moveFeedbackEnabled || !SplitWindowFeedback.moveFeedbackShowsShortcut) {
    return nil;
  }
  NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
  NSArray<NSString *> *shown = [defaults stringArrayForKey:@"ShownTips"] ?: @[];
  NSString *(^keys)(NSString *) = ^NSString *(NSString *name) {
    return [self->_shortcutManager shortcutForShortcutName:name].displayString ?: @"";
  };
  BOOL half = [@[kSplitWindowActionLeftHalf, kSplitWindowActionRightHalf, kSplitWindowActionTopHalf, kSplitWindowActionBottomHalf] containsObject:action];
  NSArray<NSArray *> *tips = @[
    @[@"TipCycle", @(half), @""],
    @[@"TipFullscreenAgain", @([action isEqualToString:kSplitWindowActionFullscreen]), @""],
    @[@"TipUndo", @NO, keys(@"UndoLastMove")],
    @[@"TipSheet", @NO, @""],
    @[@"TipArrange", @NO, keys(@"ArrangeWindows")],
  ];
  NSArray *chosen = nil;
  for (NSArray *tip in tips) {
    if (![shown containsObject:tip[0]] && [tip[1] boolValue]) {
      chosen = tip;
      break;
    }
  }
  for (NSArray *tip in tips) {
    // Tips tied to another action wait for that action.
    BOOL tiedToAction = [tip[0] isEqualToString:@"TipCycle"] || [tip[0] isEqualToString:@"TipFullscreenAgain"];
    if (!chosen && ![shown containsObject:tip[0]] && !tiedToAction) {
      chosen = tip;
    }
  }
  if (!chosen || ([chosen[0] isEqualToString:@"TipSheet"] && !SplitShortcutSheet.holdToShowEnabled)) {
    if (chosen) {
      [defaults setObject:[shown arrayByAddingObject:chosen[0]] forKey:@"ShownTips"];
    }
    return nil;
  }
  [defaults setObject:[shown arrayByAddingObject:chosen[0]] forKey:@"ShownTips"];
  NSString *text = SplitLocalized(chosen[0]);
  return [chosen[2] length] > 0 ? [NSString stringWithFormat:text, chosen[2]] : text;
}

- (void)showDisplayChangeFeedbackForCount:(NSUInteger)count restored:(BOOL)restored
{
  if (!SplitWindowFeedback.moveFeedbackEnabled || count == 0) {
    return;
  }
  NSString *format = SplitLocalized(restored ? @"DisplayRestored" : @"DisplayRearranged");
  NSString *undo = [_shortcutManager shortcutForShortcutName:@"UndoLastMove"].displayString ?: @"";
  [_windowFeedback showLabel:[NSString localizedStringWithFormat:format, (long)count]
                    shortcut:nil
                         tip:[NSString stringWithFormat:SplitLocalized(@"DisplayUndoTip"), undo]];
}

- (void)insertShortcutSheetMenuItem
{
  NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:SplitLocalized(@"ShowShortcutSheet")
                                                action:@selector(showShortcutSheet:)
                                         keyEquivalent:@""];
  item.target = self;
  NSInteger index = -1;
  for (NSMenuItem *candidate in _statusItemMenu.itemArray) {
    if (candidate.action == @selector(showPreferencesWindow:)) {
      index = [_statusItemMenu indexOfItem:candidate];
    }
  }
  [_statusItemMenu insertItem:item atIndex:index >= 0 ? index : _statusItemMenu.numberOfItems];
}

- (void)showShortcutSheet:(id)sender
{
  // The menu is still closing; show the card once it is gone.
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [self->_shortcutSheet show];
  });
}

/// The arrange item is new in 1.1 and not in the menu file; it goes right after Full Screen.
- (NSMenuItem *)insertArrangeWindowsMenuItem
{
  if (_arrangeWindowsMenuItem) {
    return _arrangeWindowsMenuItem;
  }
  _arrangeWindowsMenuItem = [[NSMenuItem alloc] initWithTitle:SplitLocalized(@"ArrangeWindows")
                                                       action:@selector(arrangeWindows:)
                                                keyEquivalent:@""];
  _arrangeWindowsMenuItem.target = self;
  NSInteger index = [_statusItemMenu indexOfItem:_moveToFullscreenShortcutMenuItem];
  [_statusItemMenu insertItem:_arrangeWindowsMenuItem atIndex:index >= 0 ? index + 1 : _statusItemMenu.numberOfItems];
  return _arrangeWindowsMenuItem;
}

/// Menu titles come from App.strings so every language Split ships is covered, not only the
/// few the original menu file was translated into.
- (void)localizeStatusMenu
{
  for (NSString *shortcutName in _shortcutMenuItems) {
    _shortcutMenuItems[shortcutName].title = SplitLocalized(shortcutName);
  }
  self.checkForUpdatesMenuItem.title = SplitLocalized(@"CheckForUpdates");
  self.disableShortcutsForAnHourMenuItem.title = SplitLocalized(@"DisableForAnHour");
  for (NSMenuItem *item in _statusItemMenu.itemArray) {
    if (item.submenu && item.submenu == self.disableShortcutsForAnHourMenuItem.menu) {
      item.title = SplitLocalized(@"Disable");
      item.submenu.title = item.title;
    } else if (item.action == @selector(showPreferencesWindow:)) {
      item.title = SplitLocalized(@"Settings");
    } else if (item.action == @selector(terminate:)) {
      item.title = SplitLocalized(@"QuitSplit");
    } else if (item.action == @selector(orderFrontStandardAboutPanel:)) {
      item.title = SplitLocalized(@"AboutSplit");
    }
  }
}

- (void)decorateStatusMenu
{
  for (NSString *shortcutName in _shortcutMenuItems) {
    _shortcutMenuItems[shortcutName].image = SplitMenuImageForShortcutName(shortcutName);
  }
  for (NSMenuItem *item in _statusItemMenu.itemArray) {
    NSString *icon = nil;
    if (item.action == @selector(showPreferencesWindow:)) {
      icon = @"settings";
    } else if (item.submenu && item.submenu == self.disableShortcutsForAnHourMenuItem.menu) {
      icon = @"circle-pause";
    }
    if (icon && !item.image) {
      item.image = SplitIcon(icon, 16);
    }
  }
}

#pragma mark - NSMenuDelegate (preview)

- (void)menu:(NSMenu *)menu willHighlightItem:(NSMenuItem *)item
{
  NSString *shortcutName = [_shortcutMenuItems allKeysForObject:item].firstObject;
  SplitWindowAction *action = shortcutName ? SplitWindowActionsByShortcutName()[shortcutName] : nil;
  if (action && SplitIsArrangeWindowAction(action)) {
    [_windowFeedback showPreviewForRects:[_windowArranger plannedRects]];
    return;
  }
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
      [NSString stringWithFormat:SplitLocalized(@"DisableForApplication"), frontmostApplication.localizedName];
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
