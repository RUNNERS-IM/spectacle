#import <Foundation/Foundation.h>

#import "SplitWindowAction.h"

@class SplitAccessibilityElement;

@protocol SplitWindowMover <NSObject>

- (instancetype)initWithInnerWindowMover:(id<SplitWindowMover>)innerWindowMover;

+ (instancetype)newWithInnerWindowMover:(id<SplitWindowMover>)innerWindowMover;

- (void)moveWindowRect:(CGRect)windowRect
         frameOfScreen:(CGRect)frameOfScreen
  visibleFrameOfScreen:(CGRect)visibleFrameOfScreen
frontmostWindowElement:(SplitAccessibilityElement *)frontmostWindowElement
                action:(SplitWindowAction *)action;

@end
