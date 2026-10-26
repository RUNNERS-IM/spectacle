windowPositionCalculationRegistry.registerWindowPositionCalculationWithAction(function (windowRect, visibleFrameOfSourceScreen, visibleFrameOfDestinationScreen) {
    return SplitNextOrPreviousThirds.findNextThird(windowRect, visibleFrameOfDestinationScreen);
}, "SplitWindowActionNextThird");
