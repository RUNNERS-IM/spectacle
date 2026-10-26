#import "SplitShortcut.h"

#import <Cocoa/Cocoa.h>

#import "SplitShortcutKeyBindings.h"
#import "SplitShortcutTranslations.h"

@implementation SplitShortcut

- (instancetype)initWithShortcutName:(NSString *)shortcutName shortcutKeyBinding:(NSString *)shortcutKeyBinding
{
  return [self initWithShortcutName:shortcutName shortcutKeyBinding:shortcutKeyBinding shortcutAction:nil];
}

- (instancetype)initWithShortcutName:(NSString *)shortcutName
                  shortcutKeyBinding:(NSString *)shortcutKeyBinding
                      shortcutAction:(SplitShortcutAction)shortcutAction
{
  NSNumber *shortcutKeyCode = SplitConvertShortcutKeyBindingToKeyCode(shortcutKeyBinding);
  return [self initWithShortcutName:shortcutName
                    shortcutKeyCode:shortcutKeyCode ? [shortcutKeyCode integerValue] : -1
                  shortcutModifiers:[SplitConvertShortcutKeyBindingToModifiers(shortcutKeyBinding) unsignedIntegerValue]
                     shortcutAction:shortcutAction];
}

- (instancetype)initWithShortcutName:(NSString *)shortcutName
                     shortcutKeyCode:(NSInteger)shortcutKeyCode
                   shortcutModifiers:(NSUInteger)shortcutModifiers
{
  return [self initWithShortcutName:shortcutName
                    shortcutKeyCode:shortcutKeyCode
                  shortcutModifiers:shortcutModifiers
                     shortcutAction:nil];
}

- (instancetype)initWithShortcutName:(NSString *)shortcutName
                     shortcutKeyCode:(NSInteger)shortcutKeyCode
                   shortcutModifiers:(NSUInteger)shortcutModifiers
                      shortcutAction:(SplitShortcutAction)shortcutAction
{
  if (self = [super init]) {
    _shortcutName = shortcutName;
    _shortcutKeyCode = shortcutKeyCode;
    _shortcutModifiers = SplitConvertModifiersToCarbonIfNecessary(shortcutModifiers);
    _shortcutAction = shortcutAction;
  }
  return self;
}

- (instancetype)copyWithShortcutAction:(SplitShortcutAction)shortcutAction
{
  return [[SplitShortcut alloc] initWithShortcutName:_shortcutName
                                         shortcutKeyCode:_shortcutKeyCode
                                       shortcutModifiers:_shortcutModifiers
                                          shortcutAction:shortcutAction];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
  return [self initWithShortcutName:[coder decodeObjectForKey:@"name"]
                    shortcutKeyCode:[coder decodeIntegerForKey:@"keyCode"]
                  shortcutModifiers:[coder decodeIntegerForKey:@"modifiers"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
  [coder encodeObject:_shortcutName forKey:@"name"];
  [coder encodeInteger:_shortcutKeyCode forKey:@"keyCode"];
  [coder encodeInteger:_shortcutModifiers forKey:@"modifiers"];
}

- (NSString *)shortcutKeyBinding
{
  return SplitConvertShortcutToKeyBinding(self);
}

- (SplitWindowAction *)windowAction
{
  NSString *name = _shortcutName;
  SplitWindowAction *windowAction = kSplitWindowActionNone;

  if ([name isEqualToString:@"MoveToCenter"]) {
    windowAction = kSplitWindowActionCenter;
  } else if ([name isEqualToString:@"MoveToFullscreen"]) {
    windowAction = kSplitWindowActionFullscreen;
  } else if ([name isEqualToString:@"MoveToLeftHalf"]) {
    windowAction = kSplitWindowActionLeftHalf;
  } else if ([name isEqualToString:@"MoveToRightHalf"]) {
    windowAction = kSplitWindowActionRightHalf;
  } else if ([name isEqualToString:@"MoveToTopHalf"]) {
    windowAction = kSplitWindowActionTopHalf;
  } else if ([name isEqualToString:@"MoveToBottomHalf"]) {
    windowAction = kSplitWindowActionBottomHalf;
  } else if ([name isEqualToString:@"MoveToUpperLeft"]) {
    windowAction = kSplitWindowActionUpperLeft;
  } else if ([name isEqualToString:@"MoveToLowerLeft"]) {
    windowAction = kSplitWindowActionLowerLeft;
  } else if ([name isEqualToString:@"MoveToUpperRight"]) {
    windowAction = kSplitWindowActionUpperRight;
  } else if ([name isEqualToString:@"MoveToLowerRight"]) {
    windowAction = kSplitWindowActionLowerRight;
  } else if ([name isEqualToString:@"MoveToNextDisplay"]) {
    windowAction = kSplitWindowActionNextDisplay;
  } else if ([name isEqualToString:@"MoveToPreviousDisplay"]) {
    windowAction = kSplitWindowActionPreviousDisplay;
  } else if ([name isEqualToString:@"MoveToNextThird"]) {
    windowAction = kSplitWindowActionNextThird;
  } else if ([name isEqualToString:@"MoveToPreviousThird"]) {
    windowAction = kSplitWindowActionPreviousThird;
  } else if ([name isEqualToString:@"MakeLarger"]) {
    windowAction = kSplitWindowActionLarger;
  } else if ([name isEqualToString:@"MakeSmaller"]) {
    windowAction = kSplitWindowActionSmaller;
  } else if ([name isEqualToString:@"UndoLastMove"]) {
    windowAction = kSplitWindowActionUndo;
  } else if ([name isEqualToString:@"RedoLastMove"]) {
    windowAction = kSplitWindowActionRedo;
  }

  return windowAction;
}

- (void)triggerShortcutAction
{
  if (_shortcutAction) {
    _shortcutAction(self);
  }
}

- (BOOL)isClearedShortcut
{
  return _shortcutKeyCode == -1 || (_shortcutKeyCode == 0 && _shortcutModifiers == 0);
}

- (NSString *)displayString
{
  return SplitTranslateShortcut(self);
}

- (BOOL)isEqual:(id)object
{
  if (object == self) {
    return YES;
  }
  if (!object || ![object isKindOfClass:[self class]]) {
    return NO;
  }
  return [self isEqualToShortcut:object];
}

- (BOOL)isEqualToShortcut:(SplitShortcut *)shortcut
{
  if (shortcut == self) {
    return YES;
  }
  if (shortcut.shortcutKeyCode != _shortcutKeyCode) {
    return NO;
  }
  if (shortcut.shortcutModifiers != _shortcutModifiers) {
    return NO;
  }
  return YES;
}

- (BOOL)containsModifiers:(NSUInteger)modifiers
{
  return _shortcutModifiers == SplitConvertModifiersToCarbonIfNecessary(modifiers);
}

+ (BOOL)validCocoaModifiers:(NSUInteger)modifiers
{
  return ((modifiers & NSEventModifierFlagOption)
          || (modifiers & NSEventModifierFlagCommand)
          || (modifiers & NSEventModifierFlagControl)
          || (modifiers & NSEventModifierFlagShift));
}

@end
