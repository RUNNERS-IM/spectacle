#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

#import "SplitWindowAction.h"

@class SplitWindowPositionCalculationResult;

typedef CGRect *(^SplitWindowPositionCalculation)(CGRect windowRect,
                                                      CGRect visibleFrameOfSourceScreen,
                                                      CGRect visibleFrameOfDestinationScreen);

@protocol SplitWindowPositionCalculationRegistryExports <JSExport>

- (void)registerWindowPositionCalculation:(JSValue *)windowPositionCalculation withAction:(NSString *)action;

@end

@interface SplitWindowPositionCalculationRegistry : NSObject <SplitWindowPositionCalculationRegistryExports>

- (JSValue *)windowPositionCalculationWithAction:(SplitWindowAction *)action;

@end
