#import "SplitBestEffortWindowMover.h"

#import "SplitAccessibilityElement.h"
#import "SplitWindowPositionManager.h"

@implementation SplitBestEffortWindowMover
{
  id<SplitWindowMover> _innerWindowMover;
}

- (instancetype)initWithInnerWindowMover:(id<SplitWindowMover>)innerWindowMover
{
  if (self = [super init]) {
    _innerWindowMover = innerWindowMover;
  }
  return self;
}

- (instancetype)init
{
  return [self initWithInnerWindowMover:nil];
}

+ (instancetype)newWithInnerWindowMover:(id<SplitWindowMover>)innerWindowMover
{
  return [[self alloc] initWithInnerWindowMover:innerWindowMover];
}

- (void)moveWindowRect:(CGRect)windowRect
         frameOfScreen:(CGRect)frameOfScreen
  visibleFrameOfScreen:(CGRect)visibleFrameOfScreen
frontmostWindowElement:(SplitAccessibilityElement *)frontmostWindowElement
                action:(SplitWindowAction *)action
{
  [_innerWindowMover moveWindowRect:windowRect
                      frameOfScreen:frameOfScreen
               visibleFrameOfScreen:visibleFrameOfScreen
             frontmostWindowElement:frontmostWindowElement
                             action:action];
  CGRect movedWindowRect = [frontmostWindowElement rectOfElement];
  CGRect previouslyMovedWindowRect = movedWindowRect;
  if (movedWindowRect.origin.x < visibleFrameOfScreen.origin.x) {
    movedWindowRect.origin.x = visibleFrameOfScreen.origin.x;
  } else if ((movedWindowRect.origin.x + movedWindowRect.size.width) > (visibleFrameOfScreen.origin.x + visibleFrameOfScreen.size.width)) {
    movedWindowRect.origin.x = visibleFrameOfScreen.origin.x + visibleFrameOfScreen.size.width - movedWindowRect.size.width;
  }
  movedWindowRect = [SplitAccessibilityElement normalizeCoordinatesOfRect:movedWindowRect
                                                                frameOfScreen:frameOfScreen];
  if (movedWindowRect.origin.y < visibleFrameOfScreen.origin.y) {
    movedWindowRect.origin.y = visibleFrameOfScreen.origin.y;
  } else if ((movedWindowRect.origin.y + movedWindowRect.size.height) > (visibleFrameOfScreen.origin.y + visibleFrameOfScreen.size.height)) {
    movedWindowRect.origin.y = visibleFrameOfScreen.origin.y + visibleFrameOfScreen.size.height - movedWindowRect.size.height;
  }
  movedWindowRect = [SplitAccessibilityElement normalizeCoordinatesOfRect:movedWindowRect
                                                                frameOfScreen:frameOfScreen];
  if (!CGRectEqualToRect(movedWindowRect, previouslyMovedWindowRect)) {
    [frontmostWindowElement setRectOfElement:movedWindowRect];
  }
}

@end
