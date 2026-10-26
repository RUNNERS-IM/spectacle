windowPositionCalculationRegistry.registerWindowPositionCalculationWithAction(function (windowRect, visibleFrameOfSourceScreen, visibleFrameOfDestinationScreen) {
    return SplitNextOrPreviousThirds.findPreviousThird(windowRect, visibleFrameOfDestinationScreen);
}, "SplitWindowActionPreviousThird");
