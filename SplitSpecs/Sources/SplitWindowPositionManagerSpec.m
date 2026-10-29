#import <Expecta/Expecta.h>
#import <OCHamcrest/OCHamcrest.h>
#import <OCMockito/OCMockito.h>
#import <Specta/Specta.h>

#import "SplitAccessibilityElement.h"
#import "SplitScreenDetectionResult.h"
#import "SplitScreenDetector.h"
#import "SplitWindowPositionCalculationResult.h"
#import "SplitWindowPositionCalculator.h"
#import "SplitWindowMover.h"
#import "SplitWindowPositionManager.h"

// OCMockito crashes on arm64 when it retains CGRect arguments of a stubbed call,
// so the calculator is replaced with a hand-written fake that counts its calls.
@interface SplitFakeWindowPositionCalculator : SplitWindowPositionCalculator
@property (nonatomic, strong) SplitWindowPositionCalculationResult *stubbedResult;
@property (nonatomic, assign) NSUInteger calculateCallCount;
@end

@implementation SplitFakeWindowPositionCalculator

- (SplitWindowPositionCalculationResult *)calculateWindowRect:(CGRect)windowRect
                                       visibleFrameOfSourceScreen:(CGRect)visibleFrameOfSourceScreen
                                  visibleFrameOfDestinationScreen:(CGRect)visibleFrameOfDestinationScreen
                                                           action:(SplitWindowAction *)action
{
  self.calculateCallCount += 1;
  return self.stubbedResult;
}

@end

/// Remembers every rect it was asked to move a window to.
@interface SplitRecordingWindowMover : NSObject <SplitWindowMover>
@property (nonatomic, strong) NSMutableArray<NSValue *> *movedRects;
@end

@implementation SplitRecordingWindowMover

- (instancetype)initWithInnerWindowMover:(id<SplitWindowMover>)innerWindowMover
{
  if (self = [super init]) {
    _movedRects = [NSMutableArray new];
  }
  return self;
}

+ (instancetype)newWithInnerWindowMover:(id<SplitWindowMover>)innerWindowMover
{
  return [[self alloc] initWithInnerWindowMover:innerWindowMover];
}

- (void)moveWindowRect:(CGRect)windowRect
         frameOfScreen:(CGRect)frameOfScreen
  visibleFrameOfScreen:(CGRect)visibleFrameOfScreen
frontmostWindowElement:(SplitAccessibilityElement *)frontmostWindowElement
                action:(SplitWindowAction *)action
{
  [self.movedRects addObject:[NSValue valueWithRect:NSRectFromCGRect(windowRect)]];
}

@end

SpecBegin(SplitWindowPositionManager)
describe(@"SplitWindowPositionManager", ^{
  CGRect frameOfScreen = CGRectMake(0.0f, 0.0f, 1440.0f, 900.0f);
  CGRect visibleFrameOfScreen = CGRectMake(0.0f, 4.0f, 1440.0f, 873.0f);
  CGRect frontmostWindowRect = CGRectMake(165.0f, 245.0f, 564.0f, 384.0f);

  __block NSScreen *mockMainScreen;
  __block SplitScreenDetector *mockScreenDetector;
  __block SplitFakeWindowPositionCalculator *mockWindowPositionCalculator;
  __block NSWorkspace *mockSharedWorkspace;
  __block NSRunningApplication *mockFrontmostApplication;
  __block SplitWindowPositionManager *windowPositionManager;
  __block SplitWindowPositionCalculationResult *mockWindowPositionCalculationResult;

  beforeEach(^{
    mockMainScreen = mock([NSScreen class]);
    mockScreenDetector = mock([SplitScreenDetector class]);
    mockWindowPositionCalculator = [[SplitFakeWindowPositionCalculator alloc] initWithErrorHandler:^(NSString *message) {}];
    mockSharedWorkspace = mock([NSWorkspace class]);
    mockFrontmostApplication = mock([NSRunningApplication class]);
    mockWindowPositionCalculationResult = mock([SplitWindowPositionCalculationResult class]);

    [given([mockMainScreen frame]) willReturnStruct:&frameOfScreen objCType:@encode(NSRect)];
    [given([mockMainScreen visibleFrame]) willReturnStruct:&visibleFrameOfScreen objCType:@encode(NSRect)];

    mockWindowPositionCalculator.stubbedResult = mockWindowPositionCalculationResult;

    MKTOngoingStubbing *ongoingScreenDetectorStubbing =
      given([mockScreenDetector screenWithAction:kSplitWindowActionNone
                          frontmostWindowElement:anything()
                                         screens:anything()
                                      mainScreen:anything()]);

    ongoingScreenDetectorStubbing = [ongoingScreenDetectorStubbing withMatcher:anything()
                                                                   forArgument:0];

    ongoingScreenDetectorStubbing = [ongoingScreenDetectorStubbing withMatcher:anything()
                                                                   forArgument:1];

    [ongoingScreenDetectorStubbing willReturn:[SplitScreenDetectionResult resultWithSourceScreen:mockMainScreen
                                                                                   destinationScreen:mockMainScreen]];

    [given([mockFrontmostApplication bundleIdentifier]) willReturn:@"com.divisiblebyzero.SpectacleSpecs"];

    [given([mockSharedWorkspace frontmostApplication]) willReturn:mockFrontmostApplication];

    windowPositionManager = [[SplitWindowPositionManager alloc] initWithScreenDetector:mockScreenDetector
                                                                  windowPositionCalculator:mockWindowPositionCalculator
                                                                           sharedWorkspace:mockSharedWorkspace
                                                                           failureFeedback:^() {}
                                                                               windowMover:nil];
  });

  it(@"should do nothing if the frontmost window is a sheet", ^{
    SplitAccessibilityElement *mockAccessibilityElemenet = mock([SplitAccessibilityElement class]);

    [given([mockAccessibilityElemenet rectOfElement]) willReturnStruct:&frontmostWindowRect objCType:@encode(CGRect)];
    [given([mockAccessibilityElemenet isSheet]) willReturnBool:YES];

    [windowPositionManager moveFrontmostWindowElement:mockAccessibilityElemenet
                                               action:kSplitWindowActionNone
                                              screens:@[mockMainScreen]
                                           mainScreen:mockMainScreen];

    [verify(mockAccessibilityElemenet) rectOfElement];
    [verify(mockAccessibilityElemenet) isSheet];
    [verifyCount(mockAccessibilityElemenet, never()) isSystemDialog];

    expect(mockWindowPositionCalculator.calculateCallCount).to.equal(0);
  });

  it(@"should do nothing if the frontmost window is a system dialog", ^{
    SplitAccessibilityElement *mockAccessibilityElemenet = mock([SplitAccessibilityElement class]);

    [given([mockAccessibilityElemenet rectOfElement]) willReturnStruct:&frontmostWindowRect objCType:@encode(CGRect)];
    [given([mockAccessibilityElemenet isSheet]) willReturnBool:NO];
    [given([mockAccessibilityElemenet isSystemDialog]) willReturnBool:YES];

    [windowPositionManager moveFrontmostWindowElement:mockAccessibilityElemenet
                                               action:kSplitWindowActionNone
                                              screens:@[mockMainScreen]
                                           mainScreen:mockMainScreen];

    [verify(mockAccessibilityElemenet) rectOfElement];
    [verify(mockAccessibilityElemenet) isSheet];
    [verify(mockAccessibilityElemenet) isSystemDialog];

    expect(mockWindowPositionCalculator.calculateCallCount).to.equal(0);
  });

  it(@"should do nothing if the frontmost window rect is unavailable", ^{
    SplitAccessibilityElement *mockAccessibilityElemenet = mock([SplitAccessibilityElement class]);

    [given([mockAccessibilityElemenet rectOfElement]) willReturnStruct:&CGRectNull objCType:@encode(CGRect)];
    [given([mockAccessibilityElemenet isSheet]) willReturnBool:NO];
    [given([mockAccessibilityElemenet isSystemDialog]) willReturnBool:YES];

    [windowPositionManager moveFrontmostWindowElement:mockAccessibilityElemenet
                                               action:kSplitWindowActionNone
                                              screens:@[mockMainScreen]
                                           mainScreen:mockMainScreen];

    [verify(mockAccessibilityElemenet) rectOfElement];
    [verify(mockAccessibilityElemenet) isSheet];
    [verify(mockAccessibilityElemenet) isSystemDialog];

    expect(mockWindowPositionCalculator.calculateCallCount).to.equal(0);
  });

  it(@"should do nothing if screen detection fails", ^{
    SplitAccessibilityElement *mockAccessibilityElemenet = mock([SplitAccessibilityElement class]);

    [given([mockAccessibilityElemenet rectOfElement]) willReturnStruct:&frontmostWindowRect
                                                              objCType:@encode(CGRect)];
    [given([mockAccessibilityElemenet isSheet]) willReturnBool:NO];
    [given([mockAccessibilityElemenet isSystemDialog]) willReturnBool:YES];

    [given([mockScreenDetector screenWithAction:kSplitWindowActionCenter
                         frontmostWindowElement:anything()
                                        screens:anything()
                                     mainScreen:anything()]) willReturn:nil];

    [windowPositionManager moveFrontmostWindowElement:mockAccessibilityElemenet
                                               action:kSplitWindowActionNone
                                              screens:@[mockMainScreen]
                                           mainScreen:mockMainScreen];

    [verify(mockAccessibilityElemenet) rectOfElement];
    [verify(mockAccessibilityElemenet) isSheet];
    [verify(mockAccessibilityElemenet) isSystemDialog];

    expect(mockWindowPositionCalculator.calculateCallCount).to.equal(0);
  });

  it(@"should do nothing if the window position calculation returns the same results", ^{
    SplitAccessibilityElement *mockAccessibilityElemenet = mock([SplitAccessibilityElement class]);

    [given([mockAccessibilityElemenet rectOfElement]) willReturnStruct:&frontmostWindowRect objCType:@encode(CGRect)];
    [given([mockAccessibilityElemenet isSheet]) willReturnBool:NO];
    [given([mockAccessibilityElemenet isSystemDialog]) willReturnBool:NO];

    [given([mockWindowPositionCalculationResult action]) willReturn:kSplitWindowActionCenter];

    CGRect flippedFrontmostWindowRect = frontmostWindowRect;

    [given([mockWindowPositionCalculationResult windowRect]) willReturnStruct:&flippedFrontmostWindowRect
                                                                     objCType:@encode(CGRect)];

    [windowPositionManager moveFrontmostWindowElement:mockAccessibilityElemenet
                                               action:kSplitWindowActionCenter
                                              screens:@[mockMainScreen]
                                           mainScreen:mockMainScreen];

    [(SplitWindowPositionCalculationResult *)verify(mockWindowPositionCalculationResult) action];
    [verify(mockWindowPositionCalculationResult) windowRect];

    [[verifyCount(mockAccessibilityElemenet, never()) withMatcher:anything()] setRectOfElement:CGRectNull];
  });
  it(@"should put a full screen window back when full screen is pressed again", ^{
    SplitRecordingWindowMover *mover = [SplitRecordingWindowMover newWithInnerWindowMover:nil];
    SplitWindowPositionManager *manager = [[SplitWindowPositionManager alloc] initWithScreenDetector:mockScreenDetector
                                                                       windowPositionCalculator:mockWindowPositionCalculator
                                                                                sharedWorkspace:mockSharedWorkspace
                                                                                failureFeedback:^() {}
                                                                                    windowMover:mover];
    SplitAccessibilityElement *mockAccessibilityElemenet = mock([SplitAccessibilityElement class]);
    [given([mockAccessibilityElemenet rectOfElement]) willReturnStruct:&frontmostWindowRect objCType:@encode(CGRect)];
    [given([mockAccessibilityElemenet isSheet]) willReturnBool:NO];
    [given([mockAccessibilityElemenet isSystemDialog]) willReturnBool:NO];
    [given([mockWindowPositionCalculationResult action]) willReturn:kSplitWindowActionFullscreen];
    CGRect calculatedFullscreenRect = visibleFrameOfScreen;
    [given([mockWindowPositionCalculationResult windowRect]) willReturnStruct:&calculatedFullscreenRect objCType:@encode(CGRect)];

    [manager moveFrontmostWindowElement:mockAccessibilityElemenet
                                 action:kSplitWindowActionFullscreen
                                screens:@[mockMainScreen]
                             mainScreen:mockMainScreen];
    expect(mover.movedRects.count).to.equal(1);
    CGRect fullscreenRect = NSRectToCGRect(mover.movedRects[0].rectValue);

    // The window now sits where Split put it.
    [given([mockAccessibilityElemenet rectOfElement]) willReturnStruct:&fullscreenRect objCType:@encode(CGRect)];
    [manager moveFrontmostWindowElement:mockAccessibilityElemenet
                                 action:kSplitWindowActionFullscreen
                                screens:@[mockMainScreen]
                             mainScreen:mockMainScreen];
    expect(mover.movedRects.count).to.equal(2);
    expect(CGRectEqualToRect(NSRectToCGRect(mover.movedRects[1].rectValue), frontmostWindowRect)).to.beTruthy();

    // A third press makes it full screen again.
    [given([mockAccessibilityElemenet rectOfElement]) willReturnStruct:&frontmostWindowRect objCType:@encode(CGRect)];
    [manager moveFrontmostWindowElement:mockAccessibilityElemenet
                                 action:kSplitWindowActionFullscreen
                                screens:@[mockMainScreen]
                             mainScreen:mockMainScreen];
    expect(mover.movedRects.count).to.equal(3);
    expect(CGRectEqualToRect(NSRectToCGRect(mover.movedRects[2].rectValue), fullscreenRect)).to.beTruthy();
  });
});
SpecEnd
