windowPositionCalculationRegistry.registerWindowPositionCalculationWithAction(function (windowRect, visibleFrameOfSourceScreen, visibleFrameOfDestinationScreen) {
    var oneHalfRect = SplitCalculationHelpers.copyRect(visibleFrameOfDestinationScreen);
    oneHalfRect.height = Math.floor(oneHalfRect.height / 2.0);
    oneHalfRect.y += oneHalfRect.height + (visibleFrameOfDestinationScreen.height % 2.0);
    if (Math.abs(CGRectGetMidX(windowRect) - CGRectGetMidX(oneHalfRect)) <= 1.0) {
        var threeQuartersRect = SplitCalculationHelpers.copyRect(oneHalfRect);
        threeQuartersRect.height = Math.floor(visibleFrameOfDestinationScreen.height * 3 / 4.0);
        threeQuartersRect.y = visibleFrameOfDestinationScreen.y + visibleFrameOfDestinationScreen.height - threeQuartersRect.height;
        if (SplitCalculationHelpers.rectCenteredWithinRect(oneHalfRect, windowRect)) {
            return threeQuartersRect;
        }
        if (SplitCalculationHelpers.rectCenteredWithinRect(threeQuartersRect, windowRect)) {
            var oneFourthRect = SplitCalculationHelpers.copyRect(oneHalfRect);
            oneFourthRect.height = Math.floor(visibleFrameOfDestinationScreen.height / 4.0);
            oneFourthRect.y = visibleFrameOfDestinationScreen.y + visibleFrameOfDestinationScreen.height - oneFourthRect.height;
            return oneFourthRect;
        }
    }
    return oneHalfRect;
}, "SplitWindowActionTopHalf");
