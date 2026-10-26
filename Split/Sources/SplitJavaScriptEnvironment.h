#import <Foundation/Foundation.h>

#import "SplitMacros.h"

@class JSContext;
@class JSValue;
@class SplitWindowPositionCalculationResult;

@interface SplitJavaScriptEnvironment : NSObject

- (instancetype)initWithContextBuilder:(void(^)(JSContext *))contextBuilder NS_DESIGNATED_INITIALIZER;

- (JSValue *)valueWithRect:(CGRect)rect;

SPECTACLE_INIT_AND_NEW_UNAVAILABLE

@end
