#import "SplitPreferencesController.h"

#import "SplitAccessibilityGuideController.h"
#import "SplitDefaultShortcutHelpers.h"
#import "SplitLoginItemHelper.h"
#import "SplitRegisteredShortcutValidator.h"
#import "SplitShortcut.h"
#import "SplitShortcutManager.h"
#import "SplitShortcutRecorder.h"
#import "SplitShortcutStorage.h"
#import "SplitShortcutValidation.h"
#import "SplitUtilities.h"
#import "SplitWindowArranger.h"
#import "SplitWindowFeedback.h"
#import "SplitWindowPositionManager.h"

NSNotificationName const SplitAutomaticUpdateCheckChangedNotification = @"SplitAutomaticUpdateCheckChangedNotification";

static NSString *const kWebsiteURL = @"https://runners.im/tools/split";
static NSString *const kGitHubURL = @"https://github.com/RUNNERS-IM/split";

static const CGFloat kContentWidth = 560.0;
static const CGFloat kOuterPadding = 20.0;
static const CGFloat kRowHorizontalPadding = 14.0;
static const CGFloat kRecorderWidth = 168.0;

/// Shortcut groups in the order the status menu shows them. Each entry: section title key,
/// optional hint key, shortcut names.
NSArray<NSArray *> *SplitShortcutSections(void)
{
  return @[
    @[@"SectionBasic", @"", @[@"MoveToCenter", @"MoveToFullscreen"]],
    @[@"SectionArrange", @"SectionArrangeHint", @[@"ArrangeWindows"]],
    @[@"SectionHalves", @"", @[@"MoveToLeftHalf", @"MoveToRightHalf", @"MoveToTopHalf", @"MoveToBottomHalf"]],
    @[@"SectionCorners", @"", @[@"MoveToUpperLeft", @"MoveToUpperRight", @"MoveToLowerLeft", @"MoveToLowerRight"]],
    @[@"SectionThirds", @"SectionThirdsHint", @[@"MoveToPreviousThird", @"MoveToNextThird"]],
    @[@"SectionDisplays", @"", @[@"MoveToPreviousDisplay", @"MoveToNextDisplay"]],
    @[@"SectionSize", @"", @[@"MakeLarger", @"MakeSmaller"]],
    @[@"SectionHistory", @"", @[@"UndoLastMove", @"RedoLastMove"]],
  ];
}

#pragma mark - Small view helpers

/// Lays out its subviews from the top, so a scroll view starts at the first section.
@interface SplitFlippedView : NSView
@end

@implementation SplitFlippedView
- (BOOL)isFlipped
{
  return YES;
}
@end

static NSTextField *Label(NSString *text, CGFloat size, NSFontWeight weight, NSColor *color)
{
  NSTextField *label = [NSTextField labelWithString:text ?: @""];
  label.font = [NSFont systemFontOfSize:size weight:weight];
  label.textColor = color;
  label.translatesAutoresizingMaskIntoConstraints = NO;
  return label;
}

static NSTextField *WrappingLabel(NSString *text, CGFloat size, NSColor *color, CGFloat width)
{
  NSTextField *label = [NSTextField wrappingLabelWithString:text ?: @""];
  label.font = [NSFont systemFontOfSize:size];
  label.textColor = color;
  label.selectable = NO;
  label.preferredMaxLayoutWidth = width;
  label.translatesAutoresizingMaskIntoConstraints = NO;
  [label.widthAnchor constraintEqualToConstant:width].active = YES;
  return label;
}

static NSStackView *VerticalStack(NSArray<NSView *> *views, CGFloat spacing)
{
  NSStackView *stack = [NSStackView stackViewWithViews:views];
  stack.orientation = NSUserInterfaceLayoutOrientationVertical;
  stack.alignment = NSLayoutAttributeLeading;
  stack.spacing = spacing;
  stack.translatesAutoresizingMaskIntoConstraints = NO;
  return stack;
}

static NSStackView *HorizontalStack(NSArray<NSView *> *views, CGFloat spacing)
{
  NSStackView *stack = [NSStackView stackViewWithViews:views];
  stack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  stack.alignment = NSLayoutAttributeCenterY;
  stack.spacing = spacing;
  stack.translatesAutoresizingMaskIntoConstraints = NO;
  return stack;
}

static NSView *FlexibleSpace(void)
{
  NSView *space = [NSView new];
  space.translatesAutoresizingMaskIntoConstraints = NO;
  [space setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  [space setContentCompressionResistancePriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  return space;
}

static NSColor *CardFillColor(void)
{
  return [NSColor colorWithName:nil dynamicProvider:^NSColor *(NSAppearance *appearance) {
    BOOL dark = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]] == NSAppearanceNameDarkAqua;
    return dark ? [NSColor colorWithWhite:1.0 alpha:0.05] : [NSColor colorWithWhite:1.0 alpha:0.85];
  }];
}

/// A rounded group like the ones in System Settings. Rows are separated by thin lines.
static NSBox *Card(NSArray<NSView *> *rows, CGFloat width)
{
  NSMutableArray<NSView *> *views = [NSMutableArray new];
  [rows enumerateObjectsUsingBlock:^(NSView *row, NSUInteger index, BOOL *stop) {
    if (index > 0) {
      NSBox *separator = [NSBox new];
      separator.boxType = NSBoxSeparator;
      separator.translatesAutoresizingMaskIntoConstraints = NO;
      [separator.widthAnchor constraintEqualToConstant:width - 2 * kRowHorizontalPadding].active = YES;
      [views addObject:separator];
    }
    [views addObject:row];
  }];
  NSStackView *stack = VerticalStack(views, 0);
  stack.alignment = NSLayoutAttributeCenterX;
  NSBox *box = [NSBox new];
  box.boxType = NSBoxCustom;
  box.titlePosition = NSNoTitle;
  box.cornerRadius = 10.0;
  box.borderWidth = 0.5;
  box.borderColor = NSColor.separatorColor;
  box.fillColor = CardFillColor();
  box.contentViewMargins = NSZeroSize;
  box.translatesAutoresizingMaskIntoConstraints = NO;
  [box.contentView addSubview:stack];
  [NSLayoutConstraint activateConstraints:@[
    [box.widthAnchor constraintEqualToConstant:width],
    [stack.topAnchor constraintEqualToAnchor:box.contentView.topAnchor],
    [stack.bottomAnchor constraintEqualToAnchor:box.contentView.bottomAnchor],
    [stack.leadingAnchor constraintEqualToAnchor:box.contentView.leadingAnchor],
    [stack.trailingAnchor constraintEqualToAnchor:box.contentView.trailingAnchor],
  ]];
  return box;
}

/// One row inside a card: text on the left, a control on the right.
static NSView *Row(NSView *left, NSView *right, CGFloat width, CGFloat verticalPadding)
{
  NSView *row = [NSView new];
  row.translatesAutoresizingMaskIntoConstraints = NO;
  NSStackView *line = HorizontalStack(right ? @[left, FlexibleSpace(), right] : @[left, FlexibleSpace()], 12);
  [row addSubview:line];
  [NSLayoutConstraint activateConstraints:@[
    [row.widthAnchor constraintEqualToConstant:width],
    [line.topAnchor constraintEqualToAnchor:row.topAnchor constant:verticalPadding],
    [line.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-verticalPadding],
    [line.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:kRowHorizontalPadding],
    [line.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-kRowHorizontalPadding],
  ]];
  return row;
}

/// A round color button for the Effects tab. "accent" is drawn as a color wheel because it
/// follows whatever accent color is chosen in System Settings.
@interface SplitColorSwatch : NSButton
@property (nonatomic, copy) NSString *colorName;
@property (nonatomic) BOOL chosen;
@end

@implementation SplitColorSwatch

- (void)setChosen:(BOOL)chosen
{
  _chosen = chosen;
  self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect
{
  NSRect circle = NSInsetRect(self.bounds, 4.0, 4.0);
  if ([self.colorName isEqualToString:@"accent"]) {
    NSArray<NSColor *> *wheel = @[NSColor.systemRedColor, NSColor.systemOrangeColor, NSColor.systemYellowColor,
                                  NSColor.systemGreenColor, NSColor.systemBlueColor, NSColor.systemPurpleColor];
    NSPoint center = NSMakePoint(NSMidX(circle), NSMidY(circle));
    CGFloat step = 360.0 / wheel.count;
    [wheel enumerateObjectsUsingBlock:^(NSColor *color, NSUInteger index, BOOL *stop) {
      NSBezierPath *slice = [NSBezierPath bezierPath];
      [slice moveToPoint:center];
      [slice appendBezierPathWithArcWithCenter:center radius:NSWidth(circle) / 2.0 startAngle:90.0 + index * step endAngle:90.0 + (index + 1) * step];
      [slice closePath];
      [color setFill];
      [slice fill];
    }];
  } else {
    [SplitMoveFeedbackColorForName(self.colorName) setFill];
    [[NSBezierPath bezierPathWithOvalInRect:circle] fill];
  }
  if (self.chosen) {
    NSBezierPath *ring = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(self.bounds, 1.0, 1.0)];
    ring.lineWidth = 2.0;
    [NSColor.labelColor setStroke];
    [ring stroke];
  }
  if (!self.enabled) {
    [[NSColor.windowBackgroundColor colorWithAlphaComponent:0.6] setFill];
    [[NSBezierPath bezierPathWithOvalInRect:self.bounds] fill];
  }
}

@end

#pragma mark -

@interface SplitPreferencesController () <NSWindowDelegate>
@end

@implementation SplitPreferencesController
{
  SplitShortcutManager *_shortcutManager;
  SplitWindowPositionManager *_windowPositionManager;
  id<SplitShortcutStorage> _shortcutStorage;
  NSMutableDictionary<NSString *, SplitShortcutRecorder *> *_shortcutRecorders;
  NSTabViewController *_tabViewController;
  NSSwitch *_loginItemSwitch;
  NSSwitch *_statusItemSwitch;
  NSSegmentedControl *_feedbackStyleControl;
  NSArray<SplitColorSwatch *> *_colorSwatches;
  NSSwitch *_feedbackShortcutSwitch;
  NSSegmentedControl *_feedbackDurationControl;
  NSSegmentedControl *_feedbackPositionControl;
  NSArray<NSView *> *_feedbackDetailRows;
  NSView *_feedbackPositionRow;
  SplitWindowFeedback *_feedbackSample;
  NSSwitch *_automaticUpdateSwitch;
  NSSegmentedControl *_gapControl;
  NSSwitch *_displayChangeSwitch;
  NSSwitch *_shortcutSheetSwitch;
  NSView *_permissionDot;
  NSTextField *_permissionHint;
  NSButton *_permissionButton;
  NSTimer *_permissionTimer;
}

- (instancetype)initWithShortcutManager:(SplitShortcutManager *)shortcutManager
                  windowPositionManager:(SplitWindowPositionManager *)windowPositionManager
                        shortcutStorage:(id<SplitShortcutStorage>)shortcutStorage
{
  if (self = [super initWithWindow:nil]) {
    _shortcutManager = shortcutManager;
    _windowPositionManager = windowPositionManager;
    _shortcutStorage = shortcutStorage;
    _shortcutRecorders = [NSMutableDictionary new];
  }
  return self;
}

/// NSWindowController only calls -loadWindow when it has a nib name, and this window has none,
/// so the window is built here the first time it is shown.
- (void)buildWindowIfNeeded
{
  if (_tabViewController) {
    return;
  }
  _tabViewController = [NSTabViewController new];
  _tabViewController.tabStyle = NSTabViewControllerTabStyleToolbar;
  _tabViewController.transitionOptions = NSViewControllerTransitionCrossfade | NSViewControllerTransitionAllowUserInteraction;
  [_tabViewController addTabViewItem:[self tabItemWithView:[self makeGeneralView]
                                                     title:SplitLocalized(@"TabGeneral")
                                                      icon:@"settings"]];
  [_tabViewController addTabViewItem:[self tabItemWithView:[self makeEffectsView]
                                                     title:SplitLocalized(@"TabEffects")
                                                      icon:@"sparkles"]];
  [_tabViewController addTabViewItem:[self tabItemWithView:[self makeShortcutsView]
                                                     title:SplitLocalized(@"TabShortcuts")
                                                      icon:@"keyboard"]];
  NSWindow *window = [NSWindow windowWithContentViewController:_tabViewController];
  window.styleMask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable;
  window.toolbarStyle = NSWindowToolbarStylePreference;
  window.delegate = self;
  window.releasedWhenClosed = NO;
  self.window = window;
  [window center];

  NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
  [center addObserver:self selector:@selector(loadRegisteredShortcuts) name:@"SplitShortcutChangedNotification" object:nil];
  [center addObserver:self selector:@selector(loadRegisteredShortcuts) name:@"SplitRestoreDefaultShortcutsNotification" object:nil];
  [self loadRegisteredShortcuts];
}

- (NSTabViewItem *)tabItemWithView:(NSView *)view title:(NSString *)title icon:(NSString *)icon
{
  NSViewController *controller = [NSViewController new];
  controller.view = view;
  // The window shows the selected controller's title; keep it "Split Settings" on every tab.
  controller.title = SplitLocalized(@"SettingsWindowTitle");
  controller.preferredContentSize = view.fittingSize;
  NSTabViewItem *item = [NSTabViewItem tabViewItemWithViewController:controller];
  item.label = title;
  item.image = SplitIcon(icon, 22);
  return item;
}

- (void)showWindow:(id)sender
{
  [self buildWindowIfNeeded];
  [super showWindow:sender];
  [self refreshGeneralState];
  [self startPermissionPolling];
  [NSApp activateIgnoringOtherApps:YES];
}

#pragma mark - General tab

- (NSSwitch *)switchWithAction:(SEL)action
{
  NSSwitch *control = [NSSwitch new];
  control.target = self;
  control.action = action;
  control.controlSize = NSControlSizeSmall;
  control.translatesAutoresizingMaskIntoConstraints = NO;
  return control;
}

- (NSView *)textBlockWithTitle:(NSString *)title hint:(NSString *)hint width:(CGFloat)width
{
  NSMutableArray *views = [NSMutableArray arrayWithObject:Label(title, 13, NSFontWeightRegular, NSColor.labelColor)];
  if (hint.length > 0) {
    [views addObject:WrappingLabel(hint, 11, NSColor.secondaryLabelColor, width)];
  }
  return VerticalStack(views, 2);
}

- (NSView *)makeGeneralView
{
  CGFloat cardWidth = kContentWidth - 2 * kOuterPadding;
  CGFloat textWidth = cardWidth - 2 * kRowHorizontalPadding - 70;

  _loginItemSwitch = [self switchWithAction:@selector(toggleLoginItem:)];
  _statusItemSwitch = [self switchWithAction:@selector(toggleStatusItem:)];
  _gapControl = [self segmentsWithLabelKeys:@[@"GapNone", @"GapNarrow", @"GapNormal", @"GapWide"] action:@selector(changeGap:)];
  _displayChangeSwitch = [self switchWithAction:@selector(toggleDisplayChange:)];
  _shortcutSheetSwitch = [self switchWithAction:@selector(toggleShortcutSheet:)];
  CGFloat gapTextWidth = cardWidth - 2 * kRowHorizontalPadding - 230;
  NSMutableArray<NSView *> *rows = [NSMutableArray arrayWithArray:@[
    Row([self textBlockWithTitle:SplitLocalized(@"LaunchAtLogin") hint:SplitLocalized(@"LaunchAtLoginHint") width:textWidth], _loginItemSwitch, cardWidth, 10),
    Row([self textBlockWithTitle:SplitLocalized(@"ShowMenuBarIcon") hint:SplitLocalized(@"ShowMenuBarIconHint") width:textWidth], _statusItemSwitch, cardWidth, 10),
    Row([self textBlockWithTitle:SplitLocalized(@"WindowGap") hint:SplitLocalized(@"WindowGapHint") width:gapTextWidth], _gapControl, cardWidth, 10),
    Row([self textBlockWithTitle:SplitLocalized(@"DisplayChange") hint:SplitLocalized(@"DisplayChangeHint") width:textWidth], _displayChangeSwitch, cardWidth, 10),
    Row([self textBlockWithTitle:SplitLocalized(@"ShortcutSheetHold") hint:SplitLocalized(@"ShortcutSheetHoldHint") width:textWidth], _shortcutSheetSwitch, cardWidth, 10),
  ]];
#if !SPLIT_APP_STORE
  _automaticUpdateSwitch = [self switchWithAction:@selector(toggleAutomaticUpdates:)];
  [rows addObject:Row([self textBlockWithTitle:SplitLocalized(@"AutoUpdate") hint:SplitLocalized(@"AutoUpdateHint") width:textWidth], _automaticUpdateSwitch, cardWidth, 10)];
#endif
  NSBox *optionsCard = Card(rows, cardWidth);

  // Accessibility permission, refreshed every second while the window is open.
  _permissionDot = [NSView new];
  _permissionDot.wantsLayer = YES;
  _permissionDot.layer.cornerRadius = 5.0;
  _permissionDot.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [_permissionDot.widthAnchor constraintEqualToConstant:10],
    [_permissionDot.heightAnchor constraintEqualToConstant:10],
  ]];
  _permissionHint = Label(@"", 11, NSFontWeightRegular, NSColor.secondaryLabelColor);
  NSStackView *permissionText = VerticalStack(@[
    Label(SplitLocalized(@"PermissionTitle"), 13, NSFontWeightRegular, NSColor.labelColor),
    HorizontalStack(@[_permissionDot, _permissionHint], 6),
  ], 3);
  _permissionButton = [NSButton buttonWithTitle:SplitLocalized(@"PermissionOpen") target:self action:@selector(openAccessibilitySettings:)];
  _permissionButton.controlSize = NSControlSizeSmall;
  NSBox *permissionCard = Card(@[Row(permissionText, _permissionButton, cardWidth, 10)], cardWidth);

  // About line with links.
  NSImageView *icon = [NSImageView imageViewWithImage:NSApp.applicationIconImage ?: [NSImage new]];
  icon.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [icon.widthAnchor constraintEqualToConstant:40],
    [icon.heightAnchor constraintEqualToConstant:40],
  ]];
  NSStackView *aboutText = VerticalStack(@[
    Label(@"Split", 13, NSFontWeightSemibold, NSColor.labelColor),
    Label([NSString stringWithFormat:SplitLocalized(@"AboutLine"), SplitUtilities.applicationVersion], 11, NSFontWeightRegular, NSColor.secondaryLabelColor),
  ], 1);
  NSButton *website = [NSButton buttonWithTitle:SplitLocalized(@"Website") target:self action:@selector(openWebsite:)];
  NSButton *github = [NSButton buttonWithTitle:@"GitHub" target:self action:@selector(openGitHub:)];
  website.controlSize = NSControlSizeSmall;
  github.controlSize = NSControlSizeSmall;
  NSStackView *about = HorizontalStack(@[icon, aboutText, FlexibleSpace(), website, github], 10);
  [about.widthAnchor constraintEqualToConstant:cardWidth].active = YES;

  NSMutableArray<NSView *> *cards = [NSMutableArray arrayWithObject:optionsCard];
#if !SPLIT_APP_STORE
  NSView *spacesCard = [self spacesCardWithWidth:cardWidth];
  if (spacesCard) {
    [cards addObject:spacesCard];
  }
#endif
  [cards addObjectsFromArray:@[permissionCard, about]];
  NSStackView *content = VerticalStack(cards, 16);
  NSView *container = [NSView new];
  [container addSubview:content];
  [NSLayoutConstraint activateConstraints:@[
    [container.widthAnchor constraintEqualToConstant:kContentWidth],
    [content.topAnchor constraintEqualToAnchor:container.topAnchor constant:kOuterPadding],
    [content.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-kOuterPadding],
    [content.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:kOuterPadding],
  ]];
  return container;
}

- (void)refreshGeneralState
{
  NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
  _loginItemSwitch.state = [SplitLoginItemHelper isLoginItemEnabledForBundle:NSBundle.mainBundle] ? NSControlStateValueOn : NSControlStateValueOff;
  _statusItemSwitch.state = [defaults boolForKey:@"StatusItemEnabled"] ? NSControlStateValueOn : NSControlStateValueOff;
  [self refreshEffectsState];
  NSArray<NSNumber *> *gaps = @[@0, @8, @16, @24];
  NSUInteger gapIndex = [gaps indexOfObject:@((NSInteger)round(SplitWindowGap()))];
  _gapControl.selectedSegment = gapIndex == NSNotFound ? 1 : (NSInteger)gapIndex;
  _displayChangeSwitch.state = SplitDisplayChangeArranger.enabled ? NSControlStateValueOn : NSControlStateValueOff;
  _shortcutSheetSwitch.state = SplitShortcutSheet.holdToShowEnabled ? NSControlStateValueOn : NSControlStateValueOff;
  _automaticUpdateSwitch.state = [defaults boolForKey:@"AutomaticUpdateCheckEnabled"] ? NSControlStateValueOn : NSControlStateValueOff;
  [self refreshPermission];
}

- (void)refreshPermission
{
  BOOL granted = [SplitAccessibilityGuideController isAccessibilityPermissionGranted];
  _permissionDot.layer.backgroundColor = (granted ? NSColor.systemGreenColor : NSColor.systemRedColor).CGColor;
  _permissionHint.stringValue = SplitLocalized(granted ? @"PermissionOnHint" : @"PermissionOffHint");
  _permissionButton.hidden = granted;
}

- (void)startPermissionPolling
{
  [_permissionTimer invalidate];
  _permissionTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(refreshPermission) userInfo:nil repeats:YES];
}

- (void)windowWillClose:(NSNotification *)notification
{
  [_permissionTimer invalidate];
  _permissionTimer = nil;
}

- (void)toggleLoginItem:(NSSwitch *)sender
{
  if (sender.state == NSControlStateValueOn) {
    [SplitLoginItemHelper enableLoginItemForBundle:NSBundle.mainBundle];
  } else {
    [SplitLoginItemHelper disableLoginItemForBundle:NSBundle.mainBundle];
  }
}

- (void)toggleStatusItem:(NSSwitch *)sender
{
  NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
  BOOL enable = sender.state == NSControlStateValueOn;
  if (enable == [defaults boolForKey:@"StatusItemEnabled"]) {
    return;
  }
  if (!enable && ![defaults boolForKey:@"BackgroundAlertSuppressed"]) {
    __block BOOL confirmed = YES;
    [SplitUtilities displayRunningInBackgroundAlertWithCallback:^(BOOL isConfirmed, BOOL isSuppressed) {
      confirmed = isConfirmed;
      [defaults setBool:isSuppressed forKey:@"BackgroundAlertSuppressed"];
    }];
    if (!confirmed) {
      sender.state = NSControlStateValueOn;
      return;
    }
  }
  [defaults setBool:enable forKey:@"StatusItemEnabled"];
  [NSNotificationCenter.defaultCenter postNotificationName:enable ? @"SplitStatusItemEnabledNotification" : @"SplitStatusItemDisabledNotification"
                                                    object:self];
}

- (void)changeGap:(NSSegmentedControl *)sender
{
  NSArray<NSNumber *> *gaps = @[@0, @8, @16, @24];
  [NSUserDefaults.standardUserDefaults setObject:gaps[MIN((NSUInteger)MAX(sender.selectedSegment, 0), gaps.count - 1)] forKey:SplitWindowGapKey];
}

- (void)toggleDisplayChange:(NSSwitch *)sender
{
  [NSUserDefaults.standardUserDefaults setBool:sender.state == NSControlStateValueOn forKey:@"RearrangeOnDisplayChange"];
}

- (void)toggleShortcutSheet:(NSSwitch *)sender
{
  [NSUserDefaults.standardUserDefaults setBool:sender.state == NSControlStateValueOn forKey:@"ShortcutSheetEnabled"];
}

#if !SPLIT_APP_STORE
/// Two macOS settings make desktops pile up and change order when monitors come and go.
/// Split cannot move windows between desktops, so it points to the settings instead, and only
/// while they are on.
- (NSView *)spacesCardWithWidth:(CGFloat)cardWidth
{
  CGFloat textWidth = cardWidth - 2 * kRowHorizontalPadding - 90;
  NSNumber *reorders = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("mru-spaces"), CFSTR("com.apple.dock")));
  NSNumber *spansDisplays = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("spans-displays"), CFSTR("com.apple.spaces")));
  NSMutableArray<NSView *> *rows = [NSMutableArray new];
  if (!reorders || reorders.boolValue) {
    NSButton *open = [NSButton buttonWithTitle:SplitLocalized(@"PermissionOpen") target:self action:@selector(openDesktopSettings:)];
    open.controlSize = NSControlSizeSmall;
    [rows addObject:Row([self textBlockWithTitle:SplitLocalized(@"SpacesReorder") hint:SplitLocalized(@"SpacesReorderHint") width:textWidth], open, cardWidth, 10)];
  }
  if (!spansDisplays || !spansDisplays.boolValue) {
    NSButton *open = [NSButton buttonWithTitle:SplitLocalized(@"PermissionOpen") target:self action:@selector(openDesktopSettings:)];
    open.controlSize = NSControlSizeSmall;
    [rows addObject:Row([self textBlockWithTitle:SplitLocalized(@"SpacesSeparate") hint:SplitLocalized(@"SpacesSeparateHint") width:textWidth], open, cardWidth, 10)];
  }
  if (rows.count == 0) {
    return nil;
  }
  NSStackView *section = VerticalStack(@[Label(SplitLocalized(@"SpacesSection"), 11, NSFontWeightSemibold, NSColor.secondaryLabelColor), Card(rows, cardWidth)], 6);
  return section;
}

- (void)openDesktopSettings:(id)sender
{
  [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.Desktop-Settings.extension"]];
}
#endif

#pragma mark - Effects tab

- (NSSegmentedControl *)segmentsWithLabelKeys:(NSArray<NSString *> *)keys action:(SEL)action
{
  NSMutableArray<NSString *> *labels = [NSMutableArray new];
  for (NSString *key in keys) {
    [labels addObject:SplitLocalized(key)];
  }
  NSSegmentedControl *control = [NSSegmentedControl segmentedControlWithLabels:labels
                                                                  trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                        target:self
                                                                        action:action];
  control.controlSize = NSControlSizeSmall;
  control.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
  control.translatesAutoresizingMaskIntoConstraints = NO;
  return control;
}

- (NSView *)makeEffectsView
{
  CGFloat cardWidth = kContentWidth - 2 * kOuterPadding;
  CGFloat textWidth = cardWidth - 2 * kRowHorizontalPadding - 240;

  _feedbackStyleControl = [self segmentsWithLabelKeys:@[@"FeedbackOff", @"FeedbackSubtle", @"FeedbackStrong"] action:@selector(changeFeedbackStyle:)];
  NSMutableArray<SplitColorSwatch *> *swatches = [NSMutableArray new];
  for (NSString *name in SplitMoveFeedbackColorNames()) {
    SplitColorSwatch *swatch = [SplitColorSwatch new];
    swatch.colorName = name;
    swatch.bordered = NO;
    swatch.title = @"";
    swatch.target = self;
    swatch.action = @selector(chooseFeedbackColor:);
    NSString *label = SplitLocalized([@"Color_" stringByAppendingString:name]);
    swatch.toolTip = label;
    swatch.accessibilityLabel = label;
    swatch.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
      [swatch.widthAnchor constraintEqualToConstant:22],
      [swatch.heightAnchor constraintEqualToConstant:22],
    ]];
    [swatches addObject:swatch];
  }
  _colorSwatches = swatches;
  _feedbackShortcutSwitch = [self switchWithAction:@selector(toggleFeedbackShortcut:)];
  _feedbackDurationControl = [self segmentsWithLabelKeys:@[@"DurationShort", @"DurationNormal", @"DurationLong"] action:@selector(changeFeedbackDuration:)];
  _feedbackPositionControl = [self segmentsWithLabelKeys:@[@"PositionBottom", @"PositionTop", @"PositionCenter"] action:@selector(changeFeedbackPosition:)];

  NSView *colorRow = Row([self textBlockWithTitle:SplitLocalized(@"FeedbackColor") hint:SplitLocalized(@"FeedbackColorHint") width:textWidth], HorizontalStack(swatches, 2), cardWidth, 10);
  NSView *shortcutRow = Row([self textBlockWithTitle:SplitLocalized(@"FeedbackShortcut") hint:SplitLocalized(@"FeedbackShortcutHint") width:textWidth], _feedbackShortcutSwitch, cardWidth, 10);
  NSView *durationRow = Row([self textBlockWithTitle:SplitLocalized(@"FeedbackDuration") hint:nil width:textWidth], _feedbackDurationControl, cardWidth, 10);
  _feedbackPositionRow = Row([self textBlockWithTitle:SplitLocalized(@"FeedbackPosition") hint:nil width:textWidth], _feedbackPositionControl, cardWidth, 10);
  _feedbackDetailRows = @[colorRow, shortcutRow, durationRow];
  NSBox *card = Card(@[
    Row([self textBlockWithTitle:SplitLocalized(@"MoveFeedback") hint:SplitLocalized(@"MoveFeedbackHint") width:textWidth], _feedbackStyleControl, cardWidth, 10),
    colorRow,
    shortcutRow,
    durationRow,
    _feedbackPositionRow,
  ], cardWidth);

  NSButton *sample = [NSButton buttonWithTitle:SplitLocalized(@"FeedbackTry") target:self action:@selector(showFeedbackSample:)];
  sample.controlSize = NSControlSizeSmall;
  NSStackView *footer = HorizontalStack(@[Label(SplitLocalized(@"FeedbackTryHint"), 11, NSFontWeightRegular, NSColor.secondaryLabelColor), FlexibleSpace(), sample], 12);
  [footer.widthAnchor constraintEqualToConstant:cardWidth].active = YES;

  NSStackView *content = VerticalStack(@[card, footer], 12);
  NSView *container = [NSView new];
  [container addSubview:content];
  [NSLayoutConstraint activateConstraints:@[
    [container.widthAnchor constraintEqualToConstant:kContentWidth],
    [content.topAnchor constraintEqualToAnchor:container.topAnchor constant:kOuterPadding],
    [content.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-kOuterPadding],
    [content.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:kOuterPadding],
  ]];
  return container;
}

/// Turns a row's controls and labels on or off together, so a disabled row looks dimmed.
static void SetRowEnabled(NSView *view, BOOL enabled)
{
  if ([view isKindOfClass:NSControl.class]) {
    ((NSControl *)view).enabled = enabled;
    if ([view isKindOfClass:NSTextField.class]) {
      view.alphaValue = enabled ? 1.0 : 0.45;
    }
  }
  for (NSView *subview in view.subviews) {
    SetRowEnabled(subview, enabled);
  }
}

- (void)refreshEffectsState
{
  SplitMoveFeedbackStyle style = SplitWindowFeedback.moveFeedbackStyle;
  _feedbackStyleControl.selectedSegment = style;
  NSString *colorName = SplitWindowFeedback.moveFeedbackColorName;
  for (SplitColorSwatch *swatch in _colorSwatches) {
    swatch.chosen = [swatch.colorName isEqualToString:colorName];
  }
  _feedbackShortcutSwitch.state = SplitWindowFeedback.moveFeedbackShowsShortcut ? NSControlStateValueOn : NSControlStateValueOff;
  _feedbackDurationControl.selectedSegment = SplitWindowFeedback.moveFeedbackDuration;
  _feedbackPositionControl.selectedSegment = SplitWindowFeedback.moveFeedbackLabelPosition;
  BOOL enabled = style != SplitMoveFeedbackStyleOff;
  for (NSView *row in _feedbackDetailRows) {
    SetRowEnabled(row, enabled);
  }
  SetRowEnabled(_feedbackPositionRow, enabled && SplitWindowFeedback.moveFeedbackShowsShortcut);
}

/// Plays the glow and label around the Settings window so a change can be seen right away.
- (void)showFeedbackSample:(id)sender
{
  [self refreshEffectsState];
  if (!SplitWindowFeedback.moveFeedbackEnabled || !self.window) {
    return;
  }
  if (!_feedbackSample) {
    _feedbackSample = [SplitWindowFeedback new];
  }
  NSRect frame = self.window.frame;
  CGFloat primaryHeight = NSScreen.screens.firstObject.frame.size.height;
  CGRect rect = CGRectMake(NSMinX(frame), primaryHeight - NSMaxY(frame), NSWidth(frame), NSHeight(frame));
  [_feedbackSample showMoveFeedbackForRect:rect title:SplitLocalized(@"MoveToCenter") shortcut:[_shortcutManager shortcutForShortcutName:@"MoveToCenter"].displayString];
}

- (void)changeFeedbackStyle:(NSSegmentedControl *)sender
{
  [NSUserDefaults.standardUserDefaults setInteger:sender.selectedSegment forKey:SplitMoveFeedbackStyleKey];
  [self showFeedbackSample:sender];
}

- (void)chooseFeedbackColor:(SplitColorSwatch *)sender
{
  [NSUserDefaults.standardUserDefaults setObject:sender.colorName forKey:SplitMoveFeedbackColorKey];
  [self showFeedbackSample:sender];
}

- (void)toggleFeedbackShortcut:(NSSwitch *)sender
{
  [NSUserDefaults.standardUserDefaults setBool:sender.state == NSControlStateValueOn forKey:SplitMoveFeedbackShowsShortcutKey];
  [self showFeedbackSample:sender];
}

- (void)changeFeedbackDuration:(NSSegmentedControl *)sender
{
  [NSUserDefaults.standardUserDefaults setInteger:sender.selectedSegment forKey:SplitMoveFeedbackDurationKey];
  [self showFeedbackSample:sender];
}

- (void)changeFeedbackPosition:(NSSegmentedControl *)sender
{
  [NSUserDefaults.standardUserDefaults setInteger:sender.selectedSegment forKey:SplitMoveFeedbackLabelPositionKey];
  [self showFeedbackSample:sender];
}

- (void)toggleAutomaticUpdates:(NSSwitch *)sender
{
  [NSUserDefaults.standardUserDefaults setBool:sender.state == NSControlStateValueOn forKey:@"AutomaticUpdateCheckEnabled"];
  [NSNotificationCenter.defaultCenter postNotificationName:SplitAutomaticUpdateCheckChangedNotification object:self];
}

- (void)openAccessibilitySettings:(id)sender
{
  [SplitAccessibilityGuideController openAccessibilitySettings];
}

- (void)openWebsite:(id)sender
{
  [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:kWebsiteURL]];
}

- (void)openGitHub:(id)sender
{
  [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:kGitHubURL]];
}

#pragma mark - Shortcuts tab

- (NSView *)shortcutRowForName:(NSString *)shortcutName width:(CGFloat)width
{
  NSImageView *picture = [NSImageView imageViewWithImage:SplitMenuImageForShortcutName(shortcutName) ?: [NSImage new]];
  picture.contentTintColor = NSColor.secondaryLabelColor;
  picture.imageScaling = NSImageScaleProportionallyUpOrDown;
  picture.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [picture.widthAnchor constraintEqualToConstant:22],
    [picture.heightAnchor constraintEqualToConstant:16],
  ]];
  SplitShortcutRecorder *recorder = [[SplitShortcutRecorder alloc] initWithFrame:NSMakeRect(0, 0, kRecorderWidth, 24)];
  recorder.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [recorder.widthAnchor constraintEqualToConstant:kRecorderWidth],
    [recorder.heightAnchor constraintEqualToConstant:24],
  ]];
  _shortcutRecorders[shortcutName] = recorder;
  NSStackView *left = HorizontalStack(@[picture, Label(SplitLocalized(shortcutName), 13, NSFontWeightRegular, NSColor.labelColor)], 10);
  return Row(left, recorder, width, 6);
}

- (NSView *)makeShortcutsView
{
  CGFloat cardWidth = kContentWidth - 2 * kOuterPadding;
  NSMutableArray<NSView *> *sections = [NSMutableArray new];
  for (NSArray *section in SplitShortcutSections()) {
    NSMutableArray<NSView *> *header = [NSMutableArray arrayWithObject:Label(SplitLocalized(section[0]), 11, NSFontWeightSemibold, NSColor.secondaryLabelColor)];
    if ([section[1] length] > 0) {
      [header addObject:WrappingLabel(SplitLocalized(section[1]), 11, NSColor.tertiaryLabelColor, cardWidth - 8)];
    }
    NSStackView *headerStack = VerticalStack(header, 2);
    NSMutableArray<NSView *> *rows = [NSMutableArray new];
    for (NSString *shortcutName in section[2]) {
      [rows addObject:[self shortcutRowForName:shortcutName width:cardWidth]];
    }
    NSStackView *sectionStack = VerticalStack(@[headerStack, Card(rows, cardWidth)], 6);
    [sectionStack setCustomSpacing:6 afterView:headerStack];
    [sections addObject:sectionStack];
  }
  NSStackView *list = VerticalStack(sections, 18);

  SplitFlippedView *document = [SplitFlippedView new];
  document.translatesAutoresizingMaskIntoConstraints = NO;
  [document addSubview:list];
  [NSLayoutConstraint activateConstraints:@[
    [list.topAnchor constraintEqualToAnchor:document.topAnchor constant:kOuterPadding],
    [list.bottomAnchor constraintEqualToAnchor:document.bottomAnchor constant:-kOuterPadding],
    [list.leadingAnchor constraintEqualToAnchor:document.leadingAnchor constant:kOuterPadding],
    [document.widthAnchor constraintEqualToConstant:kContentWidth],
  ]];

  NSScrollView *scrollView = [NSScrollView new];
  scrollView.hasVerticalScroller = YES;
  scrollView.autohidesScrollers = YES;
  scrollView.drawsBackground = NO;
  scrollView.borderType = NSNoBorder;
  scrollView.documentView = document;
  scrollView.translatesAutoresizingMaskIntoConstraints = NO;
  [document.topAnchor constraintEqualToAnchor:scrollView.contentView.topAnchor].active = YES;
  [document.leadingAnchor constraintEqualToAnchor:scrollView.contentView.leadingAnchor].active = YES;

  NSBox *divider = [NSBox new];
  divider.boxType = NSBoxSeparator;
  divider.translatesAutoresizingMaskIntoConstraints = NO;

  NSStackView *hints = VerticalStack(@[
    Label(SplitLocalized(@"ShortcutsHint"), 11, NSFontWeightRegular, NSColor.secondaryLabelColor),
    Label(SplitLocalized(@"ModifierLegend"), 11, NSFontWeightRegular, NSColor.tertiaryLabelColor),
  ], 2);
  NSButton *restore = [NSButton buttonWithTitle:SplitLocalized(@"RestoreDefaults") target:self action:@selector(restoreDefaults:)];
  NSStackView *footer = HorizontalStack(@[hints, FlexibleSpace(), restore], 12);

  NSView *container = [NSView new];
  [container addSubview:scrollView];
  [container addSubview:divider];
  [container addSubview:footer];
  [NSLayoutConstraint activateConstraints:@[
    [container.widthAnchor constraintEqualToConstant:kContentWidth],
    [scrollView.topAnchor constraintEqualToAnchor:container.topAnchor],
    [scrollView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
    [scrollView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
    [scrollView.heightAnchor constraintEqualToConstant:480],
    [divider.topAnchor constraintEqualToAnchor:scrollView.bottomAnchor],
    [divider.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
    [divider.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
    [footer.topAnchor constraintEqualToAnchor:divider.bottomAnchor constant:12],
    [footer.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:kOuterPadding],
    [footer.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-kOuterPadding],
    [footer.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-14],
  ]];
  return container;
}

- (void)loadRegisteredShortcuts
{
  for (NSString *shortcutName in _shortcutRecorders) {
    SplitShortcutRecorder *recorder = _shortcutRecorders[shortcutName];
    recorder.shortcutName = shortcutName;
    recorder.shortcut = [_shortcutManager shortcutForShortcutName:shortcutName];
    recorder.delegate = self;
    recorder.shortcutValidation = [[SplitShortcutValidation alloc] initWithShortcutManager:_shortcutManager
                                                                                validators:@[[SplitRegisteredShortcutValidator new]]];
  }
}

- (SplitShortcutAction)shortcutAction
{
  __weak typeof(self) weakSelf = self;
  return ^(SplitShortcut *shortcut) {
    SplitPreferencesController *strongSelf = weakSelf;
    if (strongSelf.windowActionHandler) {
      strongSelf.windowActionHandler(shortcut.windowAction);
    }
  };
}

- (void)shortcutRecorder:(SplitShortcutRecorder *)shortcutRecorder didReceiveNewShortcut:(SplitShortcut *)shortcut
{
  [_shortcutManager updateShortcut:[shortcut copyWithShortcutAction:[self shortcutAction]]];
  [NSNotificationCenter.defaultCenter postNotificationName:@"SplitShortcutChangedNotification" object:self];
}

- (void)shortcutRecorder:(SplitShortcutRecorder *)shortcutRecorder didClearExistingShortcut:(SplitShortcut *)shortcut
{
  [_shortcutManager clearShortcut:shortcut];
  [NSNotificationCenter.defaultCenter postNotificationName:@"SplitShortcutChangedNotification" object:self];
}

- (void)restoreDefaults:(id)sender
{
  [SplitUtilities displayRestoreDefaultsAlertWithConfirmationCallback:^{
    [self->_shortcutManager updateShortcuts:SplitDefaultShortcutsWithAction([self shortcutAction])];
    [NSNotificationCenter.defaultCenter postNotificationName:@"SplitRestoreDefaultShortcutsNotification" object:self];
  }];
}

- (void)dealloc
{
  [_permissionTimer invalidate];
  [NSNotificationCenter.defaultCenter removeObserver:self];
}

@end
