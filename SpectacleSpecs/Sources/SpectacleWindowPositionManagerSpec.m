#import <Expecta/Expecta.h>
#import <OCHamcrest/OCHamcrest.h>
#import <OCMockito/OCMockito.h>
#import <Specta/Specta.h>

#import "SpectacleAccessibilityElement.h"
#import "SpectacleScreenDetectionResult.h"
#import "SpectacleScreenDetector.h"
#import "SpectacleWindowPositionCalculationResult.h"
#import "SpectacleWindowPositionCalculator.h"
#import "SpectacleWindowPositionManager.h"

// OCMockito crashes on arm64 when it retains CGRect arguments of a stubbed call,
// so the calculator is replaced with a hand-written fake that counts its calls.
@interface SpectacleFakeWindowPositionCalculator : SpectacleWindowPositionCalculator
@property (nonatomic, strong) SpectacleWindowPositionCalculationResult *stubbedResult;
@property (nonatomic, assign) NSUInteger calculateCallCount;
@end

@implementation SpectacleFakeWindowPositionCalculator

- (SpectacleWindowPositionCalculationResult *)calculateWindowRect:(CGRect)windowRect
                                       visibleFrameOfSourceScreen:(CGRect)visibleFrameOfSourceScreen
                                  visibleFrameOfDestinationScreen:(CGRect)visibleFrameOfDestinationScreen
                                                           action:(SpectacleWindowAction *)action
{
  self.calculateCallCount += 1;
  return self.stubbedResult;
}

@end

SpecBegin(SpectacleWindowPositionManager)
describe(@"SpectacleWindowPositionManager", ^{
  CGRect frameOfScreen = CGRectMake(0.0f, 0.0f, 1440.0f, 900.0f);
  CGRect visibleFrameOfScreen = CGRectMake(0.0f, 4.0f, 1440.0f, 873.0f);
  CGRect frontmostWindowRect = CGRectMake(165.0f, 245.0f, 564.0f, 384.0f);

  __block NSScreen *mockMainScreen;
  __block SpectacleScreenDetector *mockScreenDetector;
  __block SpectacleFakeWindowPositionCalculator *mockWindowPositionCalculator;
  __block NSWorkspace *mockSharedWorkspace;
  __block NSRunningApplication *mockFrontmostApplication;
  __block SpectacleWindowPositionManager *windowPositionManager;
  __block SpectacleWindowPositionCalculationResult *mockWindowPositionCalculationResult;

  beforeEach(^{
    mockMainScreen = mock([NSScreen class]);
    mockScreenDetector = mock([SpectacleScreenDetector class]);
    mockWindowPositionCalculator = [[SpectacleFakeWindowPositionCalculator alloc] initWithErrorHandler:^(NSString *message) {}];
    mockSharedWorkspace = mock([NSWorkspace class]);
    mockFrontmostApplication = mock([NSRunningApplication class]);
    mockWindowPositionCalculationResult = mock([SpectacleWindowPositionCalculationResult class]);

    [given([mockMainScreen frame]) willReturnStruct:&frameOfScreen objCType:@encode(NSRect)];
    [given([mockMainScreen visibleFrame]) willReturnStruct:&visibleFrameOfScreen objCType:@encode(NSRect)];

    mockWindowPositionCalculator.stubbedResult = mockWindowPositionCalculationResult;

    MKTOngoingStubbing *ongoingScreenDetectorStubbing =
      given([mockScreenDetector screenWithAction:kSpectacleWindowActionNone
                          frontmostWindowElement:anything()
                                         screens:anything()
                                      mainScreen:anything()]);

    ongoingScreenDetectorStubbing = [ongoingScreenDetectorStubbing withMatcher:anything()
                                                                   forArgument:0];

    ongoingScreenDetectorStubbing = [ongoingScreenDetectorStubbing withMatcher:anything()
                                                                   forArgument:1];

    [ongoingScreenDetectorStubbing willReturn:[SpectacleScreenDetectionResult resultWithSourceScreen:mockMainScreen
                                                                                   destinationScreen:mockMainScreen]];

    [given([mockFrontmostApplication bundleIdentifier]) willReturn:@"com.divisiblebyzero.SpectacleSpecs"];

    [given([mockSharedWorkspace frontmostApplication]) willReturn:mockFrontmostApplication];

    windowPositionManager = [[SpectacleWindowPositionManager alloc] initWithScreenDetector:mockScreenDetector
                                                                  windowPositionCalculator:mockWindowPositionCalculator
                                                                           sharedWorkspace:mockSharedWorkspace
                                                                           failureFeedback:^() {}
                                                                               windowMover:nil];
  });

  it(@"should do nothing if the frontmost window is a sheet", ^{
    SpectacleAccessibilityElement *mockAccessibilityElemenet = mock([SpectacleAccessibilityElement class]);

    [given([mockAccessibilityElemenet rectOfElement]) willReturnStruct:&frontmostWindowRect objCType:@encode(CGRect)];
    [given([mockAccessibilityElemenet isSheet]) willReturnBool:YES];

    [windowPositionManager moveFrontmostWindowElement:mockAccessibilityElemenet
                                               action:kSpectacleWindowActionNone
                                              screens:@[mockMainScreen]
                                           mainScreen:mockMainScreen];

    [verify(mockAccessibilityElemenet) rectOfElement];
    [verify(mockAccessibilityElemenet) isSheet];
    [verifyCount(mockAccessibilityElemenet, never()) isSystemDialog];

    expect(mockWindowPositionCalculator.calculateCallCount).to.equal(0);
  });

  it(@"should do nothing if the frontmost window is a system dialog", ^{
    SpectacleAccessibilityElement *mockAccessibilityElemenet = mock([SpectacleAccessibilityElement class]);

    [given([mockAccessibilityElemenet rectOfElement]) willReturnStruct:&frontmostWindowRect objCType:@encode(CGRect)];
    [given([mockAccessibilityElemenet isSheet]) willReturnBool:NO];
    [given([mockAccessibilityElemenet isSystemDialog]) willReturnBool:YES];

    [windowPositionManager moveFrontmostWindowElement:mockAccessibilityElemenet
                                               action:kSpectacleWindowActionNone
                                              screens:@[mockMainScreen]
                                           mainScreen:mockMainScreen];

    [verify(mockAccessibilityElemenet) rectOfElement];
    [verify(mockAccessibilityElemenet) isSheet];
    [verify(mockAccessibilityElemenet) isSystemDialog];

    expect(mockWindowPositionCalculator.calculateCallCount).to.equal(0);
  });

  it(@"should do nothing if the frontmost window rect is unavailable", ^{
    SpectacleAccessibilityElement *mockAccessibilityElemenet = mock([SpectacleAccessibilityElement class]);

    [given([mockAccessibilityElemenet rectOfElement]) willReturnStruct:&CGRectNull objCType:@encode(CGRect)];
    [given([mockAccessibilityElemenet isSheet]) willReturnBool:NO];
    [given([mockAccessibilityElemenet isSystemDialog]) willReturnBool:YES];

    [windowPositionManager moveFrontmostWindowElement:mockAccessibilityElemenet
                                               action:kSpectacleWindowActionNone
                                              screens:@[mockMainScreen]
                                           mainScreen:mockMainScreen];

    [verify(mockAccessibilityElemenet) rectOfElement];
    [verify(mockAccessibilityElemenet) isSheet];
    [verify(mockAccessibilityElemenet) isSystemDialog];

    expect(mockWindowPositionCalculator.calculateCallCount).to.equal(0);
  });

  it(@"should do nothing if screen detection fails", ^{
    SpectacleAccessibilityElement *mockAccessibilityElemenet = mock([SpectacleAccessibilityElement class]);

    [given([mockAccessibilityElemenet rectOfElement]) willReturnStruct:&frontmostWindowRect
                                                              objCType:@encode(CGRect)];
    [given([mockAccessibilityElemenet isSheet]) willReturnBool:NO];
    [given([mockAccessibilityElemenet isSystemDialog]) willReturnBool:YES];

    [given([mockScreenDetector screenWithAction:kSpectacleWindowActionCenter
                         frontmostWindowElement:anything()
                                        screens:anything()
                                     mainScreen:anything()]) willReturn:nil];

    [windowPositionManager moveFrontmostWindowElement:mockAccessibilityElemenet
                                               action:kSpectacleWindowActionNone
                                              screens:@[mockMainScreen]
                                           mainScreen:mockMainScreen];

    [verify(mockAccessibilityElemenet) rectOfElement];
    [verify(mockAccessibilityElemenet) isSheet];
    [verify(mockAccessibilityElemenet) isSystemDialog];

    expect(mockWindowPositionCalculator.calculateCallCount).to.equal(0);
  });

  it(@"should do nothing if the window position calculation returns the same results", ^{
    SpectacleAccessibilityElement *mockAccessibilityElemenet = mock([SpectacleAccessibilityElement class]);

    [given([mockAccessibilityElemenet rectOfElement]) willReturnStruct:&frontmostWindowRect objCType:@encode(CGRect)];
    [given([mockAccessibilityElemenet isSheet]) willReturnBool:NO];
    [given([mockAccessibilityElemenet isSystemDialog]) willReturnBool:NO];

    [given([mockWindowPositionCalculationResult action]) willReturn:kSpectacleWindowActionCenter];

    CGRect flippedFrontmostWindowRect = frontmostWindowRect;

    [given([mockWindowPositionCalculationResult windowRect]) willReturnStruct:&flippedFrontmostWindowRect
                                                                     objCType:@encode(CGRect)];

    [windowPositionManager moveFrontmostWindowElement:mockAccessibilityElemenet
                                               action:kSpectacleWindowActionCenter
                                              screens:@[mockMainScreen]
                                           mainScreen:mockMainScreen];

    [(SpectacleWindowPositionCalculationResult *)verify(mockWindowPositionCalculationResult) action];
    [verify(mockWindowPositionCalculationResult) windowRect];

    [[verifyCount(mockAccessibilityElemenet, never()) withMatcher:anything()] setRectOfElement:CGRectNull];
  });
});
SpecEnd
