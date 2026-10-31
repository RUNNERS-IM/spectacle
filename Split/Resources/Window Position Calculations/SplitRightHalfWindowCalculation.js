windowPositionCalculationRegistry.registerWindowPositionCalculationWithAction(function (windowRect, visibleFrameOfSourceScreen, visibleFrameOfDestinationScreen) {
    var oneHalfRect = SplitCalculationHelpers.copyRect(visibleFrameOfDestinationScreen);
    oneHalfRect.width = Math.floor(oneHalfRect.width / 2.0);
    oneHalfRect.x += oneHalfRect.width;
    if (Math.abs(CGRectGetMidY(windowRect) - CGRectGetMidY(oneHalfRect)) <= 1.0) {
        var threeQuartersRect = SplitCalculationHelpers.copyRect(oneHalfRect);
        threeQuartersRect.width = Math.floor(visibleFrameOfDestinationScreen.width * 3 / 4.0);
        threeQuartersRect.x = visibleFrameOfDestinationScreen.x + visibleFrameOfDestinationScreen.width - threeQuartersRect.width;
        if (SplitCalculationHelpers.rectCenteredWithinRect(oneHalfRect, windowRect)) {
            return threeQuartersRect;
        }
        if (SplitCalculationHelpers.rectCenteredWithinRect(threeQuartersRect, windowRect)) {
            var oneFourthRect = SplitCalculationHelpers.copyRect(oneHalfRect);
            oneFourthRect.width = Math.floor(visibleFrameOfDestinationScreen.width / 4.0);
            oneFourthRect.x = visibleFrameOfDestinationScreen.x + visibleFrameOfDestinationScreen.width - oneFourthRect.width;
            return oneFourthRect;
        }
    }
    return oneHalfRect;
}, "SplitWindowActionRightHalf");
