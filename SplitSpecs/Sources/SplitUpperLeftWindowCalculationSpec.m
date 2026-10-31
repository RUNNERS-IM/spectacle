#import <Expecta/Expecta.h>
#import <Specta/Specta.h>

#import "SplitWindowPositionCalculationResult.h"
#import "SplitWindowPositionCalculator.h"

SpecBegin(SplitUpperLeftWindowCalculation)
describe(@"SplitUpperLeftWindowCalculation", ^{
  CGRect visibleFrameSourceScreen = CGRectMake(0.0f, 4.0f, 1440.0f, 873.0f);
  CGRect visibleFrameDestinationScreen = CGRectMake(0.0f, 4.0f, 1440.0f, 873.0f);
  SplitWindowPositionCalculator *windowPositionCalculator = [[SplitWindowPositionCalculator alloc] initWithErrorHandler:^(NSString *message) {
    EXP_failure(message);
  }];

  it(@"should calculate a window's CGRect in the upper left corner of the screen", ^{
    SplitWindowPositionCalculationResult *result = [windowPositionCalculator calculateWindowRect:CGRectMake(165.0f, 245.0f, 564.0f, 384.0f)
                                                                          visibleFrameOfSourceScreen:visibleFrameSourceScreen
                                                                     visibleFrameOfDestinationScreen:visibleFrameDestinationScreen
                                                                                              action:kSplitWindowActionUpperLeft];
    expect(result.windowRect).to.equal(CGRectMake(0.0f, 441.0f, 720.0f, 436.0f));
  });
  
  it(@"should calculate a window's CGRect in the left 3/4 of the screen", ^{
    SplitWindowPositionCalculationResult *result = [windowPositionCalculator calculateWindowRect:CGRectMake(0.0f, 441.0f, 720.0f, 436.0f)
                                                                          visibleFrameOfSourceScreen:visibleFrameSourceScreen
                                                                     visibleFrameOfDestinationScreen:visibleFrameDestinationScreen
                                                                                              action:kSplitWindowActionUpperLeft];
    expect(result.windowRect).to.equal(CGRectMake(0.0f, 441.0f, 1080.0f, 436.0f));
  });
  
  it(@"should calculate a window's CGRect in the left 1/4 of the screen", ^{
    SplitWindowPositionCalculationResult *result = [windowPositionCalculator calculateWindowRect:CGRectMake(0.0f, 441.0f, 1080.0f, 436.0f)
                                                                          visibleFrameOfSourceScreen:visibleFrameSourceScreen
                                                                     visibleFrameOfDestinationScreen:visibleFrameDestinationScreen
                                                                                              action:kSplitWindowActionUpperLeft];
    expect(result.windowRect).to.equal(CGRectMake(0.0f, 441.0f, 360.0f, 436.0f));
  });

  
});
SpecEnd
