#import <Foundation/Foundation.h>

#import "SplitWindowMover.h"

@interface SplitStandardWindowMover : NSObject <SplitWindowMover>

- (instancetype)initWithInnerWindowMover:(id<SplitWindowMover>)innerWindowMover NS_DESIGNATED_INITIALIZER;

@end
