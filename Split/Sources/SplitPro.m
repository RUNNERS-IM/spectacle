#import "SplitPro.h"

#import "SplitUtilities.h"

static const CGFloat kPillFontSize = 10.0;
static const CGFloat kPillHorizontalPadding = 6.0;
static const CGFloat kPillHeight = 16.0;
static const CGFloat kSheetWidth = 360.0;
static const CGFloat kSheetPadding = 24.0;

static NSColor *DynamicColor(NSColor *light, NSColor *dark)
{
  return [NSColor colorWithName:nil dynamicProvider:^NSColor *(NSAppearance *appearance) {
    BOOL isDark = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]] == NSAppearanceNameDarkAqua;
    return isDark ? dark : light;
  }];
}

static NSColor *PillFillColor(void)
{
  return DynamicColor([NSColor colorWithSRGBRed:1.0 green:0.91 blue:0.80 alpha:1.0],
                      [NSColor colorWithSRGBRed:0.35 green:0.23 blue:0.07 alpha:1.0]);
}

static NSColor *PillTextColor(void)
{
  return DynamicColor([NSColor colorWithSRGBRed:0.60 green:0.29 blue:0.0 alpha:1.0],
                      [NSColor colorWithSRGBRed:1.0 green:0.81 blue:0.60 alpha:1.0]);
}

static NSAttributedString *PillText(void)
{
  return [[NSAttributedString alloc] initWithString:@"Pro"
                                         attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:kPillFontSize weight:NSFontWeightBold],
                                                      NSForegroundColorAttributeName: PillTextColor()}];
}

static NSSize PillSize(void)
{
  return NSMakeSize(ceil(PillText().size.width) + 2 * kPillHorizontalPadding, kPillHeight);
}

static void DrawPill(NSRect rect)
{
  [PillFillColor() setFill];
  [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:NSHeight(rect) / 2 yRadius:NSHeight(rect) / 2] fill];
  NSAttributedString *text = PillText();
  NSSize size = text.size;
  [text drawAtPoint:NSMakePoint(NSMidX(rect) - size.width / 2, NSMidY(rect) - size.height / 2)];
}

@interface SplitProPillButton : NSButton
@end

@implementation SplitProPillButton

- (NSSize)intrinsicContentSize
{
  return PillSize();
}

- (void)drawRect:(NSRect)dirtyRect
{
  DrawPill(self.bounds);
}

- (void)resetCursorRects
{
  [self addCursorRect:self.bounds cursor:NSCursor.pointingHandCursor];
}

- (void)showProSheet:(id)sender
{
  SplitShowProSheet(self.window);
}

@end

NSButton *SplitProPill(void)
{
  SplitProPillButton *pill = [SplitProPillButton new];
  pill.bordered = NO;
  pill.title = @"";
  pill.toolTip = @"Split Pro";
  pill.target = pill;
  pill.action = @selector(showProSheet:);
  pill.translatesAutoresizingMaskIntoConstraints = NO;
  [pill setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
  return pill;
}

NSAttributedString *SplitTitleWithProPill(NSString *title, NSFont *font)
{
  NSSize size = PillSize();
  // Drawn when shown, so the pill follows the menu's light or dark look.
  NSImage *image = [NSImage imageWithSize:size flipped:NO drawingHandler:^BOOL(NSRect rect) {
    DrawPill(rect);
    return YES;
  }];
  NSTextAttachment *attachment = [NSTextAttachment new];
  attachment.image = image;
  attachment.bounds = NSMakeRect(0, round((font.capHeight - size.height) / 2), size.width, size.height);
  NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:[title stringByAppendingString:@"  "]
                                                                             attributes:@{NSFontAttributeName: font}];
  [result appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
  return result;
}

#pragma mark - The sheet

static NSTextField *SheetLabel(NSString *text, CGFloat size, NSFontWeight weight, NSColor *color)
{
  NSTextField *label = [NSTextField wrappingLabelWithString:text];
  label.font = [NSFont systemFontOfSize:size weight:weight];
  label.textColor = color;
  label.alignment = NSTextAlignmentCenter;
  label.selectable = NO;
  return label;
}

/// A price with a thin rounded border around it.
@interface SplitProPriceView : NSView
@end

@implementation SplitProPriceView

- (void)drawRect:(NSRect)dirtyRect
{
  [NSColor.separatorColor setStroke];
  NSBezierPath *border = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, 0.5, 0.5) xRadius:8 yRadius:8];
  border.lineWidth = 1.0;
  [border stroke];
}

@end

static NSView *PriceBox(NSString *text)
{
  SplitProPriceView *box = [SplitProPriceView new];
  box.translatesAutoresizingMaskIntoConstraints = NO;
  NSTextField *label = [NSTextField labelWithString:text];
  label.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
  label.translatesAutoresizingMaskIntoConstraints = NO;
  [box addSubview:label];
  [NSLayoutConstraint activateConstraints:@[
    [label.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:14],
    [label.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-14],
    [label.topAnchor constraintEqualToAnchor:box.topAnchor constant:6],
    [label.bottomAnchor constraintEqualToAnchor:box.bottomAnchor constant:-6],
  ]];
  return box;
}

@interface SplitProSheetController : NSWindowController
@end

@implementation SplitProSheetController

- (instancetype)init
{
  NSPanel *panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, kSheetWidth, 300)
                                              styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                backing:NSBackingStoreBuffered
                                                  defer:YES];
  panel.title = @"Split Pro";
  panel.releasedWhenClosed = NO;
  if (!(self = [super initWithWindow:panel])) {
    return nil;
  }

  const CGFloat contentWidth = kSheetWidth - 2 * kSheetPadding;
  NSImageView *icon = [NSImageView imageViewWithImage:NSApp.applicationIconImage ?: [NSImage new]];
  icon.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [icon.widthAnchor constraintEqualToConstant:64],
    [icon.heightAnchor constraintEqualToConstant:64],
  ]];
  NSTextField *title = SheetLabel(@"Split Pro", 17, NSFontWeightSemibold, NSColor.labelColor);
  NSTextField *features = SheetLabel(SplitLocalized(@"ProFeatures"), 12, NSFontWeightRegular, NSColor.secondaryLabelColor);
  features.preferredMaxLayoutWidth = contentWidth;
  [features.widthAnchor constraintEqualToConstant:contentWidth].active = YES;

  NSStackView *prices = [NSStackView stackViewWithViews:@[PriceBox(SplitLocalized(@"ProPriceMonthly")), PriceBox(SplitLocalized(@"ProPriceYearly"))]];
  prices.spacing = 8;

  NSButton *buy = [NSButton buttonWithTitle:SplitLocalized(@"ProComingSoon") target:nil action:nil];
  buy.enabled = NO;
  [buy.widthAnchor constraintEqualToConstant:contentWidth].active = YES;

  NSButton *signIn = [NSButton buttonWithTitle:SplitLocalized(@"ProSignIn") target:nil action:nil];
  signIn.enabled = NO;
  NSButton *restore = [NSButton buttonWithTitle:SplitLocalized(@"ProRestore") target:nil action:nil];
  restore.enabled = NO;
  NSButton *done = [NSButton buttonWithTitle:SplitLocalized(@"ProContinue") target:self action:@selector(close:)];
  done.keyEquivalent = @"\r";
  NSStackView *buttons = [NSStackView stackViewWithViews:@[signIn, restore, done]];
  buttons.spacing = 8;

  NSTextField *note = SheetLabel(SplitLocalized(@"ProFreeUntilLaunch"), 11, NSFontWeightRegular, NSColor.tertiaryLabelColor);

  NSStackView *content = [NSStackView stackViewWithViews:@[icon, title, features, prices, buy, buttons, note]];
  content.orientation = NSUserInterfaceLayoutOrientationVertical;
  content.alignment = NSLayoutAttributeCenterX;
  content.spacing = 8;
  [content setCustomSpacing:14 afterView:features];
  [content setCustomSpacing:16 afterView:prices];
  [content setCustomSpacing:14 afterView:buttons];
  content.translatesAutoresizingMaskIntoConstraints = NO;

  NSView *container = panel.contentView;
  [container addSubview:content];
  [NSLayoutConstraint activateConstraints:@[
    [container.widthAnchor constraintEqualToConstant:kSheetWidth],
    [content.topAnchor constraintEqualToAnchor:container.topAnchor constant:kSheetPadding],
    [content.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-kSheetPadding],
    [content.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
  ]];
  [panel layoutIfNeeded];
  return self;
}

- (void)close:(id)sender
{
  NSWindow *panel = self.window;
  if (panel.sheetParent) {
    [panel.sheetParent endSheet:panel];
  } else {
    [panel orderOut:sender];
  }
}

@end

void SplitShowProSheet(NSWindow *window)
{
  static SplitProSheetController *controller;
  if (!controller) {
    controller = [SplitProSheetController new];
  }
  NSWindow *panel = controller.window;
  if (panel.isVisible) {
    return;
  }
  if (window) {
    [window beginSheet:panel completionHandler:nil];
  } else {
    [NSApp activateIgnoringOtherApps:YES];
    [panel center];
    [panel makeKeyAndOrderFront:nil];
  }
}
