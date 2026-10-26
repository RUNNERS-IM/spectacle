#import <Foundation/Foundation.h>

#import "SplitMacros.h"
#import "SplitWindowAction.h"

@interface SplitWindowPositionCalculationResult : NSObject

@property (nonatomic, readonly, strong) SplitWindowAction *action;
@property (nonatomic, readonly, assign) CGRect windowRect;

- (instancetype)initWithAction:(SplitWindowAction *)action windowRect:(CGRect)windowRect NS_DESIGNATED_INITIALIZER;

+ (instancetype)resultWithAction:(SplitWindowAction *)action windowRect:(CGRect)windowRect;

SPECTACLE_INIT_AND_NEW_UNAVAILABLE

@end
