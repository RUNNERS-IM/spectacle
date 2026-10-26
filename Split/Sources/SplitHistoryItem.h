#import <Foundation/Foundation.h>

#import "SplitMacros.h"

@class SplitAccessibilityElement;

@interface SplitHistoryItem : NSObject

@property (nonatomic, strong) SplitAccessibilityElement *accessibilityElement;
@property (nonatomic, assign) CGRect windowRect;
@property (nonatomic, strong) SplitHistoryItem *nextHistoryItem;
@property (nonatomic, weak) SplitHistoryItem *previousHistoryItem;

- (instancetype)initWithAccessibilityElement:(SplitAccessibilityElement *)accessibilityElement
                                  windowRect:(CGRect)windowRect NS_DESIGNATED_INITIALIZER;

+ (SplitHistoryItem *)historyItemFromAccessibilityElement:(SplitAccessibilityElement *)accessibilityElement
                                                   windowRect:(CGRect)windowRect;

SPECTACLE_INIT_AND_NEW_UNAVAILABLE

@end
