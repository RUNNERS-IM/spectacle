#import <Foundation/Foundation.h>

@class SplitShortcut;

NSString *SplitTranslateKeyCode(NSInteger keyCode);
NSString *SplitTranslateModifiers(NSUInteger modifiers);
NSString *SplitTranslateShortcut(SplitShortcut *shortcut);

NSUInteger SplitConvertCocoaModifiersToCarbon(NSUInteger modifiers);
NSUInteger SplitConvertCarbonModifiersToCocoa(NSUInteger modifiers);
NSUInteger SplitConvertModifiersToCarbonIfNecessary(NSUInteger modifiers);
NSUInteger SplitConvertModifiersToCocoaIfNecessary(NSUInteger modifiers);
