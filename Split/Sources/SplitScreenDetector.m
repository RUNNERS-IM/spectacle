#import "SplitScreenDetector.h"

#import "SplitAccessibilityElement.h"
#import "SplitScreenDetectionResult.h"

@implementation SplitScreenDetector

- (SplitScreenDetectionResult *)screenWithAction:(SplitWindowAction *)action
                              frontmostWindowElement:(SplitAccessibilityElement *)frontmostWindowElement
                                             screens:(NSArray<NSScreen *> *)screens
                                          mainScreen:(NSScreen *)mainScreen
{
  NSArray<NSScreen *> *screensInConsistentOrder = [self screensInConsistentOrder:screens];
  NSScreen *sourceScreen = [self screenContainingRect:[frontmostWindowElement rectOfElement]
                                              screens:screensInConsistentOrder
                                           mainScreen:mainScreen];
  NSScreen *destinationScreen = sourceScreen;
  if (SplitIsMovingToDisplayWindowAction(action)) {
    destinationScreen = [self nextOrPreviousScreenToFrameOfScreen:NSRectToCGRect([sourceScreen frame])
                                              inDirectionOfAction:action
                                                          screens:screensInConsistentOrder];
  }
  return [SplitScreenDetectionResult resultWithSourceScreen:sourceScreen destinationScreen:destinationScreen];
}

- (NSScreen *)screenContainingRect:(CGRect)rect
                           screens:(NSArray<NSScreen *> *)screens
                        mainScreen:(NSScreen *)mainScreen
{
  CGFloat largestPercentageOfRectWithinFrameOfScreen = 0.0f;
  NSScreen *result = mainScreen;
  for (NSScreen *currentScreen in screens) {
    CGRect currentFrameOfScreen = NSRectToCGRect(currentScreen.frame);
    CGRect normalizedRect = [SplitAccessibilityElement normalizeCoordinatesOfRect:rect
                                                                        frameOfScreen:currentFrameOfScreen];
    if (CGRectContainsRect(currentFrameOfScreen, normalizedRect)) {
      result = currentScreen;
      break;
    }
    CGFloat percentageOfRectWithinCurrentFrameOfScreen = [self percentageOfRect:normalizedRect
                                                            withinFrameOfScreen:currentFrameOfScreen];
    if (percentageOfRectWithinCurrentFrameOfScreen > largestPercentageOfRectWithinFrameOfScreen) {
      largestPercentageOfRectWithinFrameOfScreen = percentageOfRectWithinCurrentFrameOfScreen;
      result = currentScreen;
    }
  }
  return result;
}

- (CGFloat)percentageOfRect:(CGRect)rect withinFrameOfScreen:(CGRect)frameOfScreen
{
  CGRect intersectionOfRectAndFrameOfScreen = CGRectIntersection(rect, frameOfScreen);
  CGFloat result = 0.0f;
  if (!CGRectIsNull(intersectionOfRectAndFrameOfScreen)) {
    result = computeAreaOfRect(intersectionOfRectAndFrameOfScreen) / computeAreaOfRect(rect);
  }
  return result;
}

- (NSScreen *)nextOrPreviousScreenToFrameOfScreen:(CGRect)frameOfScreen
                              inDirectionOfAction:(SplitWindowAction *)action
                                          screens:(NSArray<NSScreen *> *)screens
{
  NSScreen *result = nil;
  if (screens.count <= 1) {
    return result;
  }
  for (NSInteger i = 0; i < screens.count; i++) {
    NSScreen *currentScreen = screens[i];
    CGRect currentFrameOfScreen = NSRectToCGRect(currentScreen.frame);
    NSInteger nextOrPreviousIndex = i;
    if (!CGRectEqualToRect(currentFrameOfScreen, frameOfScreen)) {
      continue;
    }
    if (SplitIsNextDisplayWindowAction(action)) {
      nextOrPreviousIndex++;
    } else if (SplitIsPreviousDisplayWindowAction(action)) {
      nextOrPreviousIndex--;
    }
    if (nextOrPreviousIndex < 0) {
      nextOrPreviousIndex = screens.count - 1;
    } else if (nextOrPreviousIndex >= screens.count) {
      nextOrPreviousIndex = 0;
    }
    result = screens[nextOrPreviousIndex];
    break;
  }
  return result;
}

- (NSArray<NSScreen *> *)screensInConsistentOrder:(NSArray<NSScreen *> *)screens
{
  return [[screens sortedArrayWithOptions:NSSortStable usingComparator:^(NSScreen *screenOne, NSScreen *screenTwo) {
    if (CGPointEqualToPoint(screenOne.frame.origin, CGPointMake(0, 0))) {
      return NSOrderedAscending;
    } else if (CGPointEqualToPoint(screenTwo.frame.origin, CGPointMake(0, 0))) {
      return NSOrderedDescending;
    }
    return (NSComparisonResult)(screenTwo.frame.origin.y - screenOne.frame.origin.y);
  }] sortedArrayWithOptions:NSSortStable usingComparator:^(NSScreen *screenOne, NSScreen *screenTwo) {
    if (CGPointEqualToPoint(screenOne.frame.origin, CGPointMake(0, 0))) {
      return NSOrderedAscending;
    } else if (CGPointEqualToPoint(screenTwo.frame.origin, CGPointMake(0, 0))) {
      return NSOrderedDescending;
    }
    return (NSComparisonResult)(screenTwo.frame.origin.x - screenOne.frame.origin.x);
  }];
}

static CGFloat computeAreaOfRect(CGRect rect)
{
  return rect.size.width * rect.size.height;
}

@end
