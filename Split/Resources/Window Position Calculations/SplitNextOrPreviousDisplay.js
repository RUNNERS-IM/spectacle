var SplitNextOrPreviousDisplay = (function () {
    var moveWindowRectToDisplay = function(windowRect, visibleFrameOfSourceScreen, visibleFrameOfDestinationScreen) {
        if (SplitCalculationHelpers.rectFitsWithinRect(windowRect, visibleFrameOfDestinationScreen)) {
            return SplitCenterWindowCalculation.centerWindowRectInVisibleFrameOfScreen(windowRect, visibleFrameOfDestinationScreen);
        } else {
            return visibleFrameOfDestinationScreen;
        }
    };
    return {
        moveWindowRectToDisplay: moveWindowRectToDisplay,
    };
})();
