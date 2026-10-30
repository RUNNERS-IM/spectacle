#import <Carbon/Carbon.h>

@interface SplitAccessibilityElement : NSObject

+ (SplitAccessibilityElement *)frontmostApplicationElement;
+ (SplitAccessibilityElement *)frontmostWindowElement;

/// The name of the app that last turned Split away although Split has the Accessibility
/// permission, or nil. An app that was already open when Split was reinstalled can keep refusing
/// until that app is quit and opened again, while every other app works.
+ (NSString *)applicationRefusingAccess;

/// Wraps an Accessibility element someone else looked up. The element is retained.
+ (SplitAccessibilityElement *)elementWithAXUIElement:(AXUIElementRef)element;

- (SplitAccessibilityElement *)elementWithAttribute:(CFStringRef)attribute;
- (SplitAccessibilityElement *)elementWithAttribute:(CFStringRef)attribute error:(AXError *)error;

- (NSString *)stringValueOfAttribute:(CFStringRef)attribute;

- (AXValueRef)valueOfAttribute:(CFStringRef)attribute type:(AXValueType)type;
- (void)setValue:(AXValueRef)value forAttribute:(CFStringRef)attribute;

- (CGRect)rectOfElement;
- (void)setRectOfElement:(CGRect)rect;

+ (CGRect)normalizeCoordinatesOfRect:(CGRect)rect frameOfScreen:(CGRect)frameOfScreen;

- (BOOL)isSheet;
- (BOOL)isSystemDialog;

@end
