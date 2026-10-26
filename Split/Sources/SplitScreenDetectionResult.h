#import <Foundation/Foundation.h>

#import "SplitMacros.h"

@class NSScreen;

@interface SplitScreenDetectionResult : NSObject

@property (nonatomic, readonly, strong) NSScreen *sourceScreen;
@property (nonatomic, readonly, strong) NSScreen *destinationScreen;

- (instancetype)initWithSourceScreen:(NSScreen *)sourceScreen
                   destinationScreen:(NSScreen *)destinationScreen NS_DESIGNATED_INITIALIZER;

+ (instancetype)resultWithSourceScreen:(NSScreen *)sourceScreen
                     destinationScreen:(NSScreen *)destinationScreen;

SPECTACLE_INIT_AND_NEW_UNAVAILABLE

@end
