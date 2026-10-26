#import "SplitShortcutValidation.h"

#import <Carbon/Carbon.h>

#import "SplitShortcut.h"
#import "SplitShortcutTranslations.h"
#import "SplitShortcutValidator.h"

@implementation SplitShortcutValidation
{
  SplitShortcutManager *_shortcutManager;
  NSArray<id<SplitShortcutValidator>> *_validators;
}

- (instancetype)initWithShortcutManager:(SplitShortcutManager *)shortcutManager
                             validators:(NSArray<id<SplitShortcutValidator>> *)validators
{
  if (self = [super init]) {
    _shortcutManager = shortcutManager;
    _validators = validators;
  }
  return self;
}

- (BOOL)isShortcutValid:(SplitShortcut *)shortcut error:(NSError **)error
{
  CFArrayRef shortcuts = NULL;
  if (CopySymbolicHotKeys(&shortcuts)) {
    return YES;
  }
  for (CFIndex i = 0; i < CFArrayGetCount(shortcuts); i++) {
    CFDictionaryRef shortcutDictionary = (CFDictionaryRef)CFArrayGetValueAtIndex(shortcuts, i);
    if (!shortcutDictionary || (CFGetTypeID(shortcutDictionary) != CFDictionaryGetTypeID())) {
      continue;
    }
    if (kCFBooleanTrue != (CFBooleanRef)CFDictionaryGetValue(shortcutDictionary, kHISymbolicHotKeyEnabled)) {
      continue;
    }
    NSInteger keyCode = keyCodeFromDictionary(shortcutDictionary);
    NSUInteger modifiers = modifiersFromDictionary(shortcutDictionary);
    if (([shortcut shortcutKeyCode] == keyCode) && [shortcut containsModifiers:modifiers]) {
      if (error) {
        NSString *description = NSLocalizedString(@"AlertMessageTextShortcutValidationError", @"The message text of the alert displayed when a shortcut is invalid");
        NSString *recoverySuggestion = NSLocalizedString(@"AlertInformativeTextSystemWideShortcutAlreadyUsed", @"The informative text of the alert displayed when a system-wide shortcut is already in use");
        *error = [SplitShortcutValidation errorWithShortcut:shortcut
                                                    description:description
                                             recoverySuggestion:recoverySuggestion];
      }
      return NO;
    }
  }
  for (id<SplitShortcutValidator> validator in _validators) {
    if ([validator conformsToProtocol:@protocol(SplitShortcutValidator)]
        && ![validator isShortcutValid:shortcut shortcutManager:_shortcutManager]) {
      if (error) {
        NSString *description = NSLocalizedString(@"AlertMessageTextShortcutValidationError", @"The message text of the alert displayed when a shortcut is invalid");
        NSString *recoverySuggestion = NSLocalizedString(@"AlertInformativeTextShortcutAlreadyInUse", @"The informative text of the alert displayed when a shortcut is already in use");
        *error = [SplitShortcutValidation errorWithShortcut:shortcut
                                                    description:description
                                             recoverySuggestion:recoverySuggestion];
      }
      return NO;
    }
  }
  return YES;
}

+ (NSError *)errorWithShortcut:(SplitShortcut *)shortcut
                   description:(NSString *)description
            recoverySuggestion:(NSString *)recoverySuggestion
{
  NSString *shortcutString = SplitTranslateShortcut(shortcut);
  return [NSError errorWithDomain:NSCocoaErrorDomain
                             code:0
                         userInfo:@{
                                    NSLocalizedDescriptionKey: [NSString stringWithFormat:description, shortcutString],
                                    NSLocalizedRecoverySuggestionErrorKey: [NSString stringWithFormat:recoverySuggestion, shortcutString],
                                    NSLocalizedRecoveryOptionsErrorKey: @[NSLocalizedString(@"ButtonLabelAffirmative", @"The button label used in the affirmative")]
                                    }];
}

static NSInteger keyCodeFromDictionary(CFDictionaryRef dictionary)
{
  CFNumberRef keyCodeFromDictionary = (CFNumberRef)CFDictionaryGetValue(dictionary, kHISymbolicHotKeyCode);
  NSInteger keyCode = 0;
  CFNumberGetValue(keyCodeFromDictionary, kCFNumberLongType, &keyCode);
  return keyCode;
}

static NSUInteger modifiersFromDictionary(CFDictionaryRef dictionary)
{
  CFNumberRef modifiersFromDictionary = (CFNumberRef)CFDictionaryGetValue(dictionary, kHISymbolicHotKeyModifiers);
  NSUInteger modifiers = 0;
  CFNumberGetValue(modifiersFromDictionary, kCFNumberLongType, &modifiers);
  return modifiers;
}

@end
