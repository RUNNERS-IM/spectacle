#import "SplitAccessibilityGuideController.h"

#import <ApplicationServices/ApplicationServices.h>
#import <QuartzCore/QuartzCore.h>

static NSString *const kGuideTable = @"AccessibilityGuide";
static const NSTimeInterval kPermissionPollInterval = 1.0;
static const NSTimeInterval kCloseDelayAfterGrant = 1.2;
static const NSTimeInterval kOpenSettingsDelay = 0.6;
static const CGFloat kContentWidth = 400.0;

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

/// A filled circle with a centred number or check mark, used for the step badges.
@interface SplitStepBadgeView : NSView
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) NSColor *fillColor;
@end

@implementation SplitStepBadgeView

- (NSSize)intrinsicContentSize
{
  return NSMakeSize(22.0, 22.0);
}

- (void)setText:(NSString *)text
{
  _text = [text copy];
  self.needsDisplay = YES;
}

- (void)setFillColor:(NSColor *)fillColor
{
  _fillColor = fillColor;
  self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect
{
  [self.fillColor setFill];
  [[NSBezierPath bezierPathWithOvalInRect:self.bounds] fill];
  NSDictionary *attributes = @{
    NSFontAttributeName: [NSFont systemFontOfSize:11.5 weight:NSFontWeightBold],
    NSForegroundColorAttributeName: NSColor.whiteColor,
  };
  NSSize size = [self.text sizeWithAttributes:attributes];
  NSPoint origin = NSMakePoint(NSMidX(self.bounds) - size.width / 2.0, NSMidY(self.bounds) - size.height / 2.0);
  [self.text drawAtPoint:origin withAttributes:attributes];
}

@end


/// Shows the real Accessibility permission state: red and off until access is granted, then
/// green and on. It is not clickable; macOS only lets the user change it in System Settings.
@interface SplitPermissionToggleView : NSView
@property (nonatomic, assign) BOOL on;
@end

@implementation SplitPermissionToggleView
{
  CALayer *_knob;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame:frameRect];
  if (self) {
    self.wantsLayer = YES;
    self.layer.cornerRadius = 11.0;
    _knob = [CALayer layer];
    _knob.backgroundColor = NSColor.whiteColor.CGColor;
    _knob.cornerRadius = 9.0;
    _knob.shadowOpacity = 0.3;
    _knob.shadowRadius = 1.5;
    _knob.shadowOffset = CGSizeMake(0, -1);
    [self.layer addSublayer:_knob];
    [self applyState:NO];
  }
  return self;
}

- (NSSize)intrinsicContentSize
{
  return NSMakeSize(42.0, 22.0);
}

- (void)layout
{
  [super layout];
  [self applyState:NO];
}

- (void)setOn:(BOOL)on
{
  if (_on == on) {
    return;
  }
  _on = on;
  [self applyState:YES];
}

- (void)applyState:(BOOL)animated
{
  [CATransaction begin];
  [CATransaction setDisableActions:!animated];
  [CATransaction setAnimationDuration:0.25];
  self.layer.backgroundColor = (_on ? NSColor.systemGreenColor : NSColor.systemRedColor).CGColor;
  CGFloat inset = 2.0, size = NSHeight(self.bounds) - inset * 2.0;
  CGFloat x = _on ? NSWidth(self.bounds) - inset - size : inset;
  _knob.frame = CGRectMake(x, inset, size, size);
  _knob.cornerRadius = size / 2.0;
  [CATransaction commit];
}

@end

@interface SplitAccessibilityGuideController ()

@property (nonatomic, strong) NSTimer *permissionTimer;
@property (nonatomic, strong) SplitPermissionToggleView *demoSwitch;
@property (nonatomic, strong) NSTextField *toggleLabel;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSView *statusDot;
@property (nonatomic, strong) SplitStepBadgeView *lastStepBadge;
@property (nonatomic, assign) BOOL granted;

@end

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
  NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, kContentWidth + 64.0, 520.0)
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
  [self updateToggle:[SplitAccessibilityGuideController isAccessibilityPermissionGranted]];
}

- (void)updateToggle:(BOOL)granted
{
  self.demoSwitch.on = granted;
  self.toggleLabel.stringValue = GuideString(granted ? @"ToggleOn" : @"ToggleOff");
  self.toggleLabel.textColor = granted ? NSColor.systemGreenColor : NSColor.systemRedColor;
}

- (void)checkPermission
{
  BOOL trusted = [SplitAccessibilityGuideController isAccessibilityPermissionGranted];
  [self updateToggle:trusted];
  if (self.granted || !trusted) {
    return;
  }
  self.granted = YES;
  [self.permissionTimer invalidate];
  self.lastStepBadge.text = @"✓";
  self.lastStepBadge.fillColor = NSColor.systemGreenColor;
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
  [icon.widthAnchor constraintEqualToConstant:84.0].active = YES;
  [icon.heightAnchor constraintEqualToConstant:84.0].active = YES;

  NSTextField *title = WrappingLabel(GuideString(@"Title"), kContentWidth);
  title.font = [NSFont systemFontOfSize:17.0 weight:NSFontWeightBold];
  title.alignment = NSTextAlignmentCenter;

  NSTextField *description = WrappingLabel(GuideString(@"Description"), kContentWidth);
  description.font = [NSFont systemFontOfSize:13.0];
  description.textColor = NSColor.secondaryLabelColor;
  description.alignment = NSTextAlignmentCenter;

  NSStackView *steps = [NSStackView stackViewWithViews:@[
    [self stepRowWithNumber:@"1" text:GuideString(@"Step1") badge:nil],
    [self stepRowWithNumber:@"2" text:GuideString(@"Step2") badge:nil],
    [self stepRowWithNumber:@"3" text:GuideString(@"Step3") badge:&_lastStepBadge],
  ]];
  steps.orientation = NSUserInterfaceLayoutOrientationVertical;
  steps.alignment = NSLayoutAttributeLeading;
  steps.spacing = 10.0;

  NSView *settingsRow = [self settingsRowMock];

  // A real screenshot of the Accessibility list (only the header and the Split row), so people
  // can see exactly which switch to turn on. English and Korean images; others use English.
  NSImage *settingsShot = [NSBundle.mainBundle imageForResource:@"GuideSettings"];
  NSView *screenshot = nil;
  if (settingsShot) {
    NSImageView *shotView = [NSImageView imageViewWithImage:settingsShot];
    shotView.imageScaling = NSImageScaleProportionallyUpOrDown;
    shotView.translatesAutoresizingMaskIntoConstraints = NO;
    CGFloat ratio = settingsShot.size.height / MAX(settingsShot.size.width, 1.0);
    [shotView.widthAnchor constraintEqualToConstant:kContentWidth].active = YES;
    [shotView.heightAnchor constraintEqualToConstant:round(kContentWidth * ratio)].active = YES;
    NSTextField *shotCaption = WrappingLabel(GuideString(@"ScreenshotCaption"), kContentWidth);
    shotCaption.font = [NSFont systemFontOfSize:11.0];
    shotCaption.textColor = NSColor.secondaryLabelColor;
    shotCaption.alignment = NSTextAlignmentCenter;
    NSStackView *shotStack = [NSStackView stackViewWithViews:@[shotView, shotCaption]];
    shotStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    shotStack.spacing = 6.0;
    screenshot = shotStack;
  }

  NSButton *laterButton = [NSButton buttonWithTitle:GuideString(@"ButtonLater") target:self action:@selector(later:)];
  laterButton.controlSize = NSControlSizeLarge;
  NSButton *openButton = [NSButton buttonWithTitle:GuideString(@"ButtonOpenSettings") target:self action:@selector(openSettings:)];
  openButton.controlSize = NSControlSizeLarge;
  openButton.keyEquivalent = @"\r";
  openButton.bezelColor = NSColor.controlAccentColor;
  NSStackView *buttons = [NSStackView stackViewWithViews:@[laterButton, openButton]];
  buttons.spacing = 10.0;

  self.statusDot = [NSView new];
  self.statusDot.wantsLayer = YES;
  self.statusDot.layer.cornerRadius = 4.0;
  self.statusDot.layer.backgroundColor = NSColor.systemOrangeColor.CGColor;
  [self.statusDot.widthAnchor constraintEqualToConstant:8.0].active = YES;
  [self.statusDot.heightAnchor constraintEqualToConstant:8.0].active = YES;
  self.statusLabel = [NSTextField labelWithString:GuideString(@"StatusWaiting")];
  self.statusLabel.font = [NSFont systemFontOfSize:11.5];
  self.statusLabel.textColor = NSColor.secondaryLabelColor;
  NSStackView *status = [NSStackView stackViewWithViews:@[self.statusDot, self.statusLabel]];
  status.spacing = 6.0;

  NSMutableArray<NSView *> *rows = [NSMutableArray arrayWithObjects:icon, title, description, steps, nil];
  if (screenshot) {
    [rows addObject:screenshot];
  }
  [rows addObjectsFromArray:@[settingsRow, buttons, status]];
  NSStackView *stack = [NSStackView stackViewWithViews:rows];
  stack.orientation = NSUserInterfaceLayoutOrientationVertical;
  stack.alignment = NSLayoutAttributeCenterX;
  stack.spacing = 14.0;
  [stack setCustomSpacing:8.0 afterView:title];
  [stack setCustomSpacing:20.0 afterView:description];
  [stack setCustomSpacing:18.0 afterView:steps];
  if (screenshot) {
    [stack setCustomSpacing:16.0 afterView:screenshot];
  }
  [stack setCustomSpacing:20.0 afterView:settingsRow];
  stack.translatesAutoresizingMaskIntoConstraints = NO;
  [background addSubview:stack];

  [NSLayoutConstraint activateConstraints:@[
    [stack.topAnchor constraintEqualToAnchor:background.topAnchor constant:40.0],
    [stack.bottomAnchor constraintEqualToAnchor:background.bottomAnchor constant:-24.0],
    [stack.leadingAnchor constraintEqualToAnchor:background.leadingAnchor constant:32.0],
    [stack.trailingAnchor constraintEqualToAnchor:background.trailingAnchor constant:-32.0],
    [stack.widthAnchor constraintEqualToConstant:kContentWidth],
    [title.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
    [description.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
    [steps.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
    [settingsRow.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
  ]];
}

- (NSView *)stepRowWithNumber:(NSString *)number text:(NSString *)text badge:(SplitStepBadgeView * __strong *)badgeOut
{
  SplitStepBadgeView *badge = [SplitStepBadgeView new];
  badge.text = number;
  badge.fillColor = NSColor.controlAccentColor;
  [badge setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
  if (badgeOut) {
    *badgeOut = badge;
  }

  CGFloat labelWidth = kContentWidth - 22.0 - 10.0;
  NSTextField *label = WrappingLabel(@"", labelWidth);
  label.attributedStringValue = [self attributedStepText:text];

  // Lay the badge out by hand so it lines up with the first line of the text, even when
  // the text wraps onto a second line.
  NSView *row = [NSView new];
  badge.translatesAutoresizingMaskIntoConstraints = NO;
  label.translatesAutoresizingMaskIntoConstraints = NO;
  [row addSubview:badge];
  [row addSubview:label];
  [NSLayoutConstraint activateConstraints:@[
    [badge.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
    [badge.widthAnchor constraintEqualToConstant:22.0],
    [badge.heightAnchor constraintEqualToConstant:22.0],
    [badge.centerYAnchor constraintEqualToAnchor:label.firstBaselineAnchor constant:-4.5],
    [label.leadingAnchor constraintEqualToAnchor:badge.trailingAnchor constant:10.0],
    [label.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
    [label.widthAnchor constraintEqualToConstant:labelWidth],
    [label.topAnchor constraintEqualToAnchor:row.topAnchor constant:2.0],
    [label.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-2.0],
    [badge.topAnchor constraintGreaterThanOrEqualToAnchor:row.topAnchor],
  ]];
  return row;
}

/// Text between ** markers is drawn in semibold, e.g. "Click **Open System Settings** below".
- (NSAttributedString *)attributedStepText:(NSString *)text
{
  NSMutableAttributedString *result = [NSMutableAttributedString new];
  NSArray<NSString *> *parts = [text componentsSeparatedByString:@"**"];
  [parts enumerateObjectsUsingBlock:^(NSString *part, NSUInteger index, BOOL *stop) {
    NSFont *font = (index % 2 == 1) ? [NSFont systemFontOfSize:13.0 weight:NSFontWeightSemibold] : [NSFont systemFontOfSize:13.0];
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakStrategy = NSLineBreakStrategyHangulWordPriority;
    paragraph.lineSpacing = 1.0;
    [result appendAttributedString:[[NSAttributedString alloc] initWithString:part attributes:@{
      NSFontAttributeName: font,
      NSForegroundColorAttributeName: NSColor.labelColor,
      NSParagraphStyleAttributeName: paragraph,
    }]];
  }];
  return result;
}

/// A drawn copy of the Split row in System Settings, with a switch that flips on and off.
- (NSView *)settingsRowMock
{
  NSView *box = [NSView new];
  box.wantsLayer = YES;
  box.layer.cornerRadius = 12.0;
  box.layer.borderWidth = 0.5;
  box.layer.borderColor = NSColor.separatorColor.CGColor;
  box.layer.backgroundColor = [NSColor.labelColor colorWithAlphaComponent:0.05].CGColor;

  NSImageView *icon = [NSImageView imageViewWithImage:AppIconImage()];
  icon.imageScaling = NSImageScaleProportionallyUpOrDown;
  NSTextField *name = [NSTextField labelWithString:@"Split"];
  name.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium];
  self.demoSwitch = [[SplitPermissionToggleView alloc] initWithFrame:NSMakeRect(0, 0, 42, 22)];
  self.toggleLabel = [NSTextField labelWithString:GuideString(@"ToggleOff")];
  self.toggleLabel.font = [NSFont systemFontOfSize:12.0 weight:NSFontWeightSemibold];
  self.toggleLabel.textColor = NSColor.systemRedColor;

  for (NSView *view in @[icon, name, self.demoSwitch, self.toggleLabel]) {
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [box addSubview:view];
  }
  [NSLayoutConstraint activateConstraints:@[
    [box.heightAnchor constraintEqualToConstant:48.0],
    [icon.widthAnchor constraintEqualToConstant:28.0],
    [icon.heightAnchor constraintEqualToConstant:28.0],
    [icon.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:12.0],
    [icon.centerYAnchor constraintEqualToAnchor:box.centerYAnchor],
    [name.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:10.0],
    [name.centerYAnchor constraintEqualToAnchor:box.centerYAnchor],
    [self.demoSwitch.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-14.0],
    [self.demoSwitch.centerYAnchor constraintEqualToAnchor:box.centerYAnchor],
    [self.demoSwitch.widthAnchor constraintEqualToConstant:42.0],
    [self.demoSwitch.heightAnchor constraintEqualToConstant:22.0],
    [self.toggleLabel.trailingAnchor constraintEqualToAnchor:self.demoSwitch.leadingAnchor constant:-8.0],
    [self.toggleLabel.centerYAnchor constraintEqualToAnchor:box.centerYAnchor],
  ]];

  NSTextField *caption = WrappingLabel(GuideString(@"LiveStatus"), kContentWidth);
  caption.font = [NSFont systemFontOfSize:11.0];
  caption.textColor = NSColor.tertiaryLabelColor;
  caption.alignment = NSTextAlignmentCenter;

  NSStackView *wrapper = [NSStackView stackViewWithViews:@[box, caption]];
  wrapper.orientation = NSUserInterfaceLayoutOrientationVertical;
  wrapper.spacing = 6.0;
  [box.widthAnchor constraintEqualToAnchor:wrapper.widthAnchor].active = YES;
  [caption.widthAnchor constraintEqualToAnchor:wrapper.widthAnchor].active = YES;
  return wrapper;
}

@end
