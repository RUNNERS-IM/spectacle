#import "SplitWindowFeedback.h"

#import <QuartzCore/QuartzCore.h>

static const CGFloat kPreviewCornerRadius = 12.0;
static const NSTimeInterval kGlowDuration = 0.65;
static const NSTimeInterval kLabelVisibleDuration = 0.9;

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
}

+ (BOOL)moveFeedbackEnabled
{
  NSNumber *value = [NSUserDefaults.standardUserDefaults objectForKey:@"MoveFeedbackEnabled"];
  return value ? value.boolValue : YES;
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
    CALayer *layer = _previewWindow.contentView.layer;
    layer.cornerRadius = kPreviewCornerRadius;
    layer.borderWidth = 2.0;
    layer.borderColor = [NSColor.systemBlueColor colorWithAlphaComponent:0.95].CGColor;
    layer.backgroundColor = [NSColor.systemBlueColor colorWithAlphaComponent:0.22].CGColor;
  }
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
  if (!SplitWindowFeedback.moveFeedbackEnabled || CGRectIsNull(rect)) {
    return;
  }
  [self hidePreview];
  [self glowAtRect:rect];
  [self showLabel:title shortcut:shortcut onScreenContainingRect:CocoaRectFromAccessibilityRect(rect)];
}

- (void)glowAtRect:(CGRect)rect
{
  if (!_glowWindow) {
    _glowWindow = MakeOverlayWindow();
  }
  NSRect frame = NSInsetRect(CocoaRectFromAccessibilityRect(rect), -12.0, -12.0);
  [_glowWindow setFrame:frame display:NO];
  CALayer *root = _glowWindow.contentView.layer;
  root.sublayers = nil;
  CALayer *ring = [CALayer layer];
  ring.frame = NSInsetRect(_glowWindow.contentView.bounds, 12.0, 12.0);
  ring.cornerRadius = kPreviewCornerRadius;
  ring.borderWidth = 2.5;
  ring.borderColor = [NSColor colorWithSRGBRed:0.58 green:0.77 blue:0.99 alpha:1.0].CGColor;
  ring.shadowColor = NSColor.systemBlueColor.CGColor;
  ring.shadowRadius = 10.0;
  ring.shadowOpacity = 0.9;
  ring.shadowOffset = CGSizeZero;
  [root addSublayer:ring];
  _glowWindow.alphaValue = 1.0;
  [_glowWindow orderFrontRegardless];

  CABasicAnimation *grow = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
  grow.fromValue = @1.0;
  grow.toValue = @1.03;
  CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
  fade.fromValue = @1.0;
  fade.toValue = @0.0;
  CAAnimationGroup *group = [CAAnimationGroup animation];
  group.animations = @[grow, fade];
  group.duration = kGlowDuration;
  group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
  group.fillMode = kCAFillModeForwards;
  group.removedOnCompletion = NO;
  [ring addAnimation:group forKey:@"glow"];

  NSWindow *window = _glowWindow;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kGlowDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [window orderOut:nil];
  });
}

- (void)showLabel:(NSString *)title shortcut:(NSString *)shortcut onScreenContainingRect:(NSRect)rect
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
    _labelField.font = [NSFont systemFontOfSize:15.0 weight:NSFontWeightSemibold];
    _labelField.textColor = NSColor.labelColor;
    _labelField.translatesAutoresizingMaskIntoConstraints = NO;
    [background addSubview:_labelField];
    [NSLayoutConstraint activateConstraints:@[
      [_labelField.centerXAnchor constraintEqualToAnchor:background.centerXAnchor],
      [_labelField.centerYAnchor constraintEqualToAnchor:background.centerYAnchor],
    ]];
    _labelPanel.contentView = background;
  }
  NSString *text = shortcut.length > 0 ? [NSString stringWithFormat:@"%@   %@", shortcut, title] : title;
  _labelField.stringValue = text;
  NSSize size = NSMakeSize(MAX(180.0, _labelField.intrinsicContentSize.width + 40.0), 44.0);

  NSScreen *screen = NSScreen.mainScreen;
  for (NSScreen *candidate in NSScreen.screens) {
    if (NSIntersectsRect(candidate.frame, rect)) {
      screen = candidate;
      break;
    }
  }
  NSRect visible = screen.visibleFrame;
  NSRect frame = NSMakeRect(NSMidX(visible) - size.width / 2.0, NSMinY(visible) + 64.0, size.width, size.height);
  [_labelPanel setFrame:frame display:YES];
  _labelPanel.alphaValue = 0.0;
  [_labelPanel orderFrontRegardless];
  [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
    context.duration = 0.12;
    self->_labelPanel.animator.alphaValue = 1.0;
  }];
  NSUInteger generation = ++_labelGeneration;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kLabelVisibleDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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

static NSDictionary<NSString *, NSString *> *SymbolNames(void)
{
  return @{
    @"MoveToNextDisplay": @"rectangle.portrait.and.arrow.right",
    @"MoveToPreviousDisplay": @"rectangle.portrait.and.arrow.right",
    @"MakeLarger": @"arrow.up.left.and.arrow.down.right",
    @"MakeSmaller": @"arrow.down.right.and.arrow.up.left",
    @"UndoLastMove": @"arrow.uturn.backward",
    @"RedoLastMove": @"arrow.uturn.forward",
  };
}

NSImage *SplitMenuImageForShortcutName(NSString *shortcutName)
{
  NSValue *region = ScreenRegions()[shortcutName];
  if (!region) {
    NSString *symbol = SymbolNames()[shortcutName];
    NSImage *image = symbol ? [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil] : nil;
    if ([shortcutName isEqualToString:@"MoveToPreviousDisplay"] && image) {
      // Mirror the next-display arrow so it points left.
      NSImage *mirrored = [NSImage imageWithSize:image.size flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        NSAffineTransform *transform = [NSAffineTransform transform];
        [transform translateXBy:dstRect.size.width yBy:0];
        [transform scaleXBy:-1 yBy:1];
        [transform concat];
        [image drawInRect:dstRect];
        return YES;
      }];
      mirrored.template = YES;
      return mirrored;
    }
    image.template = YES;
    return image;
  }
  NSRect fraction = region.rectValue;
  NSSize size = NSMakeSize(22.0, 15.0);
  NSImage *image = [NSImage imageWithSize:size flipped:YES drawingHandler:^BOOL(NSRect dstRect) {
    NSRect screen = NSInsetRect(dstRect, 0.75, 0.75);
    NSBezierPath *outline = [NSBezierPath bezierPathWithRoundedRect:screen xRadius:2.5 yRadius:2.5];
    outline.lineWidth = 1.3;
    [[NSColor colorWithWhite:0 alpha:0.55] setStroke];
    [outline stroke];
    NSRect inner = NSInsetRect(screen, 2.0, 2.0);
    NSRect fill = NSMakeRect(NSMinX(inner) + fraction.origin.x * NSWidth(inner),
                             NSMinY(inner) + fraction.origin.y * NSHeight(inner),
                             fraction.size.width * NSWidth(inner),
                             fraction.size.height * NSHeight(inner));
    fill = NSInsetRect(fill, 0.4, 0.4);
    [[NSColor blackColor] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:fill xRadius:1.2 yRadius:1.2] fill];
    return YES;
  }];
  image.template = YES;
  return image;
}
