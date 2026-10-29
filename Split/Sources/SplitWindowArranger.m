#import "SplitWindowArranger.h"

#import <ApplicationServices/ApplicationServices.h>

#import "SplitAccessibilityElement.h"

const NSUInteger kSplitArrangeMaximumWindowCount = 9;

NSString *const SplitWindowGapKey = @"WindowGap";

CGFloat SplitWindowGap(void)
{
  NSNumber *value = [NSUserDefaults.standardUserDefaults objectForKey:SplitWindowGapKey];
  return value ? MIN(MAX(value.doubleValue, 0.0), 40.0) : 8.0;
}

CGRect SplitRectWithGap(CGRect rect, CGRect visibleFrame, CGFloat gap)
{
  if (gap <= 0.0 || CGRectIsNull(rect) || CGRectIsNull(visibleFrame)) {
    return rect;
  }
  // An edge within a point of the screen edge stays on it; any other edge faces a neighbour and
  // gives up half the gap, so two neighbours end up `gap` apart.
  CGFloat left = fabs(CGRectGetMinX(rect) - CGRectGetMinX(visibleFrame)) <= 1.0 ? 0.0 : gap / 2.0;
  CGFloat right = fabs(CGRectGetMaxX(rect) - CGRectGetMaxX(visibleFrame)) <= 1.0 ? 0.0 : gap / 2.0;
  CGFloat bottom = fabs(CGRectGetMinY(rect) - CGRectGetMinY(visibleFrame)) <= 1.0 ? 0.0 : gap / 2.0;
  CGFloat top = fabs(CGRectGetMaxY(rect) - CGRectGetMaxY(visibleFrame)) <= 1.0 ? 0.0 : gap / 2.0;
  CGRect result = CGRectMake(round(rect.origin.x + left), round(rect.origin.y + bottom),
                             round(rect.size.width - left - right), round(rect.size.height - bottom - top));
  return result.size.width > 0 && result.size.height > 0 ? result : rect;
}

static const CGFloat kFloatingScale = 0.6;
static const CGFloat kStackOffset = 30.0;
static const CGFloat kMinimumWindowSide = 80.0;

/// Not in the public headers, but part of HIServices since macOS 10.x and used by most window
/// managers to tie an Accessibility window to its window-server number.
extern AXError _AXUIElementGetWindow(AXUIElementRef element, CGWindowID *windowID);

static CGRect GridCell(CGRect frame, NSUInteger columns, NSUInteger rows, NSUInteger column, NSUInteger row)
{
  CGFloat width = floor(frame.size.width / columns);
  CGFloat height = floor(frame.size.height / rows);
  CGFloat x = frame.origin.x + width * column;
  CGFloat y = frame.origin.y + height * row;
  // The last column and row take what rounding left over so the grid fills the screen.
  if (column == columns - 1) {
    width = CGRectGetMaxX(frame) - x;
  }
  if (row == rows - 1) {
    height = CGRectGetMaxY(frame) - y;
  }
  return CGRectMake(x, y, width, height);
}

static CGRect FloatingRect(CGRect frame, NSUInteger stackIndex)
{
  CGFloat width = round(frame.size.width * kFloatingScale);
  CGFloat height = round(frame.size.height * kFloatingScale);
  CGFloat x = round(CGRectGetMidX(frame) - width / 2.0) + kStackOffset * stackIndex;
  CGFloat y = round(CGRectGetMidY(frame) - height / 2.0) + kStackOffset * stackIndex;
  return CGRectMake(x, y, width, height);
}

static NSValue *Box(CGRect rect)
{
  return [NSValue valueWithRect:NSRectFromCGRect(rect)];
}

NSArray<NSValue *> *SplitArrangeLayoutRects(NSUInteger count, CGRect frame)
{
  count = MIN(count, kSplitArrangeMaximumWindowCount);
  NSMutableArray<NSValue *> *rects = [NSMutableArray new];
  switch (count) {
    case 0:
      break;
    case 1:
      [rects addObject:Box(frame)];
      break;
    case 2:
      [rects addObject:Box(GridCell(frame, 2, 1, 0, 0))];
      [rects addObject:Box(GridCell(frame, 2, 1, 1, 0))];
      break;
    case 3:
      [rects addObject:Box(GridCell(frame, 2, 1, 0, 0))];
      [rects addObject:Box(GridCell(frame, 2, 2, 1, 0))];
      [rects addObject:Box(GridCell(frame, 2, 2, 1, 1))];
      break;
    case 4:
    case 5: {
      if (count == 5) {
        [rects addObject:Box(FloatingRect(frame, 0))];
      }
      for (NSUInteger row = 0; row < 2; row++) {
        for (NSUInteger column = 0; column < 2; column++) {
          [rects addObject:Box(GridCell(frame, 2, 2, column, row))];
        }
      }
      break;
    }
    default: {
      for (NSUInteger row = 0; row < 2; row++) {
        for (NSUInteger column = 0; column < 3; column++) {
          [rects addObject:Box(GridCell(frame, 3, 2, column, row))];
        }
      }
      for (NSUInteger index = 6; index < count; index++) {
        [rects addObject:Box(FloatingRect(frame, index - 6))];
      }
      break;
    }
  }
  return rects;
}

#pragma mark -

@implementation SplitArrangedWindow
@end

@implementation SplitWindowArranger
{
  NSArray<SplitArrangedWindow *> *_lastArrangement;
}

static CGFloat PrimaryScreenHeight(void)
{
  return NSScreen.screens.firstObject.frame.size.height;
}

static CGRect TopLeftRectFromCocoaRect(NSRect rect)
{
  return CGRectMake(rect.origin.x, PrimaryScreenHeight() - NSMaxY(rect), rect.size.width, rect.size.height);
}

/// The screen that holds the middle of the frontmost window, or the main screen.
static NSScreen *TargetScreen(void)
{
  CGRect frontRect = [[SplitAccessibilityElement frontmostWindowElement] rectOfElement];
  if (!CGRectIsNull(frontRect)) {
    CGPoint middle = CGPointMake(CGRectGetMidX(frontRect), CGRectGetMidY(frontRect));
    for (NSScreen *screen in NSScreen.screens) {
      if (CGRectContainsPoint(TopLeftRectFromCocoaRect(screen.frame), middle)) {
        return screen;
      }
    }
  }
  return NSScreen.mainScreen ?: NSScreen.screens.firstObject;
}

static NSNumber *BoolAttribute(AXUIElementRef element, CFStringRef attribute)
{
  CFTypeRef value = NULL;
  if (AXUIElementCopyAttributeValue(element, attribute, &value) != kAXErrorSuccess || !value) {
    return nil;
  }
  return CFBridgingRelease(value);
}

static NSString *StringAttribute(AXUIElementRef element, CFStringRef attribute)
{
  CFTypeRef value = NULL;
  if (AXUIElementCopyAttributeValue(element, attribute, &value) != kAXErrorSuccess || !value) {
    return nil;
  }
  id object = CFBridgingRelease(value);
  return [object isKindOfClass:NSString.class] ? object : nil;
}

/// Accessibility windows of one app keyed by window-server number. Only ordinary windows that
/// are not minimized or in full screen are kept.
static NSDictionary<NSNumber *, SplitAccessibilityElement *> *StandardWindowsOfProcess(pid_t pid)
{
  NSMutableDictionary *result = [NSMutableDictionary new];
  AXUIElementRef application = AXUIElementCreateApplication(pid);
  if (!application) {
    return result;
  }
  CFArrayRef windows = NULL;
  if (AXUIElementCopyAttributeValues(application, kAXWindowsAttribute, 0, 100, &windows) == kAXErrorSuccess && windows) {
    for (CFIndex index = 0; index < CFArrayGetCount(windows); index++) {
      AXUIElementRef window = (AXUIElementRef)CFArrayGetValueAtIndex(windows, index);
      CGWindowID windowID = 0;
      if (_AXUIElementGetWindow(window, &windowID) != kAXErrorSuccess || windowID == 0) {
        continue;
      }
      if (![StringAttribute(window, kAXSubroleAttribute) isEqualToString:(__bridge NSString *)kAXStandardWindowSubrole]) {
        continue;
      }
      if ([BoolAttribute(window, kAXMinimizedAttribute) boolValue]
          || [BoolAttribute(window, CFSTR("AXFullScreen")) boolValue]) {
        continue;
      }
      result[@(windowID)] = [SplitAccessibilityElement elementWithAXUIElement:window];
    }
    CFRelease(windows);
  }
  CFRelease(application);
  return result;
}

CGRect SplitTopLeftVisibleFrame(NSScreen *screen)
{
  return TopLeftRectFromCocoaRect(screen.visibleFrame);
}

static BOOL PointIsOnAnyScreen(CGPoint point)
{
  for (NSScreen *screen in NSScreen.screens) {
    if (CGRectContainsPoint(TopLeftRectFromCocoaRect(screen.frame), point)) {
      return YES;
    }
  }
  return NO;
}

/// The window server lists windows in stacking order, which is the order they were last used in.
NSArray<SplitArrangedWindow *> *SplitVisibleWindows(NSScreen *screen)
{
  CGRect screenRect = screen ? TopLeftRectFromCocoaRect(screen.frame) : CGRectNull;
  pid_t ownPid = NSProcessInfo.processInfo.processIdentifier;
  NSArray<NSDictionary *> *infos = CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID));
  NSMutableDictionary<NSNumber *, NSDictionary *> *windowsByProcess = [NSMutableDictionary new];
  NSMutableArray<SplitArrangedWindow *> *result = [NSMutableArray new];
  for (NSDictionary *info in infos) {
    if ([info[(id)kCGWindowLayer] integerValue] != 0 || [info[(id)kCGWindowAlpha] doubleValue] <= 0.0) {
      continue;
    }
    pid_t pid = [info[(id)kCGWindowOwnerPID] intValue];
    if (pid == ownPid) {
      continue;
    }
    CGRect bounds = CGRectNull;
    if (!CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)info[(id)kCGWindowBounds], &bounds)
        || bounds.size.width < kMinimumWindowSide || bounds.size.height < kMinimumWindowSide
        || (screen && !CGRectContainsPoint(screenRect, CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds))))
        || (!screen && !PointIsOnAnyScreen(CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds))))) {
      continue;
    }
    NSDictionary<NSNumber *, SplitAccessibilityElement *> *processWindows = windowsByProcess[@(pid)];
    if (!processWindows) {
      processWindows = StandardWindowsOfProcess(pid);
      windowsByProcess[@(pid)] = processWindows;
    }
    SplitAccessibilityElement *element = processWindows[info[(id)kCGWindowNumber]];
    if (!element) {
      continue;
    }
    SplitArrangedWindow *window = [SplitArrangedWindow new];
    window.element = element;
    window.originalRect = bounds;
    [result addObject:window];
  }
  return result;
}

- (NSArray<NSValue *> *)planWindows:(NSArray<SplitArrangedWindow *> *__autoreleasing *)outWindows
{
  NSScreen *screen = TargetScreen();
  NSArray<SplitArrangedWindow *> *windows = SplitVisibleWindows(screen);
  if (windows.count > kSplitArrangeMaximumWindowCount) {
    windows = [windows subarrayWithRange:NSMakeRange(0, kSplitArrangeMaximumWindowCount)];
  }
  if (outWindows) {
    *outWindows = windows;
  }
  CGRect visibleFrame = TopLeftRectFromCocoaRect(screen.visibleFrame);
  CGFloat gap = SplitWindowGap();
  NSMutableArray<NSValue *> *rects = [NSMutableArray new];
  for (NSValue *value in SplitArrangeLayoutRects(windows.count, visibleFrame)) {
    [rects addObject:[NSValue valueWithRect:NSRectFromCGRect(SplitRectWithGap(NSRectToCGRect(value.rectValue), visibleFrame, gap))]];
  }
  return rects;
}

- (NSArray<NSValue *> *)plannedRects
{
  return [self planWindows:NULL];
}

- (NSArray<NSValue *> *)arrangeWindows
{
  NSArray<SplitArrangedWindow *> *windows = nil;
  NSArray<NSValue *> *rects = [self planWindows:&windows];
  if (windows.count == 0) {
    return @[];
  }
  for (NSUInteger index = 0; index < windows.count; index++) {
    [windows[index].element setRectOfElement:NSRectToCGRect(rects[index].rectValue)];
  }
  _lastArrangement = windows;
  return rects;
}

- (BOOL)canUndo
{
  return _lastArrangement.count > 0;
}

- (BOOL)undoLastArrangement
{
  if (_lastArrangement.count == 0) {
    return NO;
  }
  for (SplitArrangedWindow *window in _lastArrangement) {
    [window.element setRectOfElement:window.originalRect];
  }
  _lastArrangement = nil;
  return YES;
}

- (void)forgetLastArrangement
{
  _lastArrangement = nil;
}

- (void)moveWindows:(NSArray<SplitArrangedWindow *> *)windows toRects:(NSArray<NSValue *> *)rects
{
  NSUInteger count = MIN(windows.count, rects.count);
  for (NSUInteger index = 0; index < count; index++) {
    [windows[index].element setRectOfElement:NSRectToCGRect(rects[index].rectValue)];
  }
  _lastArrangement = [windows subarrayWithRange:NSMakeRange(0, count)];
}

@end

#pragma mark - Monitor changes

static const NSTimeInterval kRecordInterval = 4.0;
static const NSTimeInterval kSettleDelay = 1.0;

/// Where a window was last seen.
@interface SplitWindowPlace : NSObject
@property (nonatomic, copy) NSString *displayID;
@property (nonatomic, assign) CGRect rect;
@end

@implementation SplitWindowPlace
@end

static NSString *DisplayIDOfScreen(NSScreen *screen)
{
  NSNumber *number = screen.deviceDescription[@"NSScreenNumber"];
  CFUUIDRef uuid = number ? CGDisplayCreateUUIDFromDisplayID(number.unsignedIntValue) : NULL;
  if (!uuid) {
    return number.stringValue ?: @"";
  }
  NSString *string = CFBridgingRelease(CFUUIDCreateString(NULL, uuid));
  CFRelease(uuid);
  return string;
}

static NSScreen *ScreenContainingPoint(CGPoint point)
{
  for (NSScreen *screen in NSScreen.screens) {
    if (CGRectContainsPoint(TopLeftRectFromCocoaRect(screen.frame), point)) {
      return screen;
    }
  }
  return nil;
}

static NSSet<NSString *> *CurrentDisplayIDs(void)
{
  NSMutableSet *ids = [NSMutableSet new];
  for (NSScreen *screen in NSScreen.screens) {
    [ids addObject:DisplayIDOfScreen(screen)];
  }
  return ids;
}

@implementation SplitDisplayChangeArranger
{
  SplitWindowArranger *_arranger;
  void (^_completion)(NSUInteger, BOOL);
  NSMapTable<SplitAccessibilityElement *, SplitWindowPlace *> *_places;
  /// Where windows were before their monitor went away. Kept apart from _places, which keeps
  /// being updated while the windows sit on another screen, so they can go home later.
  NSMapTable<SplitAccessibilityElement *, SplitWindowPlace *> *_awayPlaces;
  NSSet<NSString *> *_displayIDs;
  NSMutableSet<NSString *> *_seenDisplayIDs;
  NSTimer *_recordTimer;
  BOOL _settling;
}

+ (BOOL)enabled
{
  NSNumber *value = [NSUserDefaults.standardUserDefaults objectForKey:@"RearrangeOnDisplayChange"];
  return value ? value.boolValue : YES;
}

- (instancetype)initWithArranger:(SplitWindowArranger *)arranger completion:(void (^)(NSUInteger, BOOL))completion
{
  if (self = [super init]) {
    _arranger = arranger;
    _completion = [completion copy];
    _places = [NSMapTable strongToStrongObjectsMapTable];
    _awayPlaces = [NSMapTable strongToStrongObjectsMapTable];
    _seenDisplayIDs = [NSMutableSet new];
  }
  return self;
}

- (void)start
{
  _displayIDs = CurrentDisplayIDs();
  [_seenDisplayIDs unionSet:_displayIDs];
  [self record];
  _recordTimer = [NSTimer scheduledTimerWithTimeInterval:kRecordInterval target:self selector:@selector(record) userInfo:nil repeats:YES];
  _recordTimer.tolerance = 1.0;
  [NSNotificationCenter.defaultCenter addObserver:self
                                         selector:@selector(screensChanged:)
                                             name:NSApplicationDidChangeScreenParametersNotification
                                           object:nil];
}

- (void)recordSoon
{
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [self record];
  });
}

- (void)record
{
  // Right after a change macOS has already moved windows around; those places are not the
  // user's, so nothing is recorded until the change has been handled.
  if (_settling || !SplitDisplayChangeArranger.enabled) {
    return;
  }
  NSMapTable *places = [NSMapTable strongToStrongObjectsMapTable];
  for (SplitArrangedWindow *window in SplitVisibleWindows(nil)) {
    NSScreen *screen = ScreenContainingPoint(CGPointMake(CGRectGetMidX(window.originalRect), CGRectGetMidY(window.originalRect)));
    if (!screen) {
      continue;
    }
    SplitWindowPlace *place = [SplitWindowPlace new];
    place.displayID = DisplayIDOfScreen(screen);
    place.rect = window.originalRect;
    [places setObject:place forKey:window.element];
  }
  // Only what is on screen now, so closed windows are let go.
  _places = places;
}

- (void)screensChanged:(NSNotification *)notification
{
  if (_settling) {
    return;
  }
  _settling = YES;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kSettleDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [self handleChange];
    self->_settling = NO;
    [self recordSoon];
  });
}

/// Main screen first, then bigger screens first.
static NSArray<NSScreen *> *ScreensInOrder(void)
{
  NSScreen *main = NSScreen.screens.firstObject;
  return [NSScreen.screens sortedArrayUsingComparator:^NSComparisonResult(NSScreen *a, NSScreen *b) {
    if (a == main) return NSOrderedAscending;
    if (b == main) return NSOrderedDescending;
    CGFloat areaA = a.visibleFrame.size.width * a.visibleFrame.size.height;
    CGFloat areaB = b.visibleFrame.size.width * b.visibleFrame.size.height;
    return areaA > areaB ? NSOrderedAscending : (areaA < areaB ? NSOrderedDescending : NSOrderedSame);
  }];
}

/// How many of `count` windows each screen gets, in proportion to its area, at most 9 each.
static NSArray<NSNumber *> *SharesByArea(NSArray<NSScreen *> *screens, NSUInteger count)
{
  CGFloat total = 0;
  for (NSScreen *screen in screens) {
    total += screen.visibleFrame.size.width * screen.visibleFrame.size.height;
  }
  NSMutableArray<NSNumber *> *shares = [NSMutableArray new];
  NSUInteger given = 0;
  for (NSScreen *screen in screens) {
    CGFloat area = screen.visibleFrame.size.width * screen.visibleFrame.size.height;
    NSUInteger share = total > 0 ? (NSUInteger)floor(count * area / total) : 0;
    [shares addObject:@(share)];
    given += share;
  }
  // Rounding leftovers go to the screens in order (main first).
  for (NSUInteger index = 0; given < count && shares.count > 0; index = (index + 1) % shares.count) {
    shares[index] = @(shares[index].unsignedIntegerValue + 1);
    given++;
  }
  for (NSUInteger index = 0; index < shares.count; index++) {
    shares[index] = @(MIN(shares[index].unsignedIntegerValue, kSplitArrangeMaximumWindowCount));
  }
  return shares;
}

static void AddLayout(NSArray<SplitArrangedWindow *> *windows, NSScreen *screen,
                      NSMutableArray<SplitArrangedWindow *> *movedWindows, NSMutableArray<NSValue *> *rects)
{
  CGRect visibleFrame = TopLeftRectFromCocoaRect(screen.visibleFrame);
  NSArray<NSValue *> *layout = SplitArrangeLayoutRects(windows.count, visibleFrame);
  CGFloat gap = SplitWindowGap();
  for (NSUInteger index = 0; index < layout.count; index++) {
    [movedWindows addObject:windows[index]];
    [rects addObject:[NSValue valueWithRect:NSRectFromCGRect(SplitRectWithGap(NSRectToCGRect(layout[index].rectValue), visibleFrame, gap))]];
  }
}

- (void)handleChange
{
  NSSet<NSString *> *newIDs = CurrentDisplayIDs();
  NSSet<NSString *> *oldIDs = _displayIDs ?: newIDs;
  _displayIDs = newIDs;
  if (!SplitDisplayChangeArranger.enabled || [newIDs isEqualToSet:oldIDs]) {
    // Same monitors (waking from sleep, a resolution change): leave everything alone.
    return;
  }
  NSMutableSet<NSString *> *removed = [oldIDs mutableCopy];
  [removed minusSet:newIDs];
  NSMutableSet<NSString *> *added = [newIDs mutableCopy];
  [added minusSet:oldIDs];
  NSMutableSet<NSString *> *neverSeen = [added mutableCopy];
  [neverSeen minusSet:_seenDisplayIDs];
  [_seenDisplayIDs unionSet:newIDs];

  NSArray<SplitArrangedWindow *> *windows = SplitVisibleWindows(nil);
  NSMutableArray<SplitArrangedWindow *> *movedWindows = [NSMutableArray new];
  NSMutableArray<NSValue *> *rects = [NSMutableArray new];
  NSArray<NSScreen *> *screens = ScreensInOrder();

  if (neverSeen.count > 0) {
    // A new monitor: share every window out by screen area and arrange each screen.
    NSArray<NSNumber *> *shares = SharesByArea(screens, windows.count);
    NSUInteger next = 0;
    for (NSUInteger index = 0; index < screens.count; index++) {
      NSUInteger share = MIN(shares[index].unsignedIntegerValue, windows.count - next);
      AddLayout([windows subarrayWithRange:NSMakeRange(next, share)], screens[index], movedWindows, rects);
      next += share;
    }
    [_arranger moveWindows:movedWindows toRects:rects];
    _completion(movedWindows.count, NO);
    return;
  }

  // Windows whose monitor came back go home; windows whose monitor left need a new screen.
  NSMutableArray<SplitArrangedWindow *> *homeless = [NSMutableArray new];
  NSMutableDictionary<NSString *, NSMutableArray<SplitArrangedWindow *> *> *stayingByDisplay = [NSMutableDictionary new];
  for (SplitArrangedWindow *window in windows) {
    SplitWindowPlace *place = [_places objectForKey:window.element];
    SplitWindowPlace *home = [_awayPlaces objectForKey:window.element];
    if (home && [added containsObject:home.displayID]) {
      [movedWindows addObject:window];
      [rects addObject:[NSValue valueWithRect:NSRectFromCGRect(home.rect)]];
      [_awayPlaces removeObjectForKey:window.element];
    } else if (place && [removed containsObject:place.displayID]) {
      [homeless addObject:window];
      if (!home) {
        [_awayPlaces setObject:place forKey:window.element];
      }
    } else {
      NSScreen *screen = ScreenContainingPoint(CGPointMake(CGRectGetMidX(window.originalRect), CGRectGetMidY(window.originalRect)));
      NSString *displayID = screen ? DisplayIDOfScreen(screen) : @"";
      if (!stayingByDisplay[displayID]) {
        stayingByDisplay[displayID] = [NSMutableArray new];
      }
      [stayingByDisplay[displayID] addObject:window];
    }
  }
  BOOL restored = movedWindows.count > 0 && homeless.count == 0;
  if (homeless.count > 0) {
    // Share the windows from the monitor that left out by area, then arrange each screen that
    // received some together with the windows already on it, front to back.
    NSArray<NSNumber *> *shares = SharesByArea(screens, homeless.count);
    NSUInteger next = 0;
    for (NSUInteger index = 0; index < screens.count; index++) {
      NSUInteger share = MIN(shares[index].unsignedIntegerValue, homeless.count - next);
      if (share == 0) {
        continue;
      }
      NSMutableSet *incoming = [NSMutableSet setWithArray:[homeless subarrayWithRange:NSMakeRange(next, share)]];
      next += share;
      NSArray *staying = stayingByDisplay[DisplayIDOfScreen(screens[index])] ?: @[];
      NSMutableArray<SplitArrangedWindow *> *together = [NSMutableArray new];
      for (SplitArrangedWindow *window in windows) {
        if ([incoming containsObject:window] || [staying containsObject:window]) {
          [together addObject:window];
        }
      }
      if (together.count > kSplitArrangeMaximumWindowCount) {
        [together removeObjectsInRange:NSMakeRange(kSplitArrangeMaximumWindowCount, together.count - kSplitArrangeMaximumWindowCount)];
      }
      AddLayout(together, screens[index], movedWindows, rects);
    }
  }
  if (movedWindows.count == 0) {
    return;
  }
  [_arranger moveWindows:movedWindows toRects:rects];
  _completion(movedWindows.count, restored);
}

- (void)dealloc
{
  [_recordTimer invalidate];
  [NSNotificationCenter.defaultCenter removeObserver:self];
}

@end
