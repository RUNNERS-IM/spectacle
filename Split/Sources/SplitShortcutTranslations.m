#import "SplitShortcutTranslations.h"

#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>

#import "SplitShortcut.h"

typedef NS_ENUM(unichar, SplitUnicodeGlyph)
{
  SplitUnicodeGlyphCapsLock       = 0x21EA, // ⇪
  SplitUnicodeGlyphClear          = 0x2327, // ⌧
  SplitUnicodeGlyphCommand        = 0x2318, // ⌘
  SplitUnicodeGlyphControl        = 0x2303, // ⌃
  SplitUnicodeGlyphDelete         = 0x232B, // ⌫
  SplitUnicodeGlyphDownArrow      = 0x2193, // ↓
  SplitUnicodeGlyphEnd            = 0x2198, // ↘
  SplitUnicodeGlyphEnter          = 0x2324, // ⌤
  SplitUnicodeGlyphEscape         = 0x238B, // ⎋
  SplitUnicodeGlyphForwardDelete  = 0x2326, // ⌦
  SplitUnicodeGlyphHome           = 0x2196, // ↖
  SplitUnicodeGlyphLeftArrow      = 0x2190, // ←
  SplitUnicodeGlyphOption         = 0x2325, // ⌥
  SplitUnicodeGlyphPageDown       = 0x21DF, // ⇟
  SplitUnicodeGlyphPageUp         = 0x21DE, // ⇞
  SplitUnicodeGlyphReturn         = 0x21A9, // ↩
  SplitUnicodeGlyphRightArrow     = 0x2192, // →
  SplitUnicodeGlyphShift          = 0x21E7, // ⇧
  SplitUnicodeGlyphSpace          = 0x2423, // ␣
  SplitUnicodeGlyphTab            = 0x21E5, // ⇥
  SplitUnicodeGlyphUpArrow        = 0x2191, // ↑
};

static NSDictionary<NSNumber *, NSString *> *layoutIndependentKeyCodeTranslations(void);
static NSString *glyphForUnicodeChar(unichar unicodeChar);

NSString *SplitTranslateKeyCode(NSInteger keyCode)
{
  NSString *translatedLayoutIndependentKeyCode = layoutIndependentKeyCodeTranslations()[@(keyCode)];
  if (translatedLayoutIndependentKeyCode) {
    return translatedLayoutIndependentKeyCode;
  }
  // Shortcuts are shown with the ASCII-capable layout so that ⌘C reads "C" even while a
  // non-Latin input source such as Korean or Japanese is active.
  TISInputSourceRef inputSource = TISCopyCurrentASCIICapableKeyboardLayoutInputSource();
  if (!inputSource) {
    return @"?";
  }
  CFDataRef layoutData = (CFDataRef)TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData);
  CFRelease(inputSource);
  if (!layoutData) {
    inputSource = TISCopyCurrentKeyboardLayoutInputSource();
    if (!inputSource) {
      return @"?";
    }
    layoutData = (CFDataRef)TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData);
    CFRelease(inputSource);
    if (!layoutData) {
      return @"?";
    }
  }
  const UCKeyboardLayout *keyboardLayout = (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);
  UInt32 deadKeyState = 0;
  UniCharCount maximumStringLength = 4;
  UniCharCount actualStringLength = 0;
  UniChar unicodeString[maximumStringLength];
  OSStatus err = UCKeyTranslate(keyboardLayout,
                                keyCode,
                                kUCKeyActionDisplay,
                                0,
                                LMGetKbdType(),
                                kUCKeyTranslateNoDeadKeysBit,
                                &deadKeyState,
                                maximumStringLength,
                                &actualStringLength,
                                unicodeString);
  if (err != noErr) {
    return @"?";
  }
  return [[NSString stringWithCharacters:unicodeString length:actualStringLength] uppercaseString];
}

NSString *SplitTranslateModifiers(NSUInteger modifiers)
{
  NSString *modifierGlyphs = @"";
  modifiers = SplitConvertModifiersToCocoaIfNecessary(modifiers);
  if (modifiers & NSEventModifierFlagControl) {
    modifierGlyphs = [modifierGlyphs stringByAppendingFormat:@"%C", (UInt16)kControlUnicode];
  }
  if (modifiers & NSEventModifierFlagOption) {
    modifierGlyphs = [modifierGlyphs stringByAppendingFormat:@"%C", (UInt16)kOptionUnicode];
  }
  if (modifiers & NSEventModifierFlagShift) {
    modifierGlyphs = [modifierGlyphs stringByAppendingFormat:@"%C", (UInt16)kShiftUnicode];
  }
  if (modifiers & NSEventModifierFlagCommand) {
    modifierGlyphs = [modifierGlyphs stringByAppendingFormat:@"%C", (UInt16)kCommandUnicode];
  }
  return modifierGlyphs;
}

NSString *SplitTranslateShortcut(SplitShortcut *shortcut)
{
  return [NSString stringWithFormat:@"%@%@",
          SplitTranslateModifiers(shortcut.shortcutModifiers),
          SplitTranslateKeyCode(shortcut.shortcutKeyCode)];
}

NSUInteger SplitConvertCocoaModifiersToCarbon(NSUInteger modifiers)
{
  NSUInteger convertedModifiers = 0;
  if (modifiers & NSEventModifierFlagControl) {
    convertedModifiers |= controlKey;
  }
  if (modifiers & NSEventModifierFlagOption) {
    convertedModifiers |= optionKey;
  }
  if (modifiers & NSEventModifierFlagShift) {
    convertedModifiers |= shiftKey;
  }
  if (modifiers & NSEventModifierFlagCommand) {
    convertedModifiers |= cmdKey;
  }
  return convertedModifiers;
}

NSUInteger SplitConvertCarbonModifiersToCocoa(NSUInteger modifiers)
{
  NSUInteger convertedModifiers = 0;
  if (modifiers & controlKey) {
    convertedModifiers |= NSEventModifierFlagControl;
  }
  if (modifiers & optionKey) {
    convertedModifiers |= NSEventModifierFlagOption;
  }
  if (modifiers & shiftKey) {
    convertedModifiers |= NSEventModifierFlagShift;
  }
  if (modifiers & cmdKey) {
    convertedModifiers |= NSEventModifierFlagCommand;
  }
  return convertedModifiers;
}

NSUInteger SplitConvertModifiersToCarbonIfNecessary(NSUInteger modifiers)
{
  if ([SplitShortcut validCocoaModifiers:modifiers]) {
    modifiers = SplitConvertCocoaModifiersToCarbon(modifiers);
  }
  return modifiers;
}

NSUInteger SplitConvertModifiersToCocoaIfNecessary(NSUInteger modifiers)
{
  if (![SplitShortcut validCocoaModifiers:modifiers]) {
    modifiers = SplitConvertCarbonModifiersToCocoa(modifiers);
  }
  return modifiers;
}

static NSDictionary<NSNumber *, NSString *> *layoutIndependentKeyCodeTranslations(void)
{
  static dispatch_once_t onceToken;
  static NSDictionary<NSNumber *, NSString *> *translations;
  dispatch_once(&onceToken, ^{
    translations = @{
                     @(kVK_F1):                  @"F1",
                     @(kVK_F2):                  @"F2",
                     @(kVK_F3):                  @"F3",
                     @(kVK_F4):                  @"F4",
                     @(kVK_F5):                  @"F5",
                     @(kVK_F6):                  @"F6",
                     @(kVK_F7):                  @"F7",
                     @(kVK_F8):                  @"F8",
                     @(kVK_F9):                  @"F9",
                     @(kVK_F10):                 @"F10",
                     @(kVK_F11):                 @"F11",
                     @(kVK_F12):                 @"F12",
                     @(kVK_F13):                 @"F13",
                     @(kVK_F14):                 @"F14",
                     @(kVK_F15):                 @"F15",
                     @(kVK_F16):                 @"F16",
                     @(kVK_F17):                 @"F17",
                     @(kVK_F18):                 @"F18",
                     @(kVK_F19):                 @"F19",
                     @(kVK_F20):                 @"F20",

                     @(kVK_ANSI_KeypadDecimal):  @".",
                     @(kVK_ANSI_KeypadMultiply): @"*",
                     @(kVK_ANSI_KeypadPlus):     @"+",
                     @(kVK_ANSI_KeypadClear):    glyphForUnicodeChar(SplitUnicodeGlyphClear),
                     @(kVK_ANSI_KeypadDivide):   @"/",
                     @(kVK_ANSI_KeypadEnter):    glyphForUnicodeChar(SplitUnicodeGlyphEnter),
                     @(kVK_ANSI_KeypadMinus):    @"-",
                     @(kVK_ANSI_KeypadEquals):   @"=",
                     @(kVK_ANSI_Keypad0):        @"0",
                     @(kVK_ANSI_Keypad1):        @"1",
                     @(kVK_ANSI_Keypad2):        @"2",
                     @(kVK_ANSI_Keypad3):        @"3",
                     @(kVK_ANSI_Keypad4):        @"4",
                     @(kVK_ANSI_Keypad5):        @"5",
                     @(kVK_ANSI_Keypad6):        @"6",
                     @(kVK_ANSI_Keypad7):        @"7",
                     @(kVK_ANSI_Keypad8):        @"8",
                     @(kVK_ANSI_Keypad9):        @"9",

                     @(kVK_Return):              glyphForUnicodeChar(SplitUnicodeGlyphReturn),
                     @(kVK_Tab):                 glyphForUnicodeChar(SplitUnicodeGlyphTab),
                     @(kVK_Space):               glyphForUnicodeChar(SplitUnicodeGlyphSpace),
                     @(kVK_Delete):              glyphForUnicodeChar(SplitUnicodeGlyphDelete),
                     @(kVK_Escape):              glyphForUnicodeChar(SplitUnicodeGlyphEscape),
                     @(kVK_Command):             glyphForUnicodeChar(SplitUnicodeGlyphCommand),
                     @(kVK_Shift):               glyphForUnicodeChar(SplitUnicodeGlyphShift),
                     @(kVK_CapsLock):            glyphForUnicodeChar(SplitUnicodeGlyphCapsLock),
                     @(kVK_Option):              glyphForUnicodeChar(SplitUnicodeGlyphOption),
                     @(kVK_Control):             glyphForUnicodeChar(SplitUnicodeGlyphControl),
                     @(kVK_RightShift):          @"",
                     @(kVK_RightOption):         @"",
                     @(kVK_RightControl):        @"",
                     @(kVK_Function):            @"",
                     @(kVK_VolumeUp):            @"",
                     @(kVK_VolumeDown):          @"",
                     @(kVK_Mute):                @"",
                     @(kVK_Help):                @"",
                     @(kVK_Home):                glyphForUnicodeChar(SplitUnicodeGlyphHome),
                     @(kVK_PageUp):              glyphForUnicodeChar(SplitUnicodeGlyphPageUp),
                     @(kVK_ForwardDelete):       glyphForUnicodeChar(SplitUnicodeGlyphForwardDelete),
                     @(kVK_End):                 glyphForUnicodeChar(SplitUnicodeGlyphEnd),
                     @(kVK_PageDown):            glyphForUnicodeChar(SplitUnicodeGlyphPageDown),
                     @(kVK_LeftArrow):           glyphForUnicodeChar(SplitUnicodeGlyphLeftArrow),
                     @(kVK_RightArrow):          glyphForUnicodeChar(SplitUnicodeGlyphRightArrow),
                     @(kVK_DownArrow):           glyphForUnicodeChar(SplitUnicodeGlyphDownArrow),
                     @(kVK_UpArrow):             glyphForUnicodeChar(SplitUnicodeGlyphUpArrow),
                     };
  });
  return translations;
}

static NSString *glyphForUnicodeChar(unichar unicodeChar)
{
  return [NSString stringWithFormat: @"%C", unicodeChar];
}
