#import "SplitWindowAction.h"

SplitWindowAction *const kSplitWindowActionUndo = @"SplitWindowActionUndo";
SplitWindowAction *const kSplitWindowActionRedo = @"SplitWindowActionRedo";
SplitWindowAction *const kSplitWindowActionLarger = @"SplitWindowActionLarger";
SplitWindowAction *const kSplitWindowActionSmaller = @"SplitWindowActionSmaller";
SplitWindowAction *const kSplitWindowActionNone = @"SplitWindowActionNone";
SplitWindowAction *const kSplitWindowActionCenter = @"SplitWindowActionCenter";
SplitWindowAction *const kSplitWindowActionFullscreen = @"SplitWindowActionFullscreen";
SplitWindowAction *const kSplitWindowActionLeftHalf = @"SplitWindowActionLeftHalf";
SplitWindowAction *const kSplitWindowActionUpperLeft = @"SplitWindowActionUpperLeft";
SplitWindowAction *const kSplitWindowActionLowerLeft = @"SplitWindowActionLowerLeft";
SplitWindowAction *const kSplitWindowActionRightHalf = @"SplitWindowActionRightHalf";
SplitWindowAction *const kSplitWindowActionUpperRight = @"SplitWindowActionUpperRight";
SplitWindowAction *const kSplitWindowActionLowerRight = @"SplitWindowActionLowerRight";
SplitWindowAction *const kSplitWindowActionTopHalf = @"SplitWindowActionTopHalf";
SplitWindowAction *const kSplitWindowActionBottomHalf = @"SplitWindowActionBottomHalf";
SplitWindowAction *const kSplitWindowActionNextDisplay = @"SplitWindowActionNextDisplay";
SplitWindowAction *const kSplitWindowActionPreviousDisplay = @"SplitWindowActionPreviousDisplay";
SplitWindowAction *const kSplitWindowActionNextThird = @"SplitWindowActionNextThird";
SplitWindowAction *const kSplitWindowActionPreviousThird = @"SplitWindowActionPreviousThird";

BOOL SplitIsUndoWindowAction(SplitWindowAction *action)
{
  return [action isEqualToString:kSplitWindowActionUndo];
}

BOOL SplitIsRedoWindowAction(SplitWindowAction *action)
{
  return [action isEqualToString:kSplitWindowActionRedo];
}

BOOL SplitIsNextDisplayWindowAction(SplitWindowAction *action)
{
  return [action isEqualToString:kSplitWindowActionNextDisplay];
}

BOOL SplitIsPreviousDisplayWindowAction(SplitWindowAction *action)
{
  return [action isEqualToString:kSplitWindowActionPreviousDisplay];
}

BOOL SplitIsMovingToDisplayWindowAction(SplitWindowAction *action)
{
  return SplitIsNextDisplayWindowAction(action) || SplitIsPreviousDisplayWindowAction(action);
}
