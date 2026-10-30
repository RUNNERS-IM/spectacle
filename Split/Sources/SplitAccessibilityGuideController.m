#import "SplitAccessibilityGuideController.h"

#import <ApplicationServices/ApplicationServices.h>

static NSString *const kGuideTable = @"AccessibilityGuide";
static const NSTimeInterval kPermissionPollInterval = 1.0;
static const NSTimeInterval kCloseDelayAfterGrant = 1.2;
static const NSTimeInterval kOpenSettingsDelay = 0.6;
static const CGFloat kContentWidth = 340.0;

static NSString *GuideString(NSString *key)
{
  return [NSBundle.mainBundle localizedStringForKey:key value:nil table:kGuideTable];
}

static NSImage *AppIconImage(void)
{
  return NSApp.applicationIconImage;
}

static NSTextField *WrappingLabel(NSString *string, CGFloat width)
{
  NSTextField *label = [NSTextField wrappingLabelWithString:string];
  label.lineBreakStrategy = NSLineBreakStrategyHangulWordPriority;
  label.preferredMaxLayoutWidth = width;
  [label setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
  return label;
}

@interface SplitAccessibilityGuideController ()

@property (nonatomic, strong) NSTimer *permissionTimer;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSView *statusDot;
@property (nonatomic, assign) BOOL granted;

@end

/// The light or dark screenshot, picked each time it is drawn so it follows the system appearance.
static NSImage *SettingsShotMatchingAppearance(void)
{
  NSImage *light = [NSBundle.mainBundle imageForResource:@"GuideSettings"];
  NSImage *dark = [NSBundle.mainBundle imageForResource:@"GuideSettingsDark"] ?: light;
  if (!light) {
    return nil;
  }
  return [NSImage imageWithSize:light.size flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
    NSAppearanceName match = [NSAppearance.currentDrawingAppearance
        bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
    [([match isEqualToString:NSAppearanceNameDarkAqua] ? dark : light) drawInRect:dstRect];
    return YES;
  }];
}

@implementation SplitAccessibilityGuideController

+ (BOOL)isAccessibilityPermissionGranted
{
  return AXIsProcessTrusted();
}

/// A fresh install is not listed under Accessibility until it touches the Accessibility API.
/// Asking with kAXTrustedCheckOptionPrompt would list it too, but also shows the macOS alert on
/// top of this guide. A read-only query on the Dock lists Split silently (macOS 26.1).
+ (void)registerInAccessibilityList
{
#if SPLIT_APP_STORE
  // Inside the App Sandbox the silent query below does not list the app (macOS 26.1), so the
  // App Store build asks macOS directly. This also shows the system's own permission alert.
  AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)@{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES});
#else
  NSRunningApplication *dock = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.dock"].firstObject;
  if (!dock) {
    return;
  }
  AXUIElementRef element = AXUIElementCreateApplication(dock.processIdentifier);
  CFTypeRef value = NULL;
  AXUIElementCopyAttributeValue(element, kAXChildrenAttribute, &value);
  if (value) {
    CFRelease(value);
  }
  CFRelease(element);
#endif
}

+ (void)openAccessibilitySettings
{
  NSURL *accessibilityURL = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"];
  NSURL *privacyURL = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security"];
  BOOL settingsRunning = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.systempreferences"].count > 0;
  if (!settingsRunning) {
    [NSWorkspace.sharedWorkspace openURL:accessibilityURL];
    return;
  }
  // While System Settings is already open, opening the Accessibility URL again often lands on
  // the parent Privacy & Security page (seen on macOS 26.1). Going through the parent page
  // first and then to Accessibility lands on the right pane reliably.
  [NSWorkspace.sharedWorkspace openURL:privacyURL];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [NSWorkspace.sharedWorkspace openURL:accessibilityURL];
  });
}

- (instancetype)init
{
  NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, kContentWidth + 56.0, 400.0)
                                                 styleMask:(NSWindowStyleMaskTitled |
                                                            NSWindowStyleMaskClosable |
                                                            NSWindowStyleMaskFullSizeContentView)
                                                   backing:NSBackingStoreBuffered
                                                     defer:YES];
  window.titlebarAppearsTransparent = YES;
  window.titleVisibility = NSWindowTitleHidden;
  window.movableByWindowBackground = YES;
  window.releasedWhenClosed = NO;
  // Stay above System Settings so the steps remain visible while the user flips the switch.
  window.level = NSFloatingWindowLevel;
  window.title = GuideString(@"WindowTitle");
  self = [super initWithWindow:window];
  if (self) {
    [self buildContent];
  }
  return self;
}

- (void)dealloc
{
  [_permissionTimer invalidate];
}

#pragma mark - Showing

- (void)showGuide
{
  self.granted = NO;
  [SplitAccessibilityGuideController registerInAccessibilityList];
  [self.window.contentView layoutSubtreeIfNeeded];
  [self.window setContentSize:self.window.contentView.fittingSize];
  [self.window center];
  NSRect frame = self.window.frame;
  NSRect visible = (self.window.screen ?: NSScreen.mainScreen).visibleFrame;
  // Sit on the left third of the screen; System Settings usually opens near the centre.
  frame.origin.x = NSMinX(visible) + MAX(24.0, (NSWidth(visible) / 3.0 - NSWidth(frame)) / 2.0);
  [self.window setFrame:frame display:NO];
  [NSApp activateIgnoringOtherApps:YES];
  [self.window makeKeyAndOrderFront:self];
  [self startTimers];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kOpenSettingsDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    if (!self.granted) {
      [SplitAccessibilityGuideController openAccessibilitySettings];
    }
  });
}

- (void)startTimers
{
  [self.permissionTimer invalidate];
  __weak typeof(self) weakSelf = self;
  self.permissionTimer = [NSTimer timerWithTimeInterval:kPermissionPollInterval repeats:YES block:^(NSTimer *timer) {
    [weakSelf checkPermission];
  }];
  [NSRunLoop.mainRunLoop addTimer:self.permissionTimer forMode:NSRunLoopCommonModes];
}

- (void)checkPermission
{
  BOOL trusted = [SplitAccessibilityGuideController isAccessibilityPermissionGranted];
  if (self.granted || !trusted) {
    return;
  }
  self.granted = YES;
  [self.permissionTimer invalidate];
  self.statusDot.layer.backgroundColor = NSColor.systemGreenColor.CGColor;
  self.statusLabel.stringValue = GuideString(@"StatusGranted");
  [NSApp activateIgnoringOtherApps:YES];
  [self.window orderFrontRegardless];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kCloseDelayAfterGrant * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [self.window close];
    if (self.permissionGrantedHandler) {
      self.permissionGrantedHandler();
    }
  });
}

#pragma mark - Actions

- (void)openSettings:(id)sender
{
  [SplitAccessibilityGuideController openAccessibilitySettings];
}

/// macOS sometimes keeps the switch on for an older copy of Split (after an update or a
/// reinstall), so the running copy still has no access. Removing Split from the list and
/// adding it again fixes that.
- (void)resetPermission:(id)sender
{
  NSTask *task = [NSTask new];
  task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/tccutil"];
  task.arguments = @[@"reset", @"Accessibility", NSBundle.mainBundle.bundleIdentifier ?: @"im.runners.Split"];
  task.terminationHandler = ^(NSTask *finished) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [SplitAccessibilityGuideController registerInAccessibilityList];
      [SplitAccessibilityGuideController openAccessibilitySettings];
    });
  };
  [task launchAndReturnError:nil];
}

- (void)later:(id)sender
{
  [self.window orderOut:self];
}

#pragma mark - Layout

- (void)buildContent
{
  NSVisualEffectView *background = [NSVisualEffectView new];
  background.material = NSVisualEffectMaterialWindowBackground;
  background.blendingMode = NSVisualEffectBlendingModeBehindWindow;
  background.state = NSVisualEffectStateFollowsWindowActiveState;
  self.window.contentView = background;

  NSImageView *icon = [NSImageView imageViewWithImage:AppIconImage()];
  icon.imageScaling = NSImageScaleProportionallyUpOrDown;
  [icon.widthAnchor constraintEqualToConstant:64.0].active = YES;
  [icon.heightAnchor constraintEqualToConstant:64.0].active = YES;

  NSTextField *title = WrappingLabel(GuideString(@"Title"), kContentWidth);
  title.font = [NSFont systemFontOfSize:16.0 weight:NSFontWeightBold];
  title.alignment = NSTextAlignmentCenter;

  NSTextField *description = WrappingLabel(GuideString(@"Description"), kContentWidth);
  description.font = [NSFont systemFontOfSize:13.0];
  description.textColor = NSColor.secondaryLabelColor;
  description.alignment = NSTextAlignmentCenter;

  // A real screenshot of the Accessibility list (only the header and the Split row), so people
  // can see exactly which switch to turn on. English and Korean images, light and dark; others use English.
  NSMutableArray<NSView *> *rows = [NSMutableArray arrayWithObjects:icon, title, description, nil];
  NSImage *settingsShot = SettingsShotMatchingAppearance();
  if (settingsShot) {
    NSImageView *shotView = [NSImageView imageViewWithImage:settingsShot];
    shotView.imageScaling = NSImageScaleProportionallyUpOrDown;
    CGFloat ratio = settingsShot.size.height / MAX(settingsShot.size.width, 1.0);
    [shotView.widthAnchor constraintEqualToConstant:kContentWidth].active = YES;
    [shotView.heightAnchor constraintEqualToConstant:round(kContentWidth * ratio)].active = YES;
    [rows addObject:shotView];
  }

  NSButton *laterButton = [NSButton buttonWithTitle:GuideString(@"ButtonLater") target:self action:@selector(later:)];
  laterButton.controlSize = NSControlSizeLarge;
  NSButton *openButton = [NSButton buttonWithTitle:GuideString(@"ButtonOpenSettings") target:self action:@selector(openSettings:)];
  openButton.controlSize = NSControlSizeLarge;
  openButton.keyEquivalent = @"\r";
  openButton.bezelColor = NSColor.controlAccentColor;
  NSStackView *buttons = [NSStackView stackViewWithViews:@[laterButton, openButton]];
  buttons.spacing = 10.0;
  [rows addObject:buttons];

  self.statusDot = [NSView new];
  self.statusDot.wantsLayer = YES;
  self.statusDot.layer.cornerRadius = 4.0;
  self.statusDot.layer.backgroundColor = NSColor.systemOrangeColor.CGColor;
  [self.statusDot.widthAnchor constraintEqualToConstant:8.0].active = YES;
  [self.statusDot.heightAnchor constraintEqualToConstant:8.0].active = YES;
  self.statusLabel = [NSTextField labelWithString:GuideString(@"StatusWaiting")];
  self.statusLabel.font = [NSFont systemFontOfSize:11.5];
  self.statusLabel.textColor = NSColor.secondaryLabelColor;
  NSMutableArray<NSView *> *statusViews = [NSMutableArray arrayWithObjects:self.statusDot, self.statusLabel, nil];
#if !SPLIT_APP_STORE
  // The sandboxed App Store build cannot run tccutil, so only the direct build offers this.
  NSButton *resetButton = [NSButton buttonWithTitle:GuideString(@"ButtonReset") target:self action:@selector(resetPermission:)];
  resetButton.bordered = NO;
  resetButton.font = [NSFont systemFontOfSize:11.5];
  resetButton.contentTintColor = NSColor.linkColor;
  NSTextField *separator = [NSTextField labelWithString:@"·"];
  separator.textColor = NSColor.tertiaryLabelColor;
  [statusViews addObjectsFromArray:@[separator, resetButton]];
#endif
  NSStackView *status = [NSStackView stackViewWithViews:statusViews];
  status.spacing = 6.0;
  [rows addObject:status];

  NSStackView *stack = [NSStackView stackViewWithViews:rows];
  stack.orientation = NSUserInterfaceLayoutOrientationVertical;
  stack.alignment = NSLayoutAttributeCenterX;
  stack.spacing = 16.0;
  [stack setCustomSpacing:6.0 afterView:title];
  [stack setCustomSpacing:12.0 afterView:icon];
  stack.translatesAutoresizingMaskIntoConstraints = NO;
  [background addSubview:stack];

  [NSLayoutConstraint activateConstraints:@[
    [stack.topAnchor constraintEqualToAnchor:background.topAnchor constant:36.0],
    [stack.bottomAnchor constraintEqualToAnchor:background.bottomAnchor constant:-20.0],
    [stack.leadingAnchor constraintEqualToAnchor:background.leadingAnchor constant:28.0],
    [stack.trailingAnchor constraintEqualToAnchor:background.trailingAnchor constant:-28.0],
    [stack.widthAnchor constraintEqualToConstant:kContentWidth],
    [title.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
    [description.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
  ]];
}

@end
