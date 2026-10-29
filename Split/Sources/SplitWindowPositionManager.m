#import "SplitWindowPositionManager.h"

#import "SplitAccessibilityElement.h"
#import "SplitBestEffortWindowMover.h"
#import "SplitHistory.h"
#import "SplitHistoryItem.h"
#import "SplitQuantizedWindowMover.h"
#import "SplitScreenDetectionResult.h"
#import "SplitScreenDetector.h"
#import "SplitShortcut.h"
#import "SplitStandardWindowMover.h"
#import "SplitWindowPositionCalculationResult.h"
#import "SplitWindowPositionCalculator.h"

@implementation SplitWindowPositionManager
{
  NSMutableDictionary<NSString *, SplitHistory *> *_applicationHistories;
  SplitScreenDetector *_screenDetector;
  SplitWindowPositionCalculator *_windowPositionCalculator;
  NSWorkspace *_sharedWorkspace;
  SplitFailureFeedback _failureFeedback;
  id<SplitWindowMover> _windowMover;
  /// Window → @[rect before full screen, full screen rect], so pressing full screen again restores it.
  NSMapTable<SplitAccessibilityElement *, NSArray<NSValue *> *> *_fullscreenRestoreRects;
}

/// Apps such as Terminal round their size to whole characters, so a window counts as still
/// full screen when every edge is within this distance of where Split put it.
static const CGFloat kFullscreenMatchTolerance = 24.0;

static BOOL RectsRoughlyEqual(CGRect a, CGRect b)
{
  return fabs(CGRectGetMinX(a) - CGRectGetMinX(b)) <= kFullscreenMatchTolerance
    && fabs(CGRectGetMinY(a) - CGRectGetMinY(b)) <= kFullscreenMatchTolerance
    && fabs(CGRectGetMaxX(a) - CGRectGetMaxX(b)) <= kFullscreenMatchTolerance
    && fabs(CGRectGetMaxY(a) - CGRectGetMaxY(b)) <= kFullscreenMatchTolerance;
}

- (instancetype)initWithScreenDetector:(SplitScreenDetector *)screenDetector
              windowPositionCalculator:(SplitWindowPositionCalculator *)windowPositionCalculator
                       sharedWorkspace:(NSWorkspace *)sharedWorkspace
                       failureFeedback:(SplitFailureFeedback)failureFeedback
                           windowMover:(id<SplitWindowMover>)windowMover
{
  if (self = [super init]) {
    _applicationHistories = [NSMutableDictionary new];
    _screenDetector = screenDetector;
    _windowPositionCalculator = windowPositionCalculator;
    _sharedWorkspace = sharedWorkspace;
    _failureFeedback = failureFeedback;
    _windowMover = windowMover;
    _fullscreenRestoreRects = [NSMapTable strongToStrongObjectsMapTable];
  }
  return self;
}

/// The rect to go back to when full screen is pressed on a window Split made full screen and
/// nobody has moved since. CGRectNull otherwise.
- (CGRect)fullscreenRestoreRectForElement:(SplitAccessibilityElement *)element
                                   action:(SplitWindowAction *)action
                               windowRect:(CGRect)windowRect
{
  if (![action isEqualToString:kSplitWindowActionFullscreen] || !element) {
    return CGRectNull;
  }
  NSArray<NSValue *> *rects = [_fullscreenRestoreRects objectForKey:element];
  if (!rects || !RectsRoughlyEqual(windowRect, NSRectToCGRect(rects[1].rectValue))) {
    return CGRectNull;
  }
  return NSRectToCGRect(rects[0].rectValue);
}

- (instancetype)initWithScreenDetector:(SplitScreenDetector *)screenDetector
              windowPositionCalculator:(SplitWindowPositionCalculator *)windowPositionCalculator
                       sharedWorkspace:(NSWorkspace *)sharedWorkspace
{
  return [self initWithScreenDetector:screenDetector
             windowPositionCalculator:windowPositionCalculator
                      sharedWorkspace:sharedWorkspace
                      failureFeedback:^() { NSBeep(); }
                          windowMover:[SplitStandardWindowMover newWithInnerWindowMover:
                                       [SplitQuantizedWindowMover newWithInnerWindowMover:
                                        [SplitBestEffortWindowMover new]]]];
}

- (void)moveFrontmostWindowElement:(SplitAccessibilityElement *)frontmostWindowElement
                            action:(SplitWindowAction *)action
                           screens:(NSArray<NSScreen *> *)screens
                        mainScreen:(NSScreen *)mainScreen
{
  SplitScreenDetectionResult *screenDetectionResult = [_screenDetector screenWithAction:action
                                                                     frontmostWindowElement:frontmostWindowElement
                                                                                    screens:screens
                                                                                 mainScreen:mainScreen];
  CGRect frameOfDestinationScreen = CGRectNull;
  CGRect visibleFrameOfDestinationScreen = CGRectNull;
  CGRect visibleFrameOfSourceScreen = CGRectNull;
  SplitHistory *history = [self historyForCurrentApplication];
  SplitHistoryItem *historyItem = nil;
  SplitWindowPositionCalculationResult *windowPositionCalculationResult = nil;
  if (screenDetectionResult.destinationScreen && screenDetectionResult.sourceScreen) {
    frameOfDestinationScreen = NSRectToCGRect([screenDetectionResult.destinationScreen frame]);
    visibleFrameOfDestinationScreen = NSRectToCGRect([screenDetectionResult.destinationScreen visibleFrame]);
    visibleFrameOfSourceScreen = NSRectToCGRect([screenDetectionResult.sourceScreen visibleFrame]);
  }
  CGRect frontmostWindowRect = [frontmostWindowElement rectOfElement];
  CGRect previousFrontmostWindowRect = CGRectNull;
  if ([frontmostWindowElement isSheet]
      || [frontmostWindowElement isSystemDialog]
      || CGRectIsNull(frontmostWindowRect)
      || CGRectIsNull(frameOfDestinationScreen)
      || CGRectIsNull(visibleFrameOfDestinationScreen)
      || CGRectIsNull(visibleFrameOfSourceScreen)) {
    _failureFeedback();
    return;
  }
  if ([history isEmpty]) {
    historyItem = [SplitHistoryItem historyItemFromAccessibilityElement:frontmostWindowElement
                                                                 windowRect:frontmostWindowRect];
    [history addHistoryItem:historyItem];
  }
  CGRect restoreRect = [self fullscreenRestoreRectForElement:frontmostWindowElement action:action windowRect:frontmostWindowRect];
  [_fullscreenRestoreRects removeObjectForKey:frontmostWindowElement];
  if (!CGRectIsNull(restoreRect)) {
    [history addHistoryItem:[SplitHistoryItem historyItemFromAccessibilityElement:frontmostWindowElement windowRect:restoreRect]];
    [_windowMover moveWindowRect:restoreRect
                   frameOfScreen:CGRectNull
            visibleFrameOfScreen:visibleFrameOfDestinationScreen
          frontmostWindowElement:frontmostWindowElement
                          action:kSplitWindowActionUndo];
    return;
  }
  CGRect rectBeforeMove = frontmostWindowRect;
  frontmostWindowRect = [SplitAccessibilityElement normalizeCoordinatesOfRect:frontmostWindowRect
                                                                    frameOfScreen:frameOfDestinationScreen];
  previousFrontmostWindowRect = frontmostWindowRect;
  windowPositionCalculationResult = [_windowPositionCalculator calculateWindowRect:frontmostWindowRect
                                                        visibleFrameOfSourceScreen:visibleFrameOfSourceScreen
                                                   visibleFrameOfDestinationScreen:visibleFrameOfDestinationScreen
                                                                            action:action];
  if (!windowPositionCalculationResult) {
    _failureFeedback();
    return;
  }
  action = windowPositionCalculationResult.action;
  frontmostWindowRect = windowPositionCalculationResult.windowRect;
  if (CGRectEqualToRect(previousFrontmostWindowRect, frontmostWindowRect)) {
    _failureFeedback();
    return;
  }
  frontmostWindowRect = [SplitAccessibilityElement normalizeCoordinatesOfRect:frontmostWindowRect
                                                                    frameOfScreen:frameOfDestinationScreen];
  historyItem = [SplitHistoryItem historyItemFromAccessibilityElement:frontmostWindowElement
                                                               windowRect:frontmostWindowRect];
  [history addHistoryItem:historyItem];
  if ([action isEqualToString:kSplitWindowActionFullscreen]) {
    [_fullscreenRestoreRects setObject:@[[NSValue valueWithRect:NSRectFromCGRect(rectBeforeMove)],
                                         [NSValue valueWithRect:NSRectFromCGRect(frontmostWindowRect)]]
                                forKey:frontmostWindowElement];
  }
  [_windowMover moveWindowRect:frontmostWindowRect
                 frameOfScreen:frameOfDestinationScreen
          visibleFrameOfScreen:visibleFrameOfDestinationScreen
        frontmostWindowElement:frontmostWindowElement
                        action:action];
}

- (void)moveFrontmostWindowElement:(SplitAccessibilityElement *)frontmostWindowElement
                            action:(SplitWindowAction *)action
{
  if (SplitIsUndoWindowAction(action)) {
    [self undoLastWindowAction];
  } else if (SplitIsRedoWindowAction(action)) {
    [self redoLastWindowAction];
  } else {
    [self moveFrontmostWindowElement:frontmostWindowElement
                              action:action
                             screens:[NSScreen screens]
                          mainScreen:[NSScreen mainScreen]];
  }
}

- (CGRect)targetRectForFrontmostWindowElement:(SplitAccessibilityElement *)frontmostWindowElement
                                       action:(SplitWindowAction *)action
{
  if (!frontmostWindowElement || SplitIsUndoWindowAction(action) || SplitIsRedoWindowAction(action)) {
    return CGRectNull;
  }
  SplitScreenDetectionResult *screenDetectionResult = [_screenDetector screenWithAction:action
                                                                     frontmostWindowElement:frontmostWindowElement
                                                                                    screens:[NSScreen screens]
                                                                                 mainScreen:[NSScreen mainScreen]];
  if (!screenDetectionResult.destinationScreen || !screenDetectionResult.sourceScreen) {
    return CGRectNull;
  }
  CGRect frameOfDestinationScreen = NSRectToCGRect(screenDetectionResult.destinationScreen.frame);
  CGRect visibleFrameOfDestinationScreen = NSRectToCGRect(screenDetectionResult.destinationScreen.visibleFrame);
  CGRect visibleFrameOfSourceScreen = NSRectToCGRect(screenDetectionResult.sourceScreen.visibleFrame);
  CGRect windowRect = [frontmostWindowElement rectOfElement];
  if ([frontmostWindowElement isSheet] || [frontmostWindowElement isSystemDialog] || CGRectIsNull(windowRect)) {
    return CGRectNull;
  }
  CGRect restoreRect = [self fullscreenRestoreRectForElement:frontmostWindowElement action:action windowRect:windowRect];
  if (!CGRectIsNull(restoreRect)) {
    return restoreRect;
  }
  windowRect = [SplitAccessibilityElement normalizeCoordinatesOfRect:windowRect frameOfScreen:frameOfDestinationScreen];
  SplitWindowPositionCalculationResult *result = [_windowPositionCalculator calculateWindowRect:windowRect
                                                                     visibleFrameOfSourceScreen:visibleFrameOfSourceScreen
                                                                visibleFrameOfDestinationScreen:visibleFrameOfDestinationScreen
                                                                                         action:action];
  if (!result || CGRectEqualToRect(result.windowRect, windowRect)) {
    return CGRectNull;
  }
  return [SplitAccessibilityElement normalizeCoordinatesOfRect:result.windowRect frameOfScreen:frameOfDestinationScreen];
}

- (void)undoLastWindowAction
{
  [self moveWithHistoryItem:[self historyForCurrentApplication].previousHistoryItem
                     action:kSplitWindowActionUndo
                    screens:[NSScreen screens]
                 mainScreen:[NSScreen mainScreen]];
}

- (void)redoLastWindowAction
{
  [self moveWithHistoryItem:[self historyForCurrentApplication].nextHistoryItem
                     action:kSplitWindowActionRedo
                    screens:[NSScreen screens]
                 mainScreen:[NSScreen mainScreen]];
}

- (SplitHistory *)historyForCurrentApplication
{
  NSString *frontmostApplicationBundleIdentifier = _sharedWorkspace.frontmostApplication.bundleIdentifier;
  if (!frontmostApplicationBundleIdentifier) {
    return nil;
  }
  if (!_applicationHistories[frontmostApplicationBundleIdentifier]) {
    _applicationHistories[frontmostApplicationBundleIdentifier] = [SplitHistory new];
  }
  return _applicationHistories[frontmostApplicationBundleIdentifier];
}

- (void)moveWithHistoryItem:(SplitHistoryItem *)historyItem
                     action:(SplitWindowAction *)action
                    screens:(NSArray<NSScreen *> *)screens
                 mainScreen:(NSScreen *)mainScreen
{
  SplitScreenDetectionResult *screenDetectionResult = [_screenDetector screenWithAction:action
                                                                     frontmostWindowElement:historyItem.accessibilityElement
                                                                                    screens:screens
                                                                                 mainScreen:mainScreen];
  CGRect visibleFrameOfScreen = CGRectNull;
  if (screenDetectionResult.destinationScreen) {
    visibleFrameOfScreen = NSRectToCGRect(screenDetectionResult.destinationScreen.visibleFrame);
  }
  if (![self moveWithHistoryItem:historyItem visibleFrameOfScreen:visibleFrameOfScreen action:action]) {
    _failureFeedback();
  }
}

- (BOOL)moveWithHistoryItem:(SplitHistoryItem *)historyItem
       visibleFrameOfScreen:(CGRect)visibleFrameOfScreen
                     action:(SplitWindowAction *)action
{
  SplitAccessibilityElement *frontmostWindowElement = historyItem.accessibilityElement;
  CGRect windowRect = historyItem.windowRect;
  if (!historyItem
      || !frontmostWindowElement
      || CGRectIsNull(windowRect)
      || CGRectIsNull(visibleFrameOfScreen)) {
    return NO;
  }
  [_windowMover moveWindowRect:windowRect
                 frameOfScreen:CGRectNull
          visibleFrameOfScreen:visibleFrameOfScreen
        frontmostWindowElement:frontmostWindowElement
                        action:action];
  return YES;
}

@end
