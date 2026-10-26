#import "SplitWindowPositionCalculator.h"

#import <JavaScriptCore/JavaScriptCore.h>

#import "SplitJavaScriptEnvironment.h"
#import "SplitWindowPositionCalculationRegistry.h"
#import "SplitWindowPositionCalculationResult.h"

@implementation SplitWindowPositionCalculator
{
  SplitWindowPositionCalculationRegistry *_windowPositionCalculationRegistry;
  SplitJavaScriptEnvironment *_javaScriptEnvironment;
}

- (instancetype)initWithErrorHandler:(void(^)(NSString *message))errorHandler
{
  if (self = [super init]) {
    _windowPositionCalculationRegistry = [SplitWindowPositionCalculationRegistry new];
    _javaScriptEnvironment = [[SplitJavaScriptEnvironment alloc] initWithContextBuilder:^(JSContext *context) {
      context.exceptionHandler = ^(JSContext *context, JSValue *exception) {
        NSString *errorName = [exception[@"name"] toString];
        NSString *errorMessage = [exception[@"message"] toString];
        errorHandler([NSString stringWithFormat:@"%@\n%@", errorName, errorMessage]);
      };
      context[@"windowPositionCalculationRegistry"] = self->_windowPositionCalculationRegistry;
      context[@"CGRectContainsRect"] = ^BOOL(CGRect rect1, CGRect rect2) {
        return CGRectContainsRect(rect1, rect2);
      };
      context[@"CGRectEqualToRect"] = ^BOOL(CGRect rect1, CGRect rect2) {
        return CGRectEqualToRect(rect1, rect2);
      };
      context[@"CGRectGetMinX"] = ^CGFloat(CGRect rect) {
        return CGRectGetMinX(rect);
      };
      context[@"CGRectGetMinY"] = ^CGFloat(CGRect rect) {
        return CGRectGetMinY(rect);
      };
      context[@"CGRectGetMidX"] = ^CGFloat(CGRect rect) {
        return CGRectGetMidX(rect);
      };
      context[@"CGRectGetMidY"] = ^CGFloat(CGRect rect) {
        return CGRectGetMidY(rect);
      };
      context[@"CGRectGetMaxX"] = ^CGFloat(CGRect rect) {
        return CGRectGetMaxX(rect);
      };
      context[@"CGRectGetMaxY"] = ^CGFloat(CGRect rect) {
        return CGRectGetMaxY(rect);
      };
    }];
  }
  return self;
}

- (SplitWindowPositionCalculationResult *)calculateWindowRect:(CGRect)windowRect
                                       visibleFrameOfSourceScreen:(CGRect)visibleFrameOfSourceScreen
                                  visibleFrameOfDestinationScreen:(CGRect)visibleFrameOfDestinationScreen
                                                           action:(SplitWindowAction *)action
{
  JSValue *windowPositionCalculation = [_windowPositionCalculationRegistry windowPositionCalculationWithAction:action];
  if (!windowPositionCalculation) {
    return nil;
  }
  JSValue *result = [windowPositionCalculation callWithArguments:@[
                                                                   [_javaScriptEnvironment valueWithRect:windowRect],
                                                                   [_javaScriptEnvironment valueWithRect:visibleFrameOfSourceScreen],
                                                                   [_javaScriptEnvironment valueWithRect:visibleFrameOfDestinationScreen],
                                                                   ]];
  return [SplitWindowPositionCalculationResult resultWithAction:action windowRect:[result toRect]];
}

@end
