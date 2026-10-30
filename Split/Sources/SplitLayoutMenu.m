#import "SplitLayoutMenu.h"

#import "SplitLayouts.h"
#import "SplitUtilities.h"
#import "SplitWindowArranger.h"
#import "SplitWindowFeedback.h"

static const CGFloat kMenuWidth = 300.0;
static const CGFloat kSideInset = 14.0;
static const CGFloat kTileRadius = 10.0;
static const CGFloat kChipColumns = 5.0;

static NSTextField *SectionLabel(NSString *text)
{
  NSTextField *label = [NSTextField labelWithString:text];
  label.font = [NSFont systemFontOfSize:11.0 weight:NSFontWeightSemibold];
  label.textColor = NSColor.secondaryLabelColor;
  return label;
}

/// A row or chip in the menu view: highlights under the mouse and when selected, and sends its
/// action on click. Plain controls in a menu do not get the menu's hover look by themselves.
@interface SplitLayoutMenuCell : NSControl
@property (nonatomic, assign) BOOL selected;
@property (nonatomic, copy) void (^clicked)(void);
@end

@implementation SplitLayoutMenuCell
{
  BOOL _hovering;
  NSTrackingArea *_tracking;
}

- (void)updateTrackingAreas
{
  [super updateTrackingAreas];
  if (_tracking) {
    [self removeTrackingArea:_tracking];
  }
  _tracking = [[NSTrackingArea alloc] initWithRect:self.bounds
                                           options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect
                                             owner:self
                                          userInfo:nil];
  [self addTrackingArea:_tracking];
}

- (void)mouseEntered:(NSEvent *)event
{
  _hovering = YES;
  self.needsDisplay = YES;
}

- (void)mouseExited:(NSEvent *)event
{
  _hovering = NO;
  self.needsDisplay = YES;
}

- (void)mouseUp:(NSEvent *)event
{
  if (self.clicked && NSPointInRect([self convertPoint:event.locationInWindow fromView:nil], self.bounds)) {
    self.clicked();
  }
}

- (void)setSelected:(BOOL)selected
{
  _selected = selected;
  self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect
{
  if (!self.selected && !_hovering) {
    return;
  }
  NSColor *fill = self.selected ? [NSColor.controlAccentColor colorWithAlphaComponent:0.16]
                                : [NSColor.labelColor colorWithAlphaComponent:0.08];
  [fill setFill];
  [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:6.0 yRadius:6.0] fill];
}

@end

/// A rounded panel behind a group of rows, like the modules in Control Center.
@interface SplitLayoutMenuTile : NSView
@end

@implementation SplitLayoutMenuTile

- (void)drawRect:(NSRect)dirtyRect
{
  [[NSColor.labelColor colorWithAlphaComponent:0.06] setFill];
  [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:kTileRadius yRadius:kTileRadius] fill];
}

@end

@implementation SplitLayoutMenu
{
  SplitWindowArranger *_arranger;
  void (^_moved)(NSUInteger);
  NSMenu *_menu;
  NSMenuItem *_viewItem;
  NSMenuItem *_deleteItem;
  NSString *_selectedDisplayID;
}

- (instancetype)initWithArranger:(SplitWindowArranger *)arranger moved:(void (^)(NSUInteger))moved
{
  if (self = [super init]) {
    _arranger = arranger;
    _moved = [moved copy];
  }
  return self;
}

- (void)installInMenu:(NSMenu *)menu
{
  _menu = menu;
  NSMenuItem *header = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
  header.attributedTitle = [[NSAttributedString alloc] initWithString:SplitLocalized(@"LayoutSection")
                                                          attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:11.0 weight:NSFontWeightSemibold],
                                                                       NSForegroundColorAttributeName: NSColor.secondaryLabelColor}];
  header.enabled = NO;
  _viewItem = [NSMenuItem new];
  NSMenuItem *save = [[NSMenuItem alloc] initWithTitle:SplitLocalized(@"LayoutSave") action:@selector(saveLayout:) keyEquivalent:@""];
  save.target = self;
  save.image = SplitIcon(@"save", 16);
  _deleteItem = [[NSMenuItem alloc] initWithTitle:SplitLocalized(@"LayoutDelete") action:nil keyEquivalent:@""];
  _deleteItem.image = SplitIcon(@"trash-2", 16);
  _deleteItem.submenu = [NSMenu new];
  NSArray<NSMenuItem *> *items = @[header, _viewItem, save, _deleteItem, NSMenuItem.separatorItem];
  for (NSUInteger index = 0; index < items.count; index++) {
    [menu insertItem:items[index] atIndex:index];
  }
  [self refresh];
}

#pragma mark - Building the view

static NSScreen *ScreenUnderMouse(void)
{
  NSPoint mouse = NSEvent.mouseLocation;
  for (NSScreen *screen in NSScreen.screens) {
    if (NSPointInRect(mouse, screen.frame)) {
      return screen;
    }
  }
  return NSScreen.mainScreen ?: NSScreen.screens.firstObject;
}

- (NSScreen *)selectedScreen
{
  for (NSScreen *screen in NSScreen.screens) {
    if ([SplitDisplayIDOfScreen(screen) isEqualToString:_selectedDisplayID]) {
      return screen;
    }
  }
  return ScreenUnderMouse();
}

- (void)refresh
{
  NSScreen *selected = self.selectedScreen;
  _selectedDisplayID = SplitDisplayIDOfScreen(selected);

  NSStackView *content = [NSStackView stackViewWithViews:@[]];
  content.orientation = NSUserInterfaceLayoutOrientationVertical;
  content.alignment = NSLayoutAttributeLeading;
  content.spacing = 8.0;
  content.edgeInsets = NSEdgeInsetsMake(2.0, kSideInset - 4.0, 8.0, kSideInset - 4.0);

  // Monitors, one row each, like the Display module in Control Center.
  NSStackView *displays = [NSStackView stackViewWithViews:@[]];
  displays.orientation = NSUserInterfaceLayoutOrientationVertical;
  displays.alignment = NSLayoutAttributeLeading;
  displays.spacing = 2.0;
  for (NSScreen *screen in NSScreen.screens) {
    NSView *row = [self rowForScreen:screen selected:screen == selected];
    [displays addArrangedSubview:row];
    [row.widthAnchor constraintEqualToAnchor:displays.widthAnchor].active = YES;
  }
  [content addArrangedSubview:[self tileWithTitle:SplitLocalized(@"LayoutDisplays") body:displays]];

  // Shapes, then saved layouts, as chips.
  NSMutableArray<NSView *> *shapeChips = [NSMutableArray new];
  for (SplitLayoutShape shape in SplitLayoutShapes()) {
    __weak typeof(self) weakSelf = self;
    [shapeChips addObject:[self chipWithImage:SplitMiniScreenImage(SplitLayoutShapeFractions(shape), NSMakeSize(34.0, 22.0))
                                        title:SplitLocalized([@"LayoutShape" stringByAppendingString:shape])
                                      clicked:^{ [weakSelf applyShape:shape]; }]];
  }
  NSStackView *tileBody = [NSStackView stackViewWithViews:@[[self chipGrid:shapeChips]]];
  tileBody.orientation = NSUserInterfaceLayoutOrientationVertical;
  tileBody.alignment = NSLayoutAttributeLeading;
  tileBody.spacing = 6.0;
  [tileBody addArrangedSubview:SectionLabel(SplitLocalized(@"LayoutSaved"))];
  NSArray<SplitSavedLayout *> *layouts = SplitLayoutStore.sharedStore.layouts;
  if (layouts.count == 0) {
    NSTextField *empty = [NSTextField wrappingLabelWithString:SplitLocalized(@"LayoutSavedEmpty")];
    empty.font = [NSFont systemFontOfSize:11.0];
    empty.textColor = NSColor.secondaryLabelColor;
    empty.preferredMaxLayoutWidth = kMenuWidth - 2 * kSideInset - 16.0;
    [tileBody addArrangedSubview:empty];
  } else {
    NSMutableArray<NSView *> *savedChips = [NSMutableArray new];
    for (SplitSavedLayout *layout in layouts) {
      __weak typeof(self) weakSelf = self;
      NSString *title = layout.restoresForDisplays ? [layout.name stringByAppendingString:@" ·A"] : layout.name;
      NSView *chip = [self chipWithImage:[self imageForLayout:layout] title:title clicked:^{ [weakSelf restoreLayout:layout]; }];
      chip.toolTip = layout.restoresForDisplays ? SplitLocalized(@"LayoutSaveAuto") : nil;
      [savedChips addObject:chip];
    }
    [tileBody addArrangedSubview:[self chipGrid:savedChips]];
  }
  [content addArrangedSubview:[self tileWithTitle:SplitLocalized(@"LayoutShapes") body:tileBody]];

  NSView *container = [[NSView alloc] initWithFrame:NSZeroRect];
  content.translatesAutoresizingMaskIntoConstraints = NO;
  [container addSubview:content];
  [NSLayoutConstraint activateConstraints:@[
    [content.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
    [content.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
    [content.topAnchor constraintEqualToAnchor:container.topAnchor],
    [content.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    [container.widthAnchor constraintEqualToConstant:kMenuWidth],
  ]];
  container.frame = NSMakeRect(0, 0, kMenuWidth, content.fittingSize.height);
  _viewItem.view = container;

  [_deleteItem.submenu removeAllItems];
  for (SplitSavedLayout *layout in layouts) {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:layout.name action:@selector(deleteLayout:) keyEquivalent:@""];
    item.target = self;
    item.representedObject = layout;
    [_deleteItem.submenu addItem:item];
  }
  _deleteItem.hidden = layouts.count == 0;
}

- (NSView *)tileWithTitle:(NSString *)title body:(NSView *)body
{
  SplitLayoutMenuTile *tile = [SplitLayoutMenuTile new];
  NSStackView *stack = [NSStackView stackViewWithViews:@[SectionLabel(title), body]];
  stack.orientation = NSUserInterfaceLayoutOrientationVertical;
  stack.alignment = NSLayoutAttributeLeading;
  stack.spacing = 6.0;
  stack.edgeInsets = NSEdgeInsetsMake(8.0, 8.0, 8.0, 8.0);
  stack.translatesAutoresizingMaskIntoConstraints = NO;
  [tile addSubview:stack];
  tile.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [stack.leadingAnchor constraintEqualToAnchor:tile.leadingAnchor],
    [stack.trailingAnchor constraintEqualToAnchor:tile.trailingAnchor],
    [stack.topAnchor constraintEqualToAnchor:tile.topAnchor],
    [stack.bottomAnchor constraintEqualToAnchor:tile.bottomAnchor],
    [tile.widthAnchor constraintEqualToConstant:kMenuWidth - 2 * (kSideInset - 4.0)],
    [body.widthAnchor constraintEqualToAnchor:stack.widthAnchor constant:-16.0],
  ]];
  return tile;
}

- (NSView *)rowForScreen:(NSScreen *)screen selected:(BOOL)selected
{
  SplitLayoutMenuCell *row = [SplitLayoutMenuCell new];
  row.selected = selected;
  NSString *displayID = SplitDisplayIDOfScreen(screen);
  __weak typeof(self) weakSelf = self;
  row.clicked = ^{
    typeof(self) strongSelf = weakSelf;
    if (strongSelf) {
      strongSelf->_selectedDisplayID = displayID;
      [strongSelf refresh];
    }
  };

  NSImageView *icon = [NSImageView imageViewWithImage:SplitIcon(@"monitor", 16)];
  icon.contentTintColor = selected ? NSColor.controlAccentColor : NSColor.secondaryLabelColor;
  NSTextField *name = [NSTextField labelWithString:screen.localizedName];
  name.font = [NSFont systemFontOfSize:13.0];
  NSSize pixels = [screen convertRectToBacking:screen.frame].size;
  NSUInteger count = SplitVisibleWindows(screen).count;
  NSString *detailText = [NSString stringWithFormat:@"%.0f × %.0f · %@", pixels.width, pixels.height,
                          [NSString stringWithFormat:SplitLocalized(@"LayoutWindowCount"), (unsigned long)count]];
  NSTextField *detail = [NSTextField labelWithString:detailText];
  detail.font = [NSFont systemFontOfSize:11.0];
  detail.textColor = NSColor.secondaryLabelColor;
  NSStackView *texts = [NSStackView stackViewWithViews:@[name, detail]];
  texts.orientation = NSUserInterfaceLayoutOrientationVertical;
  texts.alignment = NSLayoutAttributeLeading;
  texts.spacing = 0.0;
  NSMutableArray<NSView *> *views = [NSMutableArray arrayWithObjects:icon, texts, nil];
  if (selected) {
    NSImageView *check = [NSImageView imageViewWithImage:SplitIcon(@"check", 14)];
    check.contentTintColor = NSColor.controlAccentColor;
    [views addObject:check];
  }
  NSStackView *line = [NSStackView stackViewWithViews:views];
  line.alignment = NSLayoutAttributeCenterY;
  line.distribution = NSStackViewDistributionFill;
  line.spacing = 8.0;
  [texts setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
  line.edgeInsets = NSEdgeInsetsMake(4.0, 6.0, 4.0, 6.0);
  [line setHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
  line.translatesAutoresizingMaskIntoConstraints = NO;
  [row addSubview:line];
  row.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [line.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
    [line.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
    [line.topAnchor constraintEqualToAnchor:row.topAnchor],
    [line.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
  ]];
  return row;
}

- (NSView *)chipWithImage:(NSImage *)image title:(NSString *)title clicked:(void (^)(void))clicked
{
  SplitLayoutMenuCell *chip = [SplitLayoutMenuCell new];
  chip.clicked = clicked;
  NSImageView *picture = [NSImageView imageViewWithImage:image];
  picture.contentTintColor = NSColor.labelColor;
  NSTextField *label = [NSTextField labelWithString:title];
  label.font = [NSFont systemFontOfSize:10.0];
  label.alignment = NSTextAlignmentCenter;
  label.lineBreakMode = NSLineBreakByTruncatingTail;
  NSStackView *stack = [NSStackView stackViewWithViews:@[picture, label]];
  stack.orientation = NSUserInterfaceLayoutOrientationVertical;
  stack.spacing = 3.0;
  stack.edgeInsets = NSEdgeInsetsMake(5.0, 2.0, 4.0, 2.0);
  stack.translatesAutoresizingMaskIntoConstraints = NO;
  [chip addSubview:stack];
  chip.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [stack.leadingAnchor constraintEqualToAnchor:chip.leadingAnchor],
    [stack.trailingAnchor constraintEqualToAnchor:chip.trailingAnchor],
    [stack.topAnchor constraintEqualToAnchor:chip.topAnchor],
    [stack.bottomAnchor constraintEqualToAnchor:chip.bottomAnchor],
    [label.widthAnchor constraintLessThanOrEqualToAnchor:chip.widthAnchor constant:-4.0],
  ]];
  return chip;
}

/// Chips in rows of five, all the same width.
- (NSView *)chipGrid:(NSArray<NSView *> *)chips
{
  NSGridView *grid = [NSGridView gridViewWithNumberOfColumns:(NSInteger)kChipColumns rows:0];
  grid.columnSpacing = 4.0;
  grid.rowSpacing = 4.0;
  for (NSUInteger start = 0; start < chips.count; start += (NSUInteger)kChipColumns) {
    NSMutableArray<NSView *> *row = [NSMutableArray new];
    for (NSUInteger index = start; index < start + (NSUInteger)kChipColumns; index++) {
      [row addObject:index < chips.count ? chips[index] : [NSGridCell emptyContentView]];
    }
    [grid addRowWithViews:row];
  }
  CGFloat columnWidth = (kMenuWidth - 2 * (kSideInset - 4.0) - 16.0 - 4.0 * (kChipColumns - 1)) / kChipColumns;
  for (NSInteger column = 0; column < grid.numberOfColumns; column++) {
    [grid columnAtIndex:column].width = columnWidth;
  }
  return grid;
}

/// The windows of a saved layout drawn on one small screen: the monitor holding most of them.
- (NSImage *)imageForLayout:(SplitSavedLayout *)layout
{
  NSCountedSet<NSString *> *displays = [NSCountedSet new];
  for (SplitSavedWindow *window in layout.windows) {
    [displays addObject:window.displayID];
  }
  NSString *busiest = nil;
  for (NSString *displayID in displays) {
    if (!busiest || [displays countForObject:displayID] > [displays countForObject:busiest]) {
      busiest = displayID;
    }
  }
  NSScreen *screen = nil;
  for (NSScreen *candidate in NSScreen.screens) {
    if ([SplitDisplayIDOfScreen(candidate) isEqualToString:busiest]) {
      screen = candidate;
    }
  }
  NSMutableArray<NSValue *> *fractions = [NSMutableArray new];
  if (screen) {
    CGRect frame = SplitTopLeftVisibleFrame(screen);
    for (SplitSavedWindow *window in layout.windows) {
      if (![window.displayID isEqualToString:busiest] || frame.size.width <= 0 || frame.size.height <= 0) {
        continue;
      }
      CGRect rect = CGRectIntersection(window.rect, frame);
      [fractions addObject:[NSValue valueWithRect:NSMakeRect((rect.origin.x - frame.origin.x) / frame.size.width,
                                                             (rect.origin.y - frame.origin.y) / frame.size.height,
                                                             rect.size.width / frame.size.width,
                                                             rect.size.height / frame.size.height)]];
    }
  }
  return SplitMiniScreenImage(fractions, NSMakeSize(34.0, 22.0));
}

#pragma mark - Actions

/// Runs `block` once the menu has closed, so the windows move after the menu is gone.
- (void)afterMenuCloses:(void (^)(void))block
{
  [_menu cancelTracking];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
}

- (void)applyShape:(SplitLayoutShape)shape
{
  NSScreen *screen = self.selectedScreen;
  [self afterMenuCloses:^{
    self->_moved(SplitApplyLayoutShape(shape, screen, self->_arranger));
  }];
}

- (void)restoreLayout:(SplitSavedLayout *)layout
{
  [self afterMenuCloses:^{
    self->_moved(SplitRestoreLayout(layout, self->_arranger));
  }];
}

- (void)saveLayout:(id)sender
{
  // Wait for the menu to close, or the alert opens behind it.
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [self askForNameAndSave];
  });
}

- (void)askForNameAndSave
{
  NSAlert *alert = [NSAlert new];
  alert.messageText = SplitLocalized(@"LayoutSaveTitle");
  alert.informativeText = SplitLocalized(@"LayoutSaveMessage");
  [alert addButtonWithTitle:SplitLocalized(@"LayoutSaveButton")];
  [alert addButtonWithTitle:SplitLocalized(@"LayoutSaveCancel")];
  NSTextField *name = [NSTextField textFieldWithString:[NSString stringWithFormat:SplitLocalized(@"LayoutSaveDefaultName"),
                                                        (unsigned long)SplitLayoutStore.sharedStore.layouts.count + 1]];
  name.placeholderString = SplitLocalized(@"LayoutSaveNamePlaceholder");
  NSButton *automatic = [NSButton checkboxWithTitle:SplitLocalized(@"LayoutSaveAuto") target:nil action:nil];
  automatic.state = NSControlStateValueOn;
  NSStackView *accessory = [NSStackView stackViewWithViews:@[name, automatic]];
  accessory.orientation = NSUserInterfaceLayoutOrientationVertical;
  accessory.alignment = NSLayoutAttributeLeading;
  accessory.spacing = 8.0;
  [name.widthAnchor constraintEqualToConstant:260.0].active = YES;
  accessory.frame = NSMakeRect(0, 0, 260.0, accessory.fittingSize.height);
  alert.accessoryView = accessory;
  alert.window.initialFirstResponder = name;
  [NSApp activateIgnoringOtherApps:YES];
  if ([alert runModal] != NSAlertFirstButtonReturn) {
    return;
  }
  NSString *title = [name.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (title.length == 0) {
    title = name.placeholderString;
  }
  [SplitLayoutStore.sharedStore saveCurrentLayoutNamed:title restoresForDisplays:automatic.state == NSControlStateValueOn];
  [self refresh];
}

- (void)deleteLayout:(NSMenuItem *)sender
{
  [SplitLayoutStore.sharedStore removeLayout:sender.representedObject];
  [self refresh];
}

@end
