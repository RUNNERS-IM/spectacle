windowPositionCalculationRegistry.registerWindowPositionCalculationWithAction(function (windowRect, visibleFrameOfSourceScreen, visibleFrameOfDestinationScreen) {
    var oneQuarterRect = SplitCalculationHelpers.copyRect(visibleFrameOfDestinationScreen);
    oneQuarterRect.width = Math.floor(visibleFrameOfDestinationScreen.width / 2.0);
    oneQuarterRect.height = Math.floor(visibleFrameOfDestinationScreen.height / 2.0);
    oneQuarterRect.x += oneQuarterRect.width;
    oneQuarterRect.y = visibleFrameOfDestinationScreen.y + Math.floor(visibleFrameOfDestinationScreen.height / 2.0) + (visibleFrameOfDestinationScreen.height % 2.0);
    if (Math.abs(CGRectGetMidY(windowRect) - CGRectGetMidY(oneQuarterRect)) <= 1.0) {
        var twoThirdRect = SplitCalculationHelpers.copyRect(oneQuarterRect);
        twoThirdRect.width = Math.floor(visibleFrameOfDestinationScreen.width * 2 / 3.0);
        twoThirdRect.x = visibleFrameOfDestinationScreen.x + visibleFrameOfDestinationScreen.width - twoThirdRect.width;
        if (SplitCalculationHelpers.rectCenteredWithinRect(oneQuarterRect, windowRect)) {
            return twoThirdRect;
        }
        if (SplitCalculationHelpers.rectCenteredWithinRect(twoThirdRect, windowRect)) {
            var oneThirdsRect = SplitCalculationHelpers.copyRect(oneQuarterRect);
            oneThirdsRect.width = Math.floor(visibleFrameOfDestinationScreen.width / 3.0);
            oneThirdsRect.x = visibleFrameOfDestinationScreen.x + visibleFrameOfDestinationScreen.width - oneThirdsRect.width;
            return oneThirdsRect;
        }
    }
    return oneQuarterRect;
}, "SplitWindowActionUpperRight");
