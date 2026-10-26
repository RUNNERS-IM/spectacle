#import <Expecta/Expecta.h>
#import <Specta/Specta.h>

#import "SplitWindowPositionCalculationResult.h"
#import "SplitWindowPositionCalculator.h"

SpecBegin(SplitPreviousDisplayWindowCalculation)
describe(@"SplitPreviousDisplayWindowCalculation", ^{
  CGRect visibleFrameSourceScreen = CGRectMake(0.0f, 4.0f, 1440.0f, 873.0f);
  CGRect visibleFrameDestinationScreen = CGRectMake(1440.0f, 4.0f, 1440.0f, 873.0f);
  SplitWindowPositionCalculator *windowPositionCalculator = [[SplitWindowPositionCalculator alloc] initWithErrorHandler:^(NSString *message) {
    EXP_failure(message);
  }];

  it(@"should calculate a centered window's CGRect in the previous display", ^{
    SplitWindowPositionCalculationResult *result = [windowPositionCalculator calculateWindowRect:CGRectMake(165.0f, 245.0f, 564.0f, 384.0f)
                                                                          visibleFrameOfSourceScreen:visibleFrameSourceScreen
                                                                     visibleFrameOfDestinationScreen:visibleFrameDestinationScreen
                                                                                              action:kSplitWindowActionPreviousDisplay];
    expect(result.windowRect).to.equal(CGRectMake(1878.0f, 249.0f, 564.0f, 384.0f));
  });
});
SpecEnd
