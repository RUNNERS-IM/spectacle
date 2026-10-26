#import <Foundation/Foundation.h>

#import "SplitMacros.h"
#import "SplitWindowAction.h"

@class SplitShortcut;

typedef void(^SplitShortcutAction)(SplitShortcut *);

@interface SplitShortcut : NSObject <NSCoding>

@property (nonatomic, readonly, copy) NSString *shortcutName;
@property (nonatomic, readonly, assign) NSInteger shortcutKeyCode;
@property (nonatomic, readonly, assign) NSUInteger shortcutModifiers;
@property (nonatomic, readonly, strong) SplitShortcutAction shortcutAction;
@property (nonatomic, readonly, copy) NSString *shortcutKeyBinding;
@property (nonatomic, readonly, strong) SplitWindowAction *windowAction;

- (instancetype)initWithShortcutName:(NSString *)shortcutName shortcutKeyBinding:(NSString *)shortcutKeyBinding;

- (instancetype)initWithShortcutName:(NSString *)shortcutName
                  shortcutKeyBinding:(NSString *)shortcutKeyBinding
                      shortcutAction:(SplitShortcutAction)shortcutAction;

- (instancetype)initWithShortcutName:(NSString *)shortcutName
                     shortcutKeyCode:(NSInteger)shortcutKeyCode
                   shortcutModifiers:(NSUInteger)shortcutModifiers;

- (instancetype)initWithShortcutName:(NSString *)shortcutName
                     shortcutKeyCode:(NSInteger)shortcutKeyCode
                   shortcutModifiers:(NSUInteger)shortcutModifiers
                      shortcutAction:(SplitShortcutAction)shortcutAction NS_DESIGNATED_INITIALIZER;

SPECTACLE_INIT_AND_NEW_UNAVAILABLE

- (instancetype)copyWithShortcutAction:(SplitShortcutAction)shortcutAction;

- (void)triggerShortcutAction;

- (BOOL)isClearedShortcut;

- (NSString *)displayString;

- (BOOL)isEqual:(id)object;
- (BOOL)isEqualToShortcut:(SplitShortcut *)shortcut;

- (BOOL)containsModifiers:(NSUInteger)modifiers;

+ (BOOL)validCocoaModifiers:(NSUInteger)modifiers;

@end
