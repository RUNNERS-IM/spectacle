#import "SplitHistoryItem.h"

@implementation SplitHistoryItem

- (instancetype)initWithAccessibilityElement:(SplitAccessibilityElement *)accessibilityElement windowRect:(CGRect)windowRect
{
  if (self = [super init]) {
    _accessibilityElement = accessibilityElement;
    _windowRect = windowRect;
  }
  return self;
}

+ (SplitHistoryItem *)historyItemFromAccessibilityElement:(SplitAccessibilityElement *)accessibilityElement
                                                   windowRect:(CGRect)windowRect
{
  return [[SplitHistoryItem alloc] initWithAccessibilityElement:accessibilityElement windowRect:windowRect];
}

@end
