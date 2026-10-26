windowPositionCalculationRegistry.registerWindowPositionCalculationWithAction(function (windowRect, visibleFrameOfSourceScreen, visibleFrameOfDestinationScreen) {
    return SplitWindowSizeAdjuster.resizeWindowRect(windowRect, visibleFrameOfDestinationScreen, -30.0);
}, "SplitWindowActionSmaller");
