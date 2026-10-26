#import <Cocoa/Cocoa.h>

#import "SplitMacros.h"
#import "SplitWindowAction.h"

typedef void (^SplitFailureFeedback)(void);

@class SplitAccessibilityElement;
@class SplitScreenDetector;
@class SplitShortcut;
@class SplitWindowPositionCalculator;

@protocol SplitWindowMover;

@interface SplitWindowPositionManager : NSObject

- (instancetype)initWithScreenDetector:(SplitScreenDetector *)screenDetector
              windowPositionCalculator:(SplitWindowPositionCalculator *)windowPositionCalculator
                       sharedWorkspace:(NSWorkspace *)sharedWorkspace
                       failureFeedback:(SplitFailureFeedback)failureFeedback
                           windowMover:(id<SplitWindowMover>)windowMover NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithScreenDetector:(SplitScreenDetector *)screenDetector
              windowPositionCalculator:(SplitWindowPositionCalculator *)windowPositionCalculator
                       sharedWorkspace:(NSWorkspace *)sharedWorkspace;

SPECTACLE_INIT_AND_NEW_UNAVAILABLE

- (void)moveFrontmostWindowElement:(SplitAccessibilityElement *)frontmostWindowElement
                            action:(SplitWindowAction *)action
                           screens:(NSArray<NSScreen *> *)screens
                        mainScreen:(NSScreen *)mainScreen;

- (void)moveFrontmostWindowElement:(SplitAccessibilityElement *)frontmostWindowElement
                            action:(SplitWindowAction *)action;

/// Where the frontmost window would go for `action`, in the same top-left based screen
/// coordinates the Accessibility API uses, without moving it or touching the undo history.
/// Returns CGRectNull when the window cannot be moved or would not change.
- (CGRect)targetRectForFrontmostWindowElement:(SplitAccessibilityElement *)frontmostWindowElement
                                       action:(SplitWindowAction *)action;

- (void)undoLastWindowAction;
- (void)redoLastWindowAction;

@end
