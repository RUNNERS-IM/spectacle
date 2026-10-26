#import <Foundation/Foundation.h>

typedef NSString SplitWindowAction;

extern SplitWindowAction *const kSplitWindowActionUndo;
extern SplitWindowAction *const kSplitWindowActionRedo;
extern SplitWindowAction *const kSplitWindowActionLarger;
extern SplitWindowAction *const kSplitWindowActionSmaller;
extern SplitWindowAction *const kSplitWindowActionNone;
extern SplitWindowAction *const kSplitWindowActionCenter;
extern SplitWindowAction *const kSplitWindowActionFullscreen;
extern SplitWindowAction *const kSplitWindowActionLeftHalf;
extern SplitWindowAction *const kSplitWindowActionUpperLeft;
extern SplitWindowAction *const kSplitWindowActionLowerLeft;
extern SplitWindowAction *const kSplitWindowActionRightHalf;
extern SplitWindowAction *const kSplitWindowActionUpperRight;
extern SplitWindowAction *const kSplitWindowActionLowerRight;
extern SplitWindowAction *const kSplitWindowActionTopHalf;
extern SplitWindowAction *const kSplitWindowActionBottomHalf;
extern SplitWindowAction *const kSplitWindowActionNextDisplay;
extern SplitWindowAction *const kSplitWindowActionPreviousDisplay;
extern SplitWindowAction *const kSplitWindowActionNextThird;
extern SplitWindowAction *const kSplitWindowActionPreviousThird;

BOOL SplitIsUndoWindowAction(SplitWindowAction *action);
BOOL SplitIsRedoWindowAction(SplitWindowAction *action);

BOOL SplitIsNextDisplayWindowAction(SplitWindowAction *action);
BOOL SplitIsPreviousDisplayWindowAction(SplitWindowAction *action);
BOOL SplitIsMovingToDisplayWindowAction(SplitWindowAction *action);
