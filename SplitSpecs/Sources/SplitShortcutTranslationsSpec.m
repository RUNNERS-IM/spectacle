#import <Carbon/Carbon.h>
#import <Expecta/Expecta.h>
#import <Specta/Specta.h>

#import "SplitShortcut.h"
#import "SplitShortcutTranslations.h"

static SplitShortcut *shortcutForKeyBinding(NSString *keyBinding);

SpecBegin(SplitShortcutTranslations)
describe(@"SplitShortcutTranslations", ^{
  it(@"should translate alphanumeric key codes", ^{
    expect(SplitTranslateKeyCode(kVK_ANSI_A)).to.equal(@"A");
    expect(SplitTranslateKeyCode(kVK_ANSI_B)).to.equal(@"B");
    expect(SplitTranslateKeyCode(kVK_ANSI_C)).to.equal(@"C");
    expect(SplitTranslateKeyCode(kVK_ANSI_D)).to.equal(@"D");
    expect(SplitTranslateKeyCode(kVK_ANSI_E)).to.equal(@"E");
    expect(SplitTranslateKeyCode(kVK_ANSI_F)).to.equal(@"F");
    expect(SplitTranslateKeyCode(kVK_ANSI_G)).to.equal(@"G");
    expect(SplitTranslateKeyCode(kVK_ANSI_H)).to.equal(@"H");
    expect(SplitTranslateKeyCode(kVK_ANSI_I)).to.equal(@"I");
    expect(SplitTranslateKeyCode(kVK_ANSI_J)).to.equal(@"J");
    expect(SplitTranslateKeyCode(kVK_ANSI_K)).to.equal(@"K");
    expect(SplitTranslateKeyCode(kVK_ANSI_L)).to.equal(@"L");
    expect(SplitTranslateKeyCode(kVK_ANSI_M)).to.equal(@"M");
    expect(SplitTranslateKeyCode(kVK_ANSI_N)).to.equal(@"N");
    expect(SplitTranslateKeyCode(kVK_ANSI_O)).to.equal(@"O");
    expect(SplitTranslateKeyCode(kVK_ANSI_P)).to.equal(@"P");
    expect(SplitTranslateKeyCode(kVK_ANSI_Q)).to.equal(@"Q");
    expect(SplitTranslateKeyCode(kVK_ANSI_R)).to.equal(@"R");
    expect(SplitTranslateKeyCode(kVK_ANSI_S)).to.equal(@"S");
    expect(SplitTranslateKeyCode(kVK_ANSI_T)).to.equal(@"T");
    expect(SplitTranslateKeyCode(kVK_ANSI_U)).to.equal(@"U");
    expect(SplitTranslateKeyCode(kVK_ANSI_V)).to.equal(@"V");
    expect(SplitTranslateKeyCode(kVK_ANSI_W)).to.equal(@"W");
    expect(SplitTranslateKeyCode(kVK_ANSI_X)).to.equal(@"X");
    expect(SplitTranslateKeyCode(kVK_ANSI_Y)).to.equal(@"Y");
    expect(SplitTranslateKeyCode(kVK_ANSI_Z)).to.equal(@"Z");

    expect(SplitTranslateKeyCode(kVK_ANSI_0)).to.equal(@"0");
    expect(SplitTranslateKeyCode(kVK_ANSI_1)).to.equal(@"1");
    expect(SplitTranslateKeyCode(kVK_ANSI_2)).to.equal(@"2");
    expect(SplitTranslateKeyCode(kVK_ANSI_3)).to.equal(@"3");
    expect(SplitTranslateKeyCode(kVK_ANSI_4)).to.equal(@"4");
    expect(SplitTranslateKeyCode(kVK_ANSI_5)).to.equal(@"5");
    expect(SplitTranslateKeyCode(kVK_ANSI_6)).to.equal(@"6");
    expect(SplitTranslateKeyCode(kVK_ANSI_7)).to.equal(@"7");
    expect(SplitTranslateKeyCode(kVK_ANSI_8)).to.equal(@"8");
    expect(SplitTranslateKeyCode(kVK_ANSI_9)).to.equal(@"9");
  });

  it(@"should translate keyboard layout independent key codes", ^{
    expect(SplitTranslateKeyCode(kVK_F1)).to.equal(@"F1");
    expect(SplitTranslateKeyCode(kVK_F2)).to.equal(@"F2");
    expect(SplitTranslateKeyCode(kVK_F3)).to.equal(@"F3");
    expect(SplitTranslateKeyCode(kVK_F4)).to.equal(@"F4");
    expect(SplitTranslateKeyCode(kVK_F5)).to.equal(@"F5");
    expect(SplitTranslateKeyCode(kVK_F6)).to.equal(@"F6");
    expect(SplitTranslateKeyCode(kVK_F7)).to.equal(@"F7");
    expect(SplitTranslateKeyCode(kVK_F8)).to.equal(@"F8");
    expect(SplitTranslateKeyCode(kVK_F9)).to.equal(@"F9");
    expect(SplitTranslateKeyCode(kVK_F10)).to.equal(@"F10");
    expect(SplitTranslateKeyCode(kVK_F11)).to.equal(@"F11");
    expect(SplitTranslateKeyCode(kVK_F12)).to.equal(@"F12");
    expect(SplitTranslateKeyCode(kVK_F13)).to.equal(@"F13");
    expect(SplitTranslateKeyCode(kVK_F14)).to.equal(@"F14");
    expect(SplitTranslateKeyCode(kVK_F15)).to.equal(@"F15");
    expect(SplitTranslateKeyCode(kVK_F16)).to.equal(@"F16");
    expect(SplitTranslateKeyCode(kVK_F17)).to.equal(@"F17");
    expect(SplitTranslateKeyCode(kVK_F18)).to.equal(@"F18");
    expect(SplitTranslateKeyCode(kVK_F19)).to.equal(@"F19");
    expect(SplitTranslateKeyCode(kVK_F20)).to.equal(@"F20");

    expect(SplitTranslateKeyCode(kVK_ANSI_KeypadDecimal)).to.equal(@".");
    expect(SplitTranslateKeyCode(kVK_ANSI_KeypadMultiply)).to.equal(@"*");
    expect(SplitTranslateKeyCode(kVK_ANSI_KeypadPlus)).to.equal(@"+");
    expect(SplitTranslateKeyCode(kVK_ANSI_KeypadClear)).to.equal(@"⌧");
    expect(SplitTranslateKeyCode(kVK_ANSI_KeypadDivide)).to.equal(@"/");
    expect(SplitTranslateKeyCode(kVK_ANSI_KeypadEnter)).to.equal(@"⌤");
    expect(SplitTranslateKeyCode(kVK_ANSI_KeypadMinus)).to.equal(@"-");
    expect(SplitTranslateKeyCode(kVK_ANSI_KeypadEquals)).to.equal(@"=");
    expect(SplitTranslateKeyCode(kVK_ANSI_Keypad0)).to.equal(@"0");
    expect(SplitTranslateKeyCode(kVK_ANSI_Keypad1)).to.equal(@"1");
    expect(SplitTranslateKeyCode(kVK_ANSI_Keypad2)).to.equal(@"2");
    expect(SplitTranslateKeyCode(kVK_ANSI_Keypad3)).to.equal(@"3");
    expect(SplitTranslateKeyCode(kVK_ANSI_Keypad4)).to.equal(@"4");
    expect(SplitTranslateKeyCode(kVK_ANSI_Keypad5)).to.equal(@"5");
    expect(SplitTranslateKeyCode(kVK_ANSI_Keypad6)).to.equal(@"6");
    expect(SplitTranslateKeyCode(kVK_ANSI_Keypad7)).to.equal(@"7");
    expect(SplitTranslateKeyCode(kVK_ANSI_Keypad8)).to.equal(@"8");
    expect(SplitTranslateKeyCode(kVK_ANSI_Keypad9)).to.equal(@"9");

    expect(SplitTranslateKeyCode(kVK_Return)).to.equal(@"↩");
    expect(SplitTranslateKeyCode(kVK_Tab)).to.equal(@"⇥");
    expect(SplitTranslateKeyCode(kVK_Space)).to.equal(@"␣");
    expect(SplitTranslateKeyCode(kVK_Delete)).to.equal(@"⌫");
    expect(SplitTranslateKeyCode(kVK_Escape)).to.equal(@"⎋");
    expect(SplitTranslateKeyCode(kVK_Command)).to.equal(@"⌘");
    expect(SplitTranslateKeyCode(kVK_Shift)).to.equal(@"⇧");
    expect(SplitTranslateKeyCode(kVK_CapsLock)).to.equal(@"⇪");
    expect(SplitTranslateKeyCode(kVK_Option)).to.equal(@"⌥");
    expect(SplitTranslateKeyCode(kVK_Control)).to.equal(@"⌃");
    expect(SplitTranslateKeyCode(kVK_RightShift)).to.equal(@"");
    expect(SplitTranslateKeyCode(kVK_RightOption)).to.equal(@"");
    expect(SplitTranslateKeyCode(kVK_RightControl)).to.equal(@"");
    expect(SplitTranslateKeyCode(kVK_Function)).to.equal(@"");
    expect(SplitTranslateKeyCode(kVK_VolumeUp)).to.equal(@"");
    expect(SplitTranslateKeyCode(kVK_VolumeDown)).to.equal(@"");
    expect(SplitTranslateKeyCode(kVK_Mute)).to.equal(@"");
    expect(SplitTranslateKeyCode(kVK_Help)).to.equal(@"");
    expect(SplitTranslateKeyCode(kVK_Home)).to.equal(@"↖");
    expect(SplitTranslateKeyCode(kVK_PageUp)).to.equal(@"⇞");
    expect(SplitTranslateKeyCode(kVK_ForwardDelete)).to.equal(@"⌦");
    expect(SplitTranslateKeyCode(kVK_End)).to.equal(@"↘");
    expect(SplitTranslateKeyCode(kVK_PageDown)).to.equal(@"⇟");
    expect(SplitTranslateKeyCode(kVK_LeftArrow)).to.equal(@"←");
    expect(SplitTranslateKeyCode(kVK_RightArrow)).to.equal(@"→");
    expect(SplitTranslateKeyCode(kVK_DownArrow)).to.equal(@"↓");
    expect(SplitTranslateKeyCode(kVK_UpArrow)).to.equal(@"↑");
  });

  it(@"should translate empty modifiers", ^{
    expect(SplitTranslateModifiers(0)).to.equal(@"");
  });

  it(@"should translate modifiers", ^{
    expect(SplitTranslateModifiers(NSEventModifierFlagControl)).to.equal(@"⌃");
    expect(SplitTranslateModifiers(NSEventModifierFlagOption)).to.equal(@"⌥");
    expect(SplitTranslateModifiers(NSEventModifierFlagShift)).to.equal(@"⇧");
    expect(SplitTranslateModifiers(NSEventModifierFlagCommand)).to.equal(@"⌘");

  });

  it(@"should translate shortcuts", ^{
    expect(SplitTranslateShortcut(shortcutForKeyBinding(@"option+command+c"))).to.equal(@"⌥⌘C");
    expect(SplitTranslateShortcut(shortcutForKeyBinding(@"option+command+f"))).to.equal(@"⌥⌘F");
    expect(SplitTranslateShortcut(shortcutForKeyBinding(@"option+command+left"))).to.equal(@"⌥⌘←");
    expect(SplitTranslateShortcut(shortcutForKeyBinding(@"option+command+right"))).to.equal(@"⌥⌘→");
    expect(SplitTranslateShortcut(shortcutForKeyBinding(@"option+command+up"))).to.equal(@"⌥⌘↑");
    expect(SplitTranslateShortcut(shortcutForKeyBinding(@"option+command+down"))).to.equal(@"⌥⌘↓");
    expect(SplitTranslateShortcut(shortcutForKeyBinding(@"control+command+left"))).to.equal(@"⌃⌘←");
    expect(SplitTranslateShortcut(shortcutForKeyBinding(@"control+shift+command+left"))).to.equal(@"⌃⇧⌘←");
    expect(SplitTranslateShortcut(shortcutForKeyBinding(@"control+command+right"))).to.equal(@"⌃⌘→");
    expect(SplitTranslateShortcut(shortcutForKeyBinding(@"control+shift+command+right"))).to.equal(@"⌃⇧⌘→");
    expect(SplitTranslateShortcut(shortcutForKeyBinding(@"control+option+command+right"))).to.equal(@"⌃⌥⌘→");
    expect(SplitTranslateShortcut(shortcutForKeyBinding(@"control+option+command+left"))).to.equal(@"⌃⌥⌘←");
    expect(SplitTranslateShortcut(shortcutForKeyBinding(@"control+option+right"))).to.equal(@"⌃⌥→");
    expect(SplitTranslateShortcut(shortcutForKeyBinding(@"control+option+left"))).to.equal(@"⌃⌥←");
    expect(SplitTranslateShortcut(shortcutForKeyBinding(@"control+option+shift+right"))).to.equal(@"⌃⌥⇧→");
    expect(SplitTranslateShortcut(shortcutForKeyBinding(@"control+option+shift+left"))).to.equal(@"⌃⌥⇧←");
    expect(SplitTranslateShortcut(shortcutForKeyBinding(@"option+command+z"))).to.equal(@"⌥⌘Z");
    expect(SplitTranslateShortcut(shortcutForKeyBinding(@"option+shift+command+z"))).to.equal(@"⌥⇧⌘Z");
  });

  it(@"should convert empty modifiers", ^{
    expect(SplitConvertCocoaModifiersToCarbon(0)).to.equal(0);
    expect(SplitConvertCarbonModifiersToCocoa(0)).to.equal(0);
  });

  it(@"should convert invalid modifiers", ^{
    expect(SplitConvertCocoaModifiersToCarbon(42)).to.equal(0);
    expect(SplitConvertCarbonModifiersToCocoa(42)).to.equal(0);
  });

  it(@"should convert Cocoa modifiers to Carbon modifiers", ^{
    expect(SplitConvertCocoaModifiersToCarbon(NSEventModifierFlagControl)).to.equal(controlKey);
    expect(SplitConvertCocoaModifiersToCarbon(NSEventModifierFlagOption)).to.equal(optionKey);
    expect(SplitConvertCocoaModifiersToCarbon(NSEventModifierFlagShift)).to.equal(shiftKey);
    expect(SplitConvertCocoaModifiersToCarbon(NSEventModifierFlagCommand)).to.equal(cmdKey);
  });

  it(@"should convert Carbon modifiers to Cocoa modifiers", ^{
    expect(SplitConvertCarbonModifiersToCocoa(controlKey)).to.equal(NSEventModifierFlagControl);
    expect(SplitConvertCarbonModifiersToCocoa(optionKey)).to.equal(NSEventModifierFlagOption);
    expect(SplitConvertCarbonModifiersToCocoa(shiftKey)).to.equal(NSEventModifierFlagShift);
    expect(SplitConvertCarbonModifiersToCocoa(cmdKey)).to.equal(NSEventModifierFlagCommand);
  });

  it(@"should convert modifiers to Carbon modifiers if necessary", ^{
    expect(SplitConvertModifiersToCarbonIfNecessary(controlKey)).to.equal(controlKey);
    expect(SplitConvertModifiersToCarbonIfNecessary(optionKey)).to.equal(optionKey);
    expect(SplitConvertModifiersToCarbonIfNecessary(shiftKey)).to.equal(shiftKey);
    expect(SplitConvertModifiersToCarbonIfNecessary(cmdKey)).to.equal(cmdKey);
    expect(SplitConvertModifiersToCarbonIfNecessary(NSEventModifierFlagControl)).to.equal(controlKey);
    expect(SplitConvertModifiersToCarbonIfNecessary(NSEventModifierFlagOption)).to.equal(optionKey);
    expect(SplitConvertModifiersToCarbonIfNecessary(NSEventModifierFlagShift)).to.equal(shiftKey);
    expect(SplitConvertModifiersToCarbonIfNecessary(NSEventModifierFlagCommand)).to.equal(cmdKey);
  });

  it(@"should convert modifiers to Cocoa modifiers if necessary", ^{
    expect(SplitConvertModifiersToCocoaIfNecessary(NSEventModifierFlagControl)).to.equal(NSEventModifierFlagControl);
    expect(SplitConvertModifiersToCocoaIfNecessary(NSEventModifierFlagOption)).to.equal(NSEventModifierFlagOption);
    expect(SplitConvertModifiersToCocoaIfNecessary(NSEventModifierFlagShift)).to.equal(NSEventModifierFlagShift);
    expect(SplitConvertModifiersToCocoaIfNecessary(NSEventModifierFlagCommand)).to.equal(NSEventModifierFlagCommand);
    expect(SplitConvertModifiersToCocoaIfNecessary(controlKey)).to.equal(NSEventModifierFlagControl);
    expect(SplitConvertModifiersToCocoaIfNecessary(optionKey)).to.equal(NSEventModifierFlagOption);
    expect(SplitConvertModifiersToCocoaIfNecessary(shiftKey)).to.equal(NSEventModifierFlagShift);
    expect(SplitConvertModifiersToCocoaIfNecessary(cmdKey)).to.equal(NSEventModifierFlagCommand);
  });
});
SpecEnd

static SplitShortcut *shortcutForKeyBinding(NSString *keyBinding)
{
  return [[SplitShortcut alloc] initWithShortcutName:nil shortcutKeyBinding:keyBinding];
}
