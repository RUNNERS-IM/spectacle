#import "SplitStandardWindowMover.h"

#import "SplitAccessibilityElement.h"

@implementation SplitStandardWindowMover
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
  CGRect previousWindowRect = [frontmostWindowElement rectOfElement];
  if (CGRectIsNull(previousWindowRect)) {
    return;
  }
  [frontmostWindowElement setRectOfElement:windowRect];
  [_innerWindowMover moveWindowRect:windowRect
                      frameOfScreen:frameOfScreen
               visibleFrameOfScreen:visibleFrameOfScreen
             frontmostWindowElement:frontmostWindowElement
                             action:action];
}

@end
