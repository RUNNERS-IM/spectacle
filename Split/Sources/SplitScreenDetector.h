#import <Cocoa/Cocoa.h>

#import "SplitWindowAction.h"

@class SplitAccessibilityElement;
@class SplitScreenDetectionResult;

@interface SplitScreenDetector : NSObject

- (SplitScreenDetectionResult *)screenWithAction:(SplitWindowAction *)action
                              frontmostWindowElement:(SplitAccessibilityElement *)frontmostWindowElement
                                             screens:(NSArray<NSScreen *> *)screens
                                          mainScreen:(NSScreen *)mainScreen;

@end
