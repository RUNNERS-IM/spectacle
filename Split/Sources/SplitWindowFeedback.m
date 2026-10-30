#import "SplitWindowFeedback.h"

#import "SplitUtilities.h"

#import <QuartzCore/QuartzCore.h>

static const CGFloat kPreviewCornerRadius = 12.0;

NSString *const SplitMoveFeedbackStyleKey = @"MoveFeedbackStyle";
NSString *const SplitMoveFeedbackColorKey = @"MoveFeedbackColor";
NSString *const SplitMoveFeedbackShowsShortcutKey = @"MoveFeedbackShowsShortcut";
NSString *const SplitMoveFeedbackDurationKey = @"MoveFeedbackDuration";
NSString *const SplitMoveFeedbackLabelPositionKey = @"MoveFeedbackLabelPosition";

NSArray<NSString *> *SplitMoveFeedbackColorNames(void)
{
  return @[@"accent", @"blue", @"purple", @"pink", @"orange", @"green", @"gray"];
}

NSColor *SplitMoveFeedbackColorForName(NSString *name)
{
  NSDictionary<NSString *, NSColor *> *colors = @{
    @"blue": NSColor.systemBlueColor,
    @"purple": NSColor.systemPurpleColor,
    @"pink": NSColor.systemPinkColor,
    @"orange": NSColor.systemOrangeColor,
    @"green": NSColor.systemGreenColor,
    @"gray": NSColor.systemGrayColor,
  };
  return colors[name] ?: NSColor.controlAccentColor;
}

/// Glow and label measurements for one strength. Strong is how 1.1 looked.
typedef struct {
  CGFloat borderWidth;
  CGFloat shadowRadius;
  CGFloat shadowOpacity;
  CGFloat startOpacity;
  CGFloat growScale;
  NSTimeInterval glowDuration;
  CGFloat fontSize;
  CGFloat labelHeight;
  CGFloat labelMinWidth;
  CGFloat labelCornerRadius;
  CGFloat labelOpacity;
  NSTimeInterval labelVisibleDuration;
} SplitFeedbackMetrics;

static SplitFeedbackMetrics MetricsForStyle(SplitMoveFeedbackStyle style)
{
  if (style == SplitMoveFeedbackStyleStrong) {
    return (SplitFeedbackMetrics){2.5, 10.0, 0.9, 1.0, 1.03, 0.65, 15.0, 44.0, 180.0, 14.0, 1.0, 0.9};
  }
  return (SplitFeedbackMetrics){1.5, 4.0, 0.5, 0.6, 1.0, 0.4, 13.0, 32.0, 0.0, 10.0, 0.85, 0.6};
}

static NSTimeInterval DurationScale(void)
{
  switch (SplitWindowFeedback.moveFeedbackDuration) {
    case SplitMoveFeedbackDurationShort: return 0.6;
    case SplitMoveFeedbackDurationLong: return 1.6;
    default: return 1.0;
  }
}

/// Accessibility rectangles start at the top-left of the primary screen; Cocoa windows start at
/// its bottom-left.
static NSRect CocoaRectFromAccessibilityRect(CGRect rect)
{
  CGFloat primaryHeight = NSScreen.screens.firstObject.frame.size.height;
  return NSMakeRect(rect.origin.x, primaryHeight - CGRectGetMaxY(rect), rect.size.width, rect.size.height);
}

static NSWindow *MakeOverlayWindow(void)
{
  NSWindow *window = [[NSWindow alloc] initWithContentRect:NSZeroRect
                                                 styleMask:NSWindowStyleMaskBorderless
                                                   backing:NSBackingStoreBuffered
                                                     defer:YES];
  window.opaque = NO;
  window.backgroundColor = NSColor.clearColor;
  window.hasShadow = NO;
  window.ignoresMouseEvents = YES;
  window.releasedWhenClosed = NO;
  window.level = NSStatusWindowLevel;
  window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces
    | NSWindowCollectionBehaviorFullScreenAuxiliary
    | NSWindowCollectionBehaviorTransient
    | NSWindowCollectionBehaviorIgnoresCycle;
  NSView *view = [NSView new];
  view.wantsLayer = YES;
  window.contentView = view;
  return window;
}

@implementation SplitWindowFeedback
{
  NSWindow *_previewWindow;
  NSWindow *_glowWindow;
  NSPanel *_labelPanel;
  NSTextField *_labelField;
  NSUInteger _labelGeneration;
  BOOL _previewShowsTiles;
}

+ (SplitMoveFeedbackStyle)moveFeedbackStyle
{
  NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
  NSNumber *value = [defaults objectForKey:SplitMoveFeedbackStyleKey];
  if (value) {
    return MIN(MAX(value.integerValue, SplitMoveFeedbackStyleOff), SplitMoveFeedbackStyleStrong);
  }
  NSNumber *legacy = [defaults objectForKey:@"MoveFeedbackEnabled"];
  return legacy && !legacy.boolValue ? SplitMoveFeedbackStyleOff : SplitMoveFeedbackStyleSubtle;
}

+ (BOOL)moveFeedbackEnabled
{
  return self.moveFeedbackStyle != SplitMoveFeedbackStyleOff;
}

+ (NSString *)moveFeedbackColorName
{
  NSString *name = [NSUserDefaults.standardUserDefaults stringForKey:SplitMoveFeedbackColorKey];
  return [SplitMoveFeedbackColorNames() containsObject:name] ? name : @"accent";
}

+ (BOOL)moveFeedbackShowsShortcut
{
  NSNumber *value = [NSUserDefaults.standardUserDefaults objectForKey:SplitMoveFeedbackShowsShortcutKey];
  return value ? value.boolValue : YES;
}

+ (SplitMoveFeedbackDuration)moveFeedbackDuration
{
  NSNumber *value = [NSUserDefaults.standardUserDefaults objectForKey:SplitMoveFeedbackDurationKey];
  return value ? MIN(MAX(value.integerValue, SplitMoveFeedbackDurationShort), SplitMoveFeedbackDurationLong) : SplitMoveFeedbackDurationNormal;
}

+ (SplitMoveFeedbackLabelPosition)moveFeedbackLabelPosition
{
  NSNumber *value = [NSUserDefaults.standardUserDefaults objectForKey:SplitMoveFeedbackLabelPositionKey];
  return value ? MIN(MAX(value.integerValue, SplitMoveFeedbackLabelPositionBottom), SplitMoveFeedbackLabelPositionCenter) : SplitMoveFeedbackLabelPositionBottom;
}

static NSColor *FeedbackColor(void)
{
  return SplitMoveFeedbackColorForName(SplitWindowFeedback.moveFeedbackColorName);
}

#pragma mark - Preview

- (void)showPreviewForRect:(CGRect)rect
{
  if (CGRectIsNull(rect) || CGRectIsEmpty(rect)) {
    [self hidePreview];
    return;
  }
  if (!_previewWindow) {
    _previewWindow = MakeOverlayWindow();
    _previewShowsTiles = YES;
  }
  if (_previewShowsTiles) {
    // Back to a single outline after showing auto-arrange tiles.
    CALayer *layer = _previewWindow.contentView.layer;
    layer.sublayers = nil;
    layer.cornerRadius = kPreviewCornerRadius;
    layer.borderWidth = 2.0;
    _previewShowsTiles = NO;
    [_previewWindow orderOut:nil];
  }
  // The color can change in Settings between two previews.
  CALayer *layer = _previewWindow.contentView.layer;
  layer.borderColor = [FeedbackColor() colorWithAlphaComponent:0.95].CGColor;
  layer.backgroundColor = [FeedbackColor() colorWithAlphaComponent:0.22].CGColor;
  NSRect frame = CocoaRectFromAccessibilityRect(rect);
  BOOL wasVisible = _previewWindow.isVisible;
  if (!wasVisible) {
    _previewWindow.alphaValue = 0.0;
    [_previewWindow setFrame:frame display:NO];
    [_previewWindow orderFrontRegardless];
  }
  [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
    context.duration = wasVisible ? 0.18 : 0.12;
    context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    [self->_previewWindow.animator setFrame:frame display:YES];
    self->_previewWindow.animator.alphaValue = 1.0;
  }];
}

- (void)hidePreview
{
  if (!_previewWindow.isVisible) {
    return;
  }
  NSWindow *window = _previewWindow;
  [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
    context.duration = 0.12;
    window.animator.alphaValue = 0.0;
  } completionHandler:^{
    if (window.alphaValue < 0.01) {
      [window orderOut:nil];
    }
  }];
}

#pragma mark - After a move

- (void)showMoveFeedbackForRect:(CGRect)rect title:(NSString *)title shortcut:(NSString *)shortcut
{
  [self showMoveFeedbackForRect:rect title:title shortcut:shortcut tip:nil];
}

- (void)showMoveFeedbackForRect:(CGRect)rect title:(NSString *)title shortcut:(NSString *)shortcut tip:(NSString *)tip
{
  if (!SplitWindowFeedback.moveFeedbackEnabled || CGRectIsNull(rect)) {
    return;
  }
  [self hidePreview];
  [self glowAtRect:rect];
  if (SplitWindowFeedback.moveFeedbackShowsShortcut) {
    [self showLabel:title shortcut:shortcut tip:tip onScreenContainingRect:CocoaRectFromAccessibilityRect(rect)];
  }
}

- (void)glowAtRect:(CGRect)rect
{
  [self glowAtRects:@[[NSValue valueWithRect:NSRectFromCGRect(rect)]]];
}

static NSRect UnionOfAccessibilityRects(NSArray<NSValue *> *rects)
{
  NSRect frame = NSZeroRect;
  for (NSValue *value in rects) {
    NSRect cocoa = CocoaRectFromAccessibilityRect(NSRectToCGRect(value.rectValue));
    frame = NSIsEmptyRect(frame) ? cocoa : NSUnionRect(frame, cocoa);
  }
  return frame;
}

- (void)glowAtRects:(NSArray<NSValue *> *)rects
{
  if (rects.count == 0) {
    return;
  }
  SplitFeedbackMetrics metrics = MetricsForStyle(SplitWindowFeedback.moveFeedbackStyle);
  NSTimeInterval duration = metrics.glowDuration * DurationScale();
  NSColor *color = FeedbackColor();
  NSColor *ringColor = [[color colorUsingColorSpace:NSColorSpace.sRGBColorSpace] blendedColorWithFraction:0.4 ofColor:NSColor.whiteColor] ?: color;
  if (!_glowWindow) {
    _glowWindow = MakeOverlayWindow();
  }
  NSRect frame = NSInsetRect(UnionOfAccessibilityRects(rects), -12.0, -12.0);
  [_glowWindow setFrame:frame display:NO];
  CALayer *root = _glowWindow.contentView.layer;
  root.sublayers = nil;
  CABasicAnimation *grow = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
  grow.fromValue = @1.0;
  grow.toValue = @(metrics.growScale);
  CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
  fade.fromValue = @(metrics.startOpacity);
  fade.toValue = @0.0;
  CAAnimationGroup *group = [CAAnimationGroup animation];
  group.animations = @[grow, fade];
  group.duration = duration;
  group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
  group.fillMode = kCAFillModeForwards;
  group.removedOnCompletion = NO;
  for (NSValue *value in rects) {
    NSRect cocoa = CocoaRectFromAccessibilityRect(NSRectToCGRect(value.rectValue));
    CALayer *ring = [CALayer layer];
    CGFloat inset = rects.count > 1 ? 3.0 : 0.0;
    ring.frame = NSInsetRect(NSOffsetRect(cocoa, -NSMinX(frame), -NSMinY(frame)), inset, inset);
    ring.cornerRadius = kPreviewCornerRadius;
    ring.borderWidth = metrics.borderWidth;
    ring.borderColor = ringColor.CGColor;
    ring.shadowColor = color.CGColor;
    ring.shadowRadius = metrics.shadowRadius;
    ring.shadowOpacity = metrics.shadowOpacity;
    ring.shadowOffset = CGSizeZero;
    [root addSublayer:ring];
    [ring addAnimation:group forKey:@"glow"];
  }
  _glowWindow.alphaValue = 1.0;
  [_glowWindow orderFrontRegardless];

  NSWindow *window = _glowWindow;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [window orderOut:nil];
  });
}

- (void)showMoveFeedbackForRects:(NSArray<NSValue *> *)rects title:(NSString *)title shortcut:(NSString *)shortcut
{
  [self showMoveFeedbackForRects:rects title:title shortcut:shortcut tip:nil];
}

- (void)showMoveFeedbackForRects:(NSArray<NSValue *> *)rects title:(NSString *)title shortcut:(NSString *)shortcut tip:(NSString *)tip
{
  [self hidePreview];
  if (!SplitWindowFeedback.moveFeedbackEnabled || rects.count == 0) {
    return;
  }
  [self glowAtRects:rects];
  if (SplitWindowFeedback.moveFeedbackShowsShortcut) {
    [self showLabel:title shortcut:shortcut tip:tip onScreenContainingRect:UnionOfAccessibilityRects(rects)];
  }
}

- (void)showLabel:(NSString *)title shortcut:(NSString *)shortcut
{
  [self showLabel:title shortcut:shortcut tip:nil];
}

- (void)showLabel:(NSString *)title shortcut:(NSString *)shortcut tip:(NSString *)tip
{
  NSScreen *screen = NSScreen.mainScreen ?: NSScreen.screens.firstObject;
  [self showLabel:title shortcut:shortcut tip:tip onScreenContainingRect:screen.frame];
}

- (void)showPreviewForRects:(NSArray<NSValue *> *)rects
{
  if (rects.count == 0) {
    [self hidePreview];
    return;
  }
  if (rects.count == 1) {
    [self showPreviewForRect:NSRectToCGRect(rects.firstObject.rectValue)];
    return;
  }
  if (!_previewWindow) {
    _previewWindow = MakeOverlayWindow();
  }
  NSRect frame = UnionOfAccessibilityRects(rects);
  CALayer *root = _previewWindow.contentView.layer;
  root.cornerRadius = 0;
  root.borderWidth = 0;
  root.backgroundColor = NSColor.clearColor.CGColor;
  root.sublayers = nil;
  for (NSValue *value in rects) {
    NSRect cocoa = CocoaRectFromAccessibilityRect(NSRectToCGRect(value.rectValue));
    CALayer *tile = [CALayer layer];
    tile.frame = NSInsetRect(NSOffsetRect(cocoa, -NSMinX(frame), -NSMinY(frame)), 4.0, 4.0);
    tile.cornerRadius = kPreviewCornerRadius;
    tile.borderWidth = 2.0;
    tile.borderColor = [FeedbackColor() colorWithAlphaComponent:0.95].CGColor;
    tile.backgroundColor = [FeedbackColor() colorWithAlphaComponent:0.18].CGColor;
    [root addSublayer:tile];
  }
  _previewShowsTiles = YES;
  [_previewWindow setFrame:frame display:YES];
  _previewWindow.alphaValue = 1.0;
  [_previewWindow orderFrontRegardless];
}

- (void)showLabel:(NSString *)title shortcut:(NSString *)shortcut tip:(NSString *)tip onScreenContainingRect:(NSRect)rect
{
  if (!_labelPanel) {
    _labelPanel = [[NSPanel alloc] initWithContentRect:NSZeroRect
                                             styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                               backing:NSBackingStoreBuffered
                                                 defer:YES];
    _labelPanel.opaque = NO;
    _labelPanel.backgroundColor = NSColor.clearColor;
    _labelPanel.hasShadow = YES;
    _labelPanel.ignoresMouseEvents = YES;
    _labelPanel.level = NSStatusWindowLevel;
    _labelPanel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
    NSVisualEffectView *background = [NSVisualEffectView new];
    background.material = NSVisualEffectMaterialHUDWindow;
    background.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    background.state = NSVisualEffectStateActive;
    background.wantsLayer = YES;
    background.layer.cornerRadius = 14.0;
    background.layer.masksToBounds = YES;
    _labelField = [NSTextField labelWithString:@""];
    _labelField.alignment = NSTextAlignmentCenter;
    _labelField.usesSingleLineMode = NO;
    _labelField.maximumNumberOfLines = 2;
    _labelField.textColor = NSColor.labelColor;
    _labelField.translatesAutoresizingMaskIntoConstraints = NO;
    [background addSubview:_labelField];
    [NSLayoutConstraint activateConstraints:@[
      [_labelField.centerXAnchor constraintEqualToAnchor:background.centerXAnchor],
      [_labelField.centerYAnchor constraintEqualToAnchor:background.centerYAnchor],
    ]];
    _labelPanel.contentView = background;
  }
  SplitFeedbackMetrics metrics = MetricsForStyle(SplitWindowFeedback.moveFeedbackStyle);
  _labelPanel.contentView.layer.cornerRadius = metrics.labelCornerRadius;
  _labelField.font = [NSFont systemFontOfSize:metrics.fontSize weight:NSFontWeightSemibold];
  NSString *text = shortcut.length > 0 ? [NSString stringWithFormat:@"%@   %@", shortcut, title] : title;
  NSMutableParagraphStyle *centered = [NSMutableParagraphStyle new];
  centered.alignment = NSTextAlignmentCenter;
  NSMutableAttributedString *attributed = [[NSMutableAttributedString alloc] initWithString:text attributes:@{
    NSFontAttributeName: [NSFont systemFontOfSize:metrics.fontSize weight:NSFontWeightSemibold],
    NSForegroundColorAttributeName: NSColor.labelColor,
    NSParagraphStyleAttributeName: centered,
  }];
  CGFloat tipHeight = 0;
  if (tip.length > 0) {
    [attributed appendAttributedString:[[NSAttributedString alloc] initWithString:[@"\n" stringByAppendingString:tip] attributes:@{
      NSFontAttributeName: [NSFont systemFontOfSize:metrics.fontSize - 2.0],
      NSForegroundColorAttributeName: NSColor.secondaryLabelColor,
      NSParagraphStyleAttributeName: centered,
    }]];
    tipHeight = metrics.fontSize + 6.0;
  }
  _labelField.attributedStringValue = attributed;
  CGFloat padding = metrics.labelHeight < 40.0 ? 28.0 : 40.0;
  NSSize size = NSMakeSize(MAX(metrics.labelMinWidth, _labelField.intrinsicContentSize.width + padding), metrics.labelHeight + tipHeight);

  NSScreen *screen = NSScreen.mainScreen;
  for (NSScreen *candidate in NSScreen.screens) {
    if (NSIntersectsRect(candidate.frame, rect)) {
      screen = candidate;
      break;
    }
  }
  NSRect visible = screen.visibleFrame;
  CGFloat y = NSMinY(visible) + 64.0;
  if (SplitWindowFeedback.moveFeedbackLabelPosition == SplitMoveFeedbackLabelPositionTop) {
    y = NSMaxY(visible) - 64.0 - size.height;
  } else if (SplitWindowFeedback.moveFeedbackLabelPosition == SplitMoveFeedbackLabelPositionCenter) {
    y = NSMidY(visible) - size.height / 2.0;
  }
  NSRect frame = NSMakeRect(NSMidX(visible) - size.width / 2.0, y, size.width, size.height);
  [_labelPanel setFrame:frame display:YES];
  _labelPanel.alphaValue = 0.0;
  [_labelPanel orderFrontRegardless];
  [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
    context.duration = 0.12;
    self->_labelPanel.animator.alphaValue = metrics.labelOpacity;
  }];
  NSUInteger generation = ++_labelGeneration;
  // A tip needs a moment longer to read.
  NSTimeInterval visibleTime = metrics.labelVisibleDuration * DurationScale() + (tip.length > 0 ? 1.6 : 0.0);
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(visibleTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    if (generation != self->_labelGeneration) {
      return;
    }
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
      context.duration = 0.25;
      self->_labelPanel.animator.alphaValue = 0.0;
    } completionHandler:^{
      if (generation == self->_labelGeneration) {
        [self->_labelPanel orderOut:nil];
      }
    }];
  });
}

@end

#pragma mark - Shortcut sheet

static const NSTimeInterval kSheetHoldDelay = 1.0;

@implementation SplitShortcutSheet
{
  NSArray<NSArray *> *_sections;
  NSString *_Nullable (^_keysForName)(NSString *);
  NSPanel *_panel;
  NSTimer *_holdTimer;
  NSMutableArray *_monitors;
  id _dismissMonitor;
  BOOL _shownByHold;
}

+ (BOOL)holdToShowEnabled
{
  NSNumber *value = [NSUserDefaults.standardUserDefaults objectForKey:@"ShortcutSheetEnabled"];
  return value ? value.boolValue : YES;
}

- (instancetype)initWithSections:(NSArray<NSArray *> *)sections keysForName:(NSString *(^)(NSString *))keysForName
{
  if (self = [super init]) {
    _sections = sections;
    _keysForName = [keysForName copy];
    _monitors = [NSMutableArray new];
  }
  return self;
}

static BOOL OnlyOptionAndCommand(NSEventModifierFlags flags)
{
  flags &= NSEventModifierFlagShift | NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagCommand;
  return flags == (NSEventModifierFlagOption | NSEventModifierFlagCommand);
}

- (void)startWatchingModifiers
{
  if (_monitors.count > 0) {
    return;
  }
  __weak typeof(self) weakSelf = self;
  void (^flags)(NSEvent *) = ^(NSEvent *event) {
    [weakSelf modifiersChanged:event.modifierFlags];
  };
  void (^other)(NSEvent *) = ^(NSEvent *event) {
    [weakSelf cancelHold];
  };
  NSEventMask otherMask = NSEventMaskKeyDown | NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown | NSEventMaskScrollWheel;
  id globalFlags = [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskFlagsChanged handler:flags];
  id globalOther = [NSEvent addGlobalMonitorForEventsMatchingMask:otherMask handler:other];
  id localFlags = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskFlagsChanged handler:^NSEvent *(NSEvent *event) {
    flags(event);
    return event;
  }];
  id localOther = [NSEvent addLocalMonitorForEventsMatchingMask:otherMask handler:^NSEvent *(NSEvent *event) {
    other(event);
    return event;
  }];
  for (id monitor in @[globalFlags ?: NSNull.null, globalOther ?: NSNull.null, localFlags ?: NSNull.null, localOther ?: NSNull.null]) {
    if (monitor != NSNull.null) {
      [_monitors addObject:monitor];
    }
  }
}

- (void)modifiersChanged:(NSEventModifierFlags)flags
{
  if (OnlyOptionAndCommand(flags) && SplitShortcutSheet.holdToShowEnabled) {
    [_holdTimer invalidate];
    _holdTimer = [NSTimer scheduledTimerWithTimeInterval:kSheetHoldDelay repeats:NO block:^(NSTimer *timer) {
      [self showFromHold];
    }];
  } else {
    [self cancelHold];
  }
}

/// Any key or click: the user went on to use a shortcut, so the card is not needed.
- (void)cancelHold
{
  [_holdTimer invalidate];
  _holdTimer = nil;
  if (_shownByHold) {
    [self hide];
  }
}

- (void)showFromHold
{
  _holdTimer = nil;
  if (NSEvent.pressedMouseButtons != 0 || !OnlyOptionAndCommand(NSEvent.modifierFlags)) {
    return;
  }
  [self present];
  _shownByHold = YES;
}

- (void)show
{
  [self present];
  _shownByHold = NO;
  if (!_dismissMonitor) {
    __weak typeof(self) weakSelf = self;
    _dismissMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskKeyDown | NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown
                                                             handler:^(NSEvent *event) {
      [weakSelf hide];
    }];
  }
}

- (void)hide
{
  _shownByHold = NO;
  if (_dismissMonitor) {
    [NSEvent removeMonitor:_dismissMonitor];
    _dismissMonitor = nil;
  }
  if (!_panel.isVisible) {
    return;
  }
  NSPanel *panel = _panel;
  [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
    context.duration = 0.12;
    panel.animator.alphaValue = 0.0;
  } completionHandler:^{
    if (panel.alphaValue < 0.01) {
      [panel orderOut:nil];
    }
  }];
}

static NSTextField *SheetLabel(NSString *text, CGFloat size, NSFontWeight weight, NSColor *color)
{
  NSTextField *label = [NSTextField labelWithString:text ?: @""];
  label.font = [NSFont systemFontOfSize:size weight:weight];
  label.textColor = color;
  label.translatesAutoresizingMaskIntoConstraints = NO;
  return label;
}

- (NSView *)rowForShortcutName:(NSString *)name
{
  NSImageView *picture = [NSImageView imageViewWithImage:SplitMenuImageForShortcutName(name) ?: [NSImage new]];
  picture.contentTintColor = NSColor.secondaryLabelColor;
  picture.imageScaling = NSImageScaleProportionallyUpOrDown;
  picture.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [picture.widthAnchor constraintEqualToConstant:20],
    [picture.heightAnchor constraintEqualToConstant:14],
  ]];
  NSTextField *title = SheetLabel(SplitLocalized(name), 12, NSFontWeightRegular, NSColor.labelColor);
  NSTextField *keys = SheetLabel(_keysForName(name) ?: @"—", 12, NSFontWeightMedium, NSColor.secondaryLabelColor);
  NSView *space = [NSView new];
  space.translatesAutoresizingMaskIntoConstraints = NO;
  [space setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSStackView *row = [NSStackView stackViewWithViews:@[picture, title, space, keys]];
  row.spacing = 8;
  row.translatesAutoresizingMaskIntoConstraints = NO;
  [row.widthAnchor constraintEqualToConstant:220].active = YES;
  return row;
}

- (NSView *)makeContent
{
  NSMutableArray<NSStackView *> *columns = [NSMutableArray new];
  for (NSUInteger index = 0; index < 3; index++) {
    NSStackView *column = [NSStackView stackViewWithViews:@[]];
    column.orientation = NSUserInterfaceLayoutOrientationVertical;
    column.alignment = NSLayoutAttributeLeading;
    column.spacing = 4;
    column.translatesAutoresizingMaskIntoConstraints = NO;
    [columns addObject:column];
  }
  // Fill columns in turn by height so they come out about even.
  NSUInteger heights[3] = {0, 0, 0};
  for (NSArray *section in _sections) {
    NSUInteger target = 0;
    for (NSUInteger index = 1; index < 3; index++) {
      if (heights[index] < heights[target]) {
        target = index;
      }
    }
    NSStackView *column = columns[target];
    NSTextField *header = SheetLabel(SplitLocalized(section[0]), 10, NSFontWeightSemibold, NSColor.tertiaryLabelColor);
    [column addArrangedSubview:header];
    if (column.arrangedSubviews.count > 1) {
      [column setCustomSpacing:10 afterView:column.arrangedSubviews[column.arrangedSubviews.count - 2]];
    }
    for (NSString *name in section[2]) {
      [column addArrangedSubview:[self rowForShortcutName:name]];
    }
    heights[target] += [section[2] count] + 1;
  }
  NSStackView *grid = [NSStackView stackViewWithViews:columns];
  grid.alignment = NSLayoutAttributeTop;
  grid.spacing = 22;
  grid.translatesAutoresizingMaskIntoConstraints = NO;

  NSTextField *title = SheetLabel(SplitLocalized(@"ShortcutSheetTitle"), 14, NSFontWeightBold, NSColor.labelColor);
  NSTextField *hint = SheetLabel(SplitLocalized(@"ShortcutSheetHint"), 11, NSFontWeightRegular, NSColor.secondaryLabelColor);
  NSView *space = [NSView new];
  space.translatesAutoresizingMaskIntoConstraints = NO;
  [space setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSStackView *head = [NSStackView stackViewWithViews:@[title, space, hint]];
  head.translatesAutoresizingMaskIntoConstraints = NO;

  NSStackView *content = [NSStackView stackViewWithViews:@[head, grid]];
  content.orientation = NSUserInterfaceLayoutOrientationVertical;
  content.alignment = NSLayoutAttributeLeading;
  content.spacing = 12;
  content.translatesAutoresizingMaskIntoConstraints = NO;
  [head.widthAnchor constraintEqualToAnchor:grid.widthAnchor].active = YES;

  NSVisualEffectView *background = [NSVisualEffectView new];
  background.material = NSVisualEffectMaterialHUDWindow;
  background.blendingMode = NSVisualEffectBlendingModeBehindWindow;
  background.state = NSVisualEffectStateActive;
  background.wantsLayer = YES;
  background.layer.cornerRadius = 16.0;
  background.layer.masksToBounds = YES;
  [background addSubview:content];
  [NSLayoutConstraint activateConstraints:@[
    [content.topAnchor constraintEqualToAnchor:background.topAnchor constant:18],
    [content.bottomAnchor constraintEqualToAnchor:background.bottomAnchor constant:-18],
    [content.leadingAnchor constraintEqualToAnchor:background.leadingAnchor constant:22],
    [content.trailingAnchor constraintEqualToAnchor:background.trailingAnchor constant:-22],
  ]];
  return background;
}

- (void)present
{
  // Built every time so changed shortcuts show up.
  NSView *content = [self makeContent];
  if (!_panel) {
    _panel = [[NSPanel alloc] initWithContentRect:NSZeroRect
                                        styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                          backing:NSBackingStoreBuffered
                                            defer:YES];
    _panel.opaque = NO;
    _panel.backgroundColor = NSColor.clearColor;
    _panel.hasShadow = YES;
    _panel.ignoresMouseEvents = YES;
    _panel.level = NSStatusWindowLevel;
    _panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
  }
  _panel.contentView = content;
  NSSize size = content.fittingSize;
  NSScreen *screen = NSScreen.mainScreen;
  NSPoint mouse = NSEvent.mouseLocation;
  for (NSScreen *candidate in NSScreen.screens) {
    if (NSPointInRect(mouse, candidate.frame)) {
      screen = candidate;
      break;
    }
  }
  NSRect visible = screen.visibleFrame;
  [_panel setFrame:NSMakeRect(NSMidX(visible) - size.width / 2.0, NSMidY(visible) - size.height / 2.0, size.width, size.height) display:YES];
  _panel.alphaValue = 0.0;
  [_panel orderFrontRegardless];
  [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
    context.duration = 0.15;
    self->_panel.animator.alphaValue = 1.0;
  }];
}

- (void)dealloc
{
  for (id monitor in _monitors) {
    [NSEvent removeMonitor:monitor];
  }
  if (_dismissMonitor) {
    [NSEvent removeMonitor:_dismissMonitor];
  }
}

@end

#pragma mark - Menu images

/// Fractions of the screen (x, y from the top-left, width, height) for each shortcut.
static NSDictionary<NSString *, NSValue *> *ScreenRegions(void)
{
  static NSDictionary *regions;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    regions = @{
      @"MoveToCenter": [NSValue valueWithRect:NSMakeRect(0.25, 0.22, 0.5, 0.56)],
      @"MoveToFullscreen": [NSValue valueWithRect:NSMakeRect(0, 0, 1, 1)],
      @"MoveToLeftHalf": [NSValue valueWithRect:NSMakeRect(0, 0, 0.5, 1)],
      @"MoveToRightHalf": [NSValue valueWithRect:NSMakeRect(0.5, 0, 0.5, 1)],
      @"MoveToTopHalf": [NSValue valueWithRect:NSMakeRect(0, 0, 1, 0.5)],
      @"MoveToBottomHalf": [NSValue valueWithRect:NSMakeRect(0, 0.5, 1, 0.5)],
      @"MoveToUpperLeft": [NSValue valueWithRect:NSMakeRect(0, 0, 0.5, 0.5)],
      @"MoveToLowerLeft": [NSValue valueWithRect:NSMakeRect(0, 0.5, 0.5, 0.5)],
      @"MoveToUpperRight": [NSValue valueWithRect:NSMakeRect(0.5, 0, 0.5, 0.5)],
      @"MoveToLowerRight": [NSValue valueWithRect:NSMakeRect(0.5, 0.5, 0.5, 0.5)],
      @"MoveToNextThird": [NSValue valueWithRect:NSMakeRect(0.34, 0, 0.32, 1)],
      @"MoveToPreviousThird": [NSValue valueWithRect:NSMakeRect(0, 0, 0.32, 1)],
    };
  });
  return regions;
}

static NSDictionary<NSString *, NSString *> *IconNames(void)
{
  return @{
    @"MoveToNextDisplay": @"square-arrow-right",
    @"MoveToPreviousDisplay": @"square-arrow-left",
    @"MakeLarger": @"maximize-2",
    @"MakeSmaller": @"minimize-2",
    @"UndoLastMove": @"undo-2",
    @"RedoLastMove": @"redo-2",
  };
}

static NSImage *MiniScreenImage(NSArray<NSValue *> *fractions)
{
  return SplitMiniScreenImage(fractions, NSMakeSize(22.0, 15.0));
}

NSImage *SplitMiniScreenImage(NSArray<NSValue *> *fractions, NSSize size)
{
  NSImage *image = [NSImage imageWithSize:size flipped:YES drawingHandler:^BOOL(NSRect dstRect) {
    NSRect screen = NSInsetRect(dstRect, 0.75, 0.75);
    NSBezierPath *outline = [NSBezierPath bezierPathWithRoundedRect:screen xRadius:2.5 yRadius:2.5];
    outline.lineWidth = 1.3;
    [[NSColor colorWithWhite:0 alpha:0.55] setStroke];
    [outline stroke];
    NSRect inner = NSInsetRect(screen, 2.0, 2.0);
    for (NSValue *value in fractions) {
      NSRect fraction = value.rectValue;
      NSRect fill = NSMakeRect(NSMinX(inner) + fraction.origin.x * NSWidth(inner),
                               NSMinY(inner) + fraction.origin.y * NSHeight(inner),
                               fraction.size.width * NSWidth(inner),
                               fraction.size.height * NSHeight(inner));
      fill = NSInsetRect(fill, fractions.count > 1 ? 0.6 : 0.4, fractions.count > 1 ? 0.6 : 0.4);
      [[NSColor blackColor] setFill];
      [[NSBezierPath bezierPathWithRoundedRect:fill xRadius:1.2 yRadius:1.2] fill];
    }
    return YES;
  }];
  image.template = YES;
  return image;
}

NSImage *SplitMenuImageForShortcutName(NSString *shortcutName)
{
  if ([shortcutName isEqualToString:@"ArrangeWindows"]) {
    // One big window on the left and two stacked on the right, like three arranged windows.
    return MiniScreenImage(@[
      [NSValue valueWithRect:NSMakeRect(0, 0, 0.5, 1)],
      [NSValue valueWithRect:NSMakeRect(0.5, 0, 0.5, 0.5)],
      [NSValue valueWithRect:NSMakeRect(0.5, 0.5, 0.5, 0.5)],
    ]);
  }
  NSValue *region = ScreenRegions()[shortcutName];
  if (!region) {
    NSString *icon = IconNames()[shortcutName];
    return icon ? SplitIcon(icon, 16) : nil;
  }
  return MiniScreenImage(@[region]);
}
