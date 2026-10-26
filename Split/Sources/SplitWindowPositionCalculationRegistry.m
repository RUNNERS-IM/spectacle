#import "SplitWindowPositionCalculationRegistry.h"

#import "SplitJavaScriptEnvironment.h"
#import "SplitWindowPositionCalculationResult.h"

@interface SplitWindowPositionCalculationRegistry ()

@property (nonatomic, readonly, strong) SplitJavaScriptEnvironment *javaScriptEnvironment;

@end

@implementation SplitWindowPositionCalculationRegistry
{
  NSMutableDictionary<SplitWindowAction *, JSValue *> *_windowPositionCalculations;
}

- (instancetype)init
{
  if (self = [super init]) {
    _windowPositionCalculations = [NSMutableDictionary new];
  }
  return self;
}

- (void)registerWindowPositionCalculation:(JSValue *)windowPositionCalculation withAction:(SplitWindowAction *)action
{
  _windowPositionCalculations[action] = windowPositionCalculation;
}

- (JSValue *)windowPositionCalculationWithAction:(SplitWindowAction *)action
{
  return _windowPositionCalculations[action];
}

@end
