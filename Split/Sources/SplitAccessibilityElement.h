#import <Carbon/Carbon.h>

@interface SplitAccessibilityElement : NSObject

+ (SplitAccessibilityElement *)frontmostApplicationElement;
+ (SplitAccessibilityElement *)frontmostWindowElement;

/// Wraps an Accessibility element someone else looked up. The element is retained.
+ (SplitAccessibilityElement *)elementWithAXUIElement:(AXUIElementRef)element;

- (SplitAccessibilityElement *)elementWithAttribute:(CFStringRef)attribute;

- (NSString *)stringValueOfAttribute:(CFStringRef)attribute;

- (AXValueRef)valueOfAttribute:(CFStringRef)attribute type:(AXValueType)type;
- (void)setValue:(AXValueRef)value forAttribute:(CFStringRef)attribute;

- (CGRect)rectOfElement;
- (void)setRectOfElement:(CGRect)rect;

+ (CGRect)normalizeCoordinatesOfRect:(CGRect)rect frameOfScreen:(CGRect)frameOfScreen;

- (BOOL)isSheet;
- (BOOL)isSystemDialog;

@end
