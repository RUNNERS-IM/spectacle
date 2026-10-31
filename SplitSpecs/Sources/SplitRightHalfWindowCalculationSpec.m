#import <Expecta/Expecta.h>
#import <Specta/Specta.h>

#import "SplitWindowPositionCalculationResult.h"
#import "SplitWindowPositionCalculator.h"

SpecBegin(SplitRightHalfWindowCalculation)
describe(@"SplitRightHalfWindowCalculation", ^{
  CGRect visibleFrameSourceScreen = CGRectMake(0.0f, 4.0f, 1440.0f, 873.0f);
  CGRect visibleFrameDestinationScreen = CGRectMake(0.0f, 4.0f, 1440.0f, 873.0f);
  SplitWindowPositionCalculator *windowPositionCalculator = [[SplitWindowPositionCalculator alloc] initWithErrorHandler:^(NSString *message) {
    EXP_failure(message);
  }];

  it(@"should calculate a window's CGRect in the right half of the screen", ^{
    SplitWindowPositionCalculationResult *result = [windowPositionCalculator calculateWindowRect:CGRectMake(165.0f, 245.0f, 564.0f, 384.0f)
                                                                          visibleFrameOfSourceScreen:visibleFrameSourceScreen
                                                                     visibleFrameOfDestinationScreen:visibleFrameDestinationScreen
                                                                                              action:kSplitWindowActionRightHalf];
    expect(result.windowRect).to.equal(CGRectMake(720.0f, 4.0f, 720.0f, 873.0f));
  });

  it(@"should calculate a window's CGRect in the right 3/4 of the screen", ^{
    SplitWindowPositionCalculationResult *result = [windowPositionCalculator calculateWindowRect:CGRectMake(720.0f, 4.0f, 720.0f, 873.0f)
                                                                          visibleFrameOfSourceScreen:visibleFrameSourceScreen
                                                                     visibleFrameOfDestinationScreen:visibleFrameDestinationScreen
                                                                                              action:kSplitWindowActionRightHalf];
    expect(result.windowRect).to.equal(CGRectMake(360.0f, 4.0f, 1080.0f, 873.0f));
  });

  it(@"should calculate a window's CGRect in the right 1/4 of the screen", ^{
    SplitWindowPositionCalculationResult *result = [windowPositionCalculator calculateWindowRect:CGRectMake(360.0f, 4.0f, 1080.0f, 873.0f)
                                                                          visibleFrameOfSourceScreen:visibleFrameSourceScreen
                                                                     visibleFrameOfDestinationScreen:visibleFrameDestinationScreen
                                                                                              action:kSplitWindowActionRightHalf];
    expect(result.windowRect).to.equal(CGRectMake(1080.0f, 4.0f, 360.0f, 873.0f));
  });
});
SpecEnd
