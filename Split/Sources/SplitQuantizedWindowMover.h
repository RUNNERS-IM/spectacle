#import <Foundation/Foundation.h>

#import "SplitWindowMover.h"

@interface SplitQuantizedWindowMover : NSObject <SplitWindowMover>

- (instancetype)initWithInnerWindowMover:(id<SplitWindowMover>)innerWindowMover NS_DESIGNATED_INITIALIZER;

@end
