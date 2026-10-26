#import "SplitWindowPositionCalculationResult.h"

@implementation SplitWindowPositionCalculationResult

@synthesize action = _action;
@synthesize windowRect = _windowRect;

- (instancetype)initWithAction:(SplitWindowAction *)action windowRect:(CGRect)windowRect
{
  if (self = [super init]) {
    _action = action;
    _windowRect = windowRect;
  }
  return self;
}

+ (instancetype)resultWithAction:(SplitWindowAction *)action windowRect:(CGRect)windowRect
{
  return [[SplitWindowPositionCalculationResult alloc] initWithAction:action windowRect:windowRect];
}

@end
