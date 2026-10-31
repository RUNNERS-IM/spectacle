windowPositionCalculationRegistry.registerWindowPositionCalculationWithAction(function (windowRect, visibleFrameOfSourceScreen, visibleFrameOfDestinationScreen) {
    var oneQuarterRect = SplitCalculationHelpers.copyRect(visibleFrameOfDestinationScreen);
    oneQuarterRect.width = Math.floor(visibleFrameOfDestinationScreen.width / 2.0);
    oneQuarterRect.height = Math.floor(visibleFrameOfDestinationScreen.height / 2.0);
    oneQuarterRect.x += oneQuarterRect.width;
    oneQuarterRect.y = visibleFrameOfDestinationScreen.y + Math.floor(visibleFrameOfDestinationScreen.height / 2.0) + (visibleFrameOfDestinationScreen.height % 2.0);
    if (Math.abs(CGRectGetMidY(windowRect) - CGRectGetMidY(oneQuarterRect)) <= 1.0) {
        var threeQuartersRect = SplitCalculationHelpers.copyRect(oneQuarterRect);
        threeQuartersRect.width = Math.floor(visibleFrameOfDestinationScreen.width * 3 / 4.0);
        threeQuartersRect.x = visibleFrameOfDestinationScreen.x + visibleFrameOfDestinationScreen.width - threeQuartersRect.width;
        if (SplitCalculationHelpers.rectCenteredWithinRect(oneQuarterRect, windowRect)) {
            return threeQuartersRect;
        }
        if (SplitCalculationHelpers.rectCenteredWithinRect(threeQuartersRect, windowRect)) {
            var oneFourthRect = SplitCalculationHelpers.copyRect(oneQuarterRect);
            oneFourthRect.width = Math.floor(visibleFrameOfDestinationScreen.width / 4.0);
            oneFourthRect.x = visibleFrameOfDestinationScreen.x + visibleFrameOfDestinationScreen.width - oneFourthRect.width;
            return oneFourthRect;
        }
    }
    return oneQuarterRect;
}, "SplitWindowActionUpperRight");
