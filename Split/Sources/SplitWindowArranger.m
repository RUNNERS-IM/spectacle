#import "SplitWindowArranger.h"

#import <ApplicationServices/ApplicationServices.h>

#import "SplitAccessibilityElement.h"

const NSUInteger kSplitArrangeMaximumWindowCount = 9;

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

/// A window found on screen, with its Accessibility element and where it was.
@interface SplitArrangedWindow : NSObject
@property (nonatomic, strong) SplitAccessibilityElement *element;
@property (nonatomic, assign) CGRect originalRect;
@end

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

/// Ordinary windows on `screen`, front to back. The window server lists windows in stacking
/// order, which is the order they were last used in.
static NSArray<SplitArrangedWindow *> *VisibleWindowsOnScreen(NSScreen *screen)
{
  CGRect screenRect = TopLeftRectFromCocoaRect(screen.frame);
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
        || !CGRectContainsPoint(screenRect, CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds)))) {
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
  NSArray<SplitArrangedWindow *> *windows = VisibleWindowsOnScreen(screen);
  if (windows.count > kSplitArrangeMaximumWindowCount) {
    windows = [windows subarrayWithRange:NSMakeRange(0, kSplitArrangeMaximumWindowCount)];
  }
  if (outWindows) {
    *outWindows = windows;
  }
  return SplitArrangeLayoutRects(windows.count, TopLeftRectFromCocoaRect(screen.visibleFrame));
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

@end
