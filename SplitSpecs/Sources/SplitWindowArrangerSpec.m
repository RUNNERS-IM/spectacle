#import <Expecta/Expecta.h>
#import <Specta/Specta.h>

#import "SplitShortcut.h"
#import "SplitWindowArranger.h"

static CGRect RectAt(NSArray<NSValue *> *rects, NSUInteger index)
{
  return NSRectToCGRect(rects[index].rectValue);
}

SpecBegin(SplitWindowArranger)
describe(@"SplitArrangeLayoutRects", ^{
  CGRect frame = CGRectMake(0.0, 25.0, 1440.0, 875.0);

  it(@"returns nothing for no windows", ^{
    expect(SplitArrangeLayoutRects(0, frame).count).to.equal(0);
  });

  it(@"fills the screen with one window", ^{
    expect(RectAt(SplitArrangeLayoutRects(1, frame), 0)).to.equal(frame);
  });

  it(@"puts two windows side by side", ^{
    NSArray<NSValue *> *rects = SplitArrangeLayoutRects(2, frame);
    expect(RectAt(rects, 0)).to.equal(CGRectMake(0.0, 25.0, 720.0, 875.0));
    expect(RectAt(rects, 1)).to.equal(CGRectMake(720.0, 25.0, 720.0, 875.0));
  });

  it(@"puts three windows as a left half and a right column of two", ^{
    NSArray<NSValue *> *rects = SplitArrangeLayoutRects(3, frame);
    expect(RectAt(rects, 0)).to.equal(CGRectMake(0.0, 25.0, 720.0, 875.0));
    expect(RectAt(rects, 1)).to.equal(CGRectMake(720.0, 25.0, 720.0, 437.0));
    expect(RectAt(rects, 2)).to.equal(CGRectMake(720.0, 462.0, 720.0, 438.0));
  });

  it(@"puts four windows in a 2 by 2 grid that covers the screen", ^{
    NSArray<NSValue *> *rects = SplitArrangeLayoutRects(4, frame);
    expect(rects.count).to.equal(4);
    expect(RectAt(rects, 0)).to.equal(CGRectMake(0.0, 25.0, 720.0, 437.0));
    expect(RectAt(rects, 3)).to.equal(CGRectMake(720.0, 462.0, 720.0, 438.0));
  });

  it(@"floats the front window in the middle at 60% when there are five", ^{
    NSArray<NSValue *> *rects = SplitArrangeLayoutRects(5, frame);
    expect(rects.count).to.equal(5);
    expect(RectAt(rects, 0)).to.equal(CGRectMake(288.0, 200.0, 864.0, 525.0));
    expect(RectAt(rects, 1)).to.equal(CGRectMake(0.0, 25.0, 720.0, 437.0));
  });

  it(@"uses a 3 by 2 grid for six windows", ^{
    NSArray<NSValue *> *rects = SplitArrangeLayoutRects(6, frame);
    expect(RectAt(rects, 0)).to.equal(CGRectMake(0.0, 25.0, 480.0, 437.0));
    expect(RectAt(rects, 5)).to.equal(CGRectMake(960.0, 462.0, 480.0, 438.0));
  });

  it(@"stacks windows after six in the middle, 30 points apart", ^{
    NSArray<NSValue *> *rects = SplitArrangeLayoutRects(8, frame);
    expect(rects.count).to.equal(8);
    expect(RectAt(rects, 6)).to.equal(CGRectMake(288.0, 200.0, 864.0, 525.0));
    expect(RectAt(rects, 7)).to.equal(CGRectMake(318.0, 230.0, 864.0, 525.0));
  });

  it(@"never places more than nine windows", ^{
    expect(SplitArrangeLayoutRects(14, frame).count).to.equal(9);
  });
});

describe(@"The auto-arrange shortcut", ^{
  it(@"maps to the arrange window action", ^{
    SplitShortcut *shortcut = [[SplitShortcut alloc] initWithShortcutName:@"ArrangeWindows" shortcutKeyBinding:@"alt+cmd+a"];
    expect(shortcut.windowAction).to.equal(kSplitWindowActionArrange);
  });
});

describe(@"App.strings", ^{
  it(@"has every English key in every language Split ships", ^{
    NSBundle *bundle = [NSBundle bundleForClass:NSClassFromString(@"SplitAppDelegate")];
    NSString *englishPath = [bundle pathForResource:@"App" ofType:@"strings" inDirectory:nil forLocalization:@"en"];
    NSDictionary *english = [NSDictionary dictionaryWithContentsOfFile:englishPath];
    expect(english.count).to.beGreaterThan(50);
    for (NSString *localization in bundle.localizations) {
      NSString *path = [bundle pathForResource:@"App" ofType:@"strings" inDirectory:nil forLocalization:localization];
      if (!path || [localization isEqualToString:@"Base"]) {
        continue;
      }
      NSDictionary *strings = [NSDictionary dictionaryWithContentsOfFile:path];
      for (NSString *key in english) {
        if (!strings[key]) {
          failure([NSString stringWithFormat:@"%@ is missing %@", localization, key]);
        }
      }
    }
  });
});
describe(@"SplitRectWithGap", ^{
  it(@"keeps the gap from screen edges and half of it from neighbours", ^{
    CGRect screen = CGRectMake(0, 0, 1440, 900);
    CGRect left = SplitRectWithGap(CGRectMake(0, 0, 720, 900), screen, 8);
    CGRect right = SplitRectWithGap(CGRectMake(720, 0, 720, 900), screen, 8);
    expect(NSStringFromRect(left)).to.equal(NSStringFromRect(NSMakeRect(8, 8, 708, 884)));
    expect(NSStringFromRect(right)).to.equal(NSStringFromRect(NSMakeRect(724, 8, 708, 884)));
    expect(CGRectGetMinX(right) - CGRectGetMaxX(left)).to.equal(8);
    expect(NSStringFromRect(SplitRectWithGap(CGRectMake(0, 0, 720, 900), screen, 0))).to.equal(NSStringFromRect(NSMakeRect(0, 0, 720, 900)));
  });
});
SpecEnd
