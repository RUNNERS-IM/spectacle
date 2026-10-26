#import <Foundation/Foundation.h>

#import "SplitMacros.h"
#import "SplitWindowAction.h"

@class SplitWindowPositionCalculationResult;

@interface SplitWindowPositionCalculator : NSObject

- (instancetype)initWithErrorHandler:(void(^)(NSString *message))errorHandler NS_DESIGNATED_INITIALIZER;

- (SplitWindowPositionCalculationResult *)calculateWindowRect:(CGRect)windowRect
                                       visibleFrameOfSourceScreen:(CGRect)visibleFrameOfSourceScreen
                                  visibleFrameOfDestinationScreen:(CGRect)visibleFrameOfDestinationScreen
                                                           action:(SplitWindowAction *)action;

SPECTACLE_INIT_AND_NEW_UNAVAILABLE

@end
