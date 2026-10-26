#import <Carbon/Carbon.h>
#import <Expecta/Expecta.h>
#import <Specta/Specta.h>

#import "SplitShortcut.h"
#import "SplitShortcutKeyBindings.h"

static SplitShortcut *shortcutForKeyBinding(NSString *keyBinding);

SpecBegin(SplitShortcutKeyBindings)
describe(@"SplitShortcutKeyBindings", ^{
  it(@"should convert an empty or nil key binding to nil modifiers", ^{
    expect(SplitConvertShortcutKeyBindingToModifiers(nil)).to.equal(nil);
    expect(SplitConvertShortcutKeyBindingToModifiers(@"")).to.equal(nil);
    expect(SplitConvertShortcutKeyBindingToModifiers(@" ")).to.equal(nil);
  });

  it(@"should convert key bindings to modifiers", ^{
    expect(SplitConvertShortcutKeyBindingToModifiers(@"cmd+c")).to.equal(cmdKey);
    expect(SplitConvertShortcutKeyBindingToModifiers(@"shift+cmd+c")).to.equal(shiftKey |cmdKey);
    expect(SplitConvertShortcutKeyBindingToModifiers(@"alt+shift+cmd+c")).to.equal(optionKey | shiftKey |cmdKey);
    expect(SplitConvertShortcutKeyBindingToModifiers(@"ctrl+alt+shift+cmd+c")).to.equal(controlKey | optionKey | shiftKey | cmdKey);
    expect(SplitConvertShortcutKeyBindingToModifiers(@"command+c")).to.equal(cmdKey);
    expect(SplitConvertShortcutKeyBindingToModifiers(@"shift+command+c")).to.equal(shiftKey |cmdKey);
    expect(SplitConvertShortcutKeyBindingToModifiers(@"option+shift+command+c")).to.equal(optionKey | shiftKey |cmdKey);
    expect(SplitConvertShortcutKeyBindingToModifiers(@"control+option+shift+command+c")).to.equal(controlKey | optionKey | shiftKey | cmdKey);
  });

  it(@"should convert mixed case key bindings to modifiers", ^{
    expect(SplitConvertShortcutKeyBindingToModifiers(@"Cmd+C")).to.equal(cmdKey);
    expect(SplitConvertShortcutKeyBindingToModifiers(@"Shift+Cmd+C")).to.equal(shiftKey |cmdKey);
    expect(SplitConvertShortcutKeyBindingToModifiers(@"Alt+Shift+Cmd+C")).to.equal(optionKey | shiftKey |cmdKey);
    expect(SplitConvertShortcutKeyBindingToModifiers(@"Ctrl+Alt+Shift+Cmd+C")).to.equal(controlKey | optionKey | shiftKey | cmdKey);
    expect(SplitConvertShortcutKeyBindingToModifiers(@"COMMAND+C")).to.equal(cmdKey);
    expect(SplitConvertShortcutKeyBindingToModifiers(@"SHIFT+COMMAND+C")).to.equal(shiftKey |cmdKey);
    expect(SplitConvertShortcutKeyBindingToModifiers(@"OPTION+SHIFT+COMMAND+C")).to.equal(optionKey | shiftKey |cmdKey);
    expect(SplitConvertShortcutKeyBindingToModifiers(@"CONTROL+OPTION+SHIFT+COMMAND+C")).to.equal(controlKey | optionKey | shiftKey | cmdKey);
  });

  it(@"should convert key bindings with whitespace to modifiers", ^{
    expect(SplitConvertShortcutKeyBindingToModifiers(@" alt  +   shift    +     cmd    +c")).to.equal(optionKey | shiftKey |cmdKey);
  });

  it(@"should convert an empty or nil key binding to nil key codes", ^{
    expect(SplitConvertShortcutKeyBindingToKeyCode(nil)).to.equal(nil);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"")).to.equal(nil);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@" ")).to.equal(nil);
  });

  it(@"should convert lowercase alphabetical key bindings to key codes", ^{
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"a")).to.equal(kVK_ANSI_A);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"b")).to.equal(kVK_ANSI_B);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"c")).to.equal(kVK_ANSI_C);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"d")).to.equal(kVK_ANSI_D);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"e")).to.equal(kVK_ANSI_E);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"f")).to.equal(kVK_ANSI_F);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"g")).to.equal(kVK_ANSI_G);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"h")).to.equal(kVK_ANSI_H);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"i")).to.equal(kVK_ANSI_I);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"j")).to.equal(kVK_ANSI_J);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"k")).to.equal(kVK_ANSI_K);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"l")).to.equal(kVK_ANSI_L);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"m")).to.equal(kVK_ANSI_M);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"n")).to.equal(kVK_ANSI_N);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"o")).to.equal(kVK_ANSI_O);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"p")).to.equal(kVK_ANSI_P);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"q")).to.equal(kVK_ANSI_Q);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"r")).to.equal(kVK_ANSI_R);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"s")).to.equal(kVK_ANSI_S);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"t")).to.equal(kVK_ANSI_T);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"u")).to.equal(kVK_ANSI_U);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"v")).to.equal(kVK_ANSI_V);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"w")).to.equal(kVK_ANSI_W);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"x")).to.equal(kVK_ANSI_X);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"y")).to.equal(kVK_ANSI_Y);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"z")).to.equal(kVK_ANSI_Z);
  });

  it(@"should convert uppercase alphabetical key bindings to key codes", ^{
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"A")).to.equal(kVK_ANSI_A);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"B")).to.equal(kVK_ANSI_B);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"C")).to.equal(kVK_ANSI_C);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"D")).to.equal(kVK_ANSI_D);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"E")).to.equal(kVK_ANSI_E);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"F")).to.equal(kVK_ANSI_F);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"G")).to.equal(kVK_ANSI_G);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"H")).to.equal(kVK_ANSI_H);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"I")).to.equal(kVK_ANSI_I);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"J")).to.equal(kVK_ANSI_J);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"K")).to.equal(kVK_ANSI_K);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"L")).to.equal(kVK_ANSI_L);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"M")).to.equal(kVK_ANSI_M);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"N")).to.equal(kVK_ANSI_N);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"O")).to.equal(kVK_ANSI_O);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"P")).to.equal(kVK_ANSI_P);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Q")).to.equal(kVK_ANSI_Q);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"R")).to.equal(kVK_ANSI_R);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"S")).to.equal(kVK_ANSI_S);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"T")).to.equal(kVK_ANSI_T);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"U")).to.equal(kVK_ANSI_U);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"V")).to.equal(kVK_ANSI_V);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"W")).to.equal(kVK_ANSI_W);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"X")).to.equal(kVK_ANSI_X);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Y")).to.equal(kVK_ANSI_Y);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Z")).to.equal(kVK_ANSI_Z);
  });

  it(@"should convert numeric key bindings to key codes", ^{
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"0")).to.equal(kVK_ANSI_0);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"1")).to.equal(kVK_ANSI_1);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"2")).to.equal(kVK_ANSI_2);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"3")).to.equal(kVK_ANSI_3);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"4")).to.equal(kVK_ANSI_4);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"5")).to.equal(kVK_ANSI_5);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"6")).to.equal(kVK_ANSI_6);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"7")).to.equal(kVK_ANSI_7);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"8")).to.equal(kVK_ANSI_8);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"9")).to.equal(kVK_ANSI_9);
  });

  it(@"should convert alphabetical key bindings with modifiers to key codes", ^{
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"cmd+a")).to.equal(kVK_ANSI_A);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"shift+cmd+b")).to.equal(kVK_ANSI_B);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"alt+shift+cmd+c")).to.equal(kVK_ANSI_C);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"ctrl+alt+shift+cmd+d")).to.equal(kVK_ANSI_D);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"command+e")).to.equal(kVK_ANSI_E);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"shift+command+f")).to.equal(kVK_ANSI_F);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"option+shift+command+g")).to.equal(kVK_ANSI_G);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"control+option+shift+command+h")).to.equal(kVK_ANSI_H);
  });

  it(@"should convert alphanumeric key bindings with whitespace to key codes", ^{
    expect(SplitConvertShortcutKeyBindingToKeyCode(@" cmd  +   a    ")).to.equal(kVK_ANSI_A);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@" shift  +   cmd    +     0      ")).to.equal(kVK_ANSI_0);
  });

  it(@"should convert named key bindings to key codes", ^{
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"f1")).to.equal(kVK_F1);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"f2")).to.equal(kVK_F2);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"f3")).to.equal(kVK_F3);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"f4")).to.equal(kVK_F4);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"f5")).to.equal(kVK_F5);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"f6")).to.equal(kVK_F6);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"f7")).to.equal(kVK_F7);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"f8")).to.equal(kVK_F8);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"f9")).to.equal(kVK_F9);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"f10")).to.equal(kVK_F10);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"f11")).to.equal(kVK_F11);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"f12")).to.equal(kVK_F12);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"f13")).to.equal(kVK_F13);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"f14")).to.equal(kVK_F14);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"f15")).to.equal(kVK_F15);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"f16")).to.equal(kVK_F16);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"f17")).to.equal(kVK_F17);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"f18")).to.equal(kVK_F18);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"f19")).to.equal(kVK_F19);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"f20")).to.equal(kVK_F20);

    expect(SplitConvertShortcutKeyBindingToKeyCode(@"keypaddecimal")).to.equal(kVK_ANSI_KeypadDecimal);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"keypadmultiply")).to.equal(kVK_ANSI_KeypadMultiply);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"keypadplus")).to.equal(kVK_ANSI_KeypadPlus);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"keypadclear")).to.equal(kVK_ANSI_KeypadClear);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"keypaddivide")).to.equal(kVK_ANSI_KeypadDivide);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"keypadenter")).to.equal(kVK_ANSI_KeypadEnter);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"keypadminus")).to.equal(kVK_ANSI_KeypadMinus);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"keypadequals")).to.equal(kVK_ANSI_KeypadEquals);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"keypad0")).to.equal(kVK_ANSI_Keypad0);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"keypad1")).to.equal(kVK_ANSI_Keypad1);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"keypad2")).to.equal(kVK_ANSI_Keypad2);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"keypad3")).to.equal(kVK_ANSI_Keypad3);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"keypad4")).to.equal(kVK_ANSI_Keypad4);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"keypad5")).to.equal(kVK_ANSI_Keypad5);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"keypad6")).to.equal(kVK_ANSI_Keypad6);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"keypad7")).to.equal(kVK_ANSI_Keypad7);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"keypad8")).to.equal(kVK_ANSI_Keypad8);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"keypad9")).to.equal(kVK_ANSI_Keypad9);

    expect(SplitConvertShortcutKeyBindingToKeyCode(@"return")).to.equal(kVK_Return);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"tab")).to.equal(kVK_Tab);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"space")).to.equal(kVK_Space);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"delete")).to.equal(kVK_Delete);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"escape")).to.equal(kVK_Escape);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"command")).to.equal(kVK_Command);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"shift")).to.equal(kVK_Shift);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"capslock")).to.equal(kVK_CapsLock);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"option")).to.equal(kVK_Option);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"control")).to.equal(kVK_Control);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"rightshift")).to.equal(kVK_RightShift);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"rightoption")).to.equal(kVK_RightOption);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"rightcontrol")).to.equal(kVK_RightControl);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"function")).to.equal(kVK_Function);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"volumeup")).to.equal(kVK_VolumeUp);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"volumedown")).to.equal(kVK_VolumeDown);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"mute")).to.equal(kVK_Mute);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"help")).to.equal(kVK_Help);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"home")).to.equal(kVK_Home);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"pageup")).to.equal(kVK_PageUp);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"forwarddelete")).to.equal(kVK_ForwardDelete);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"end")).to.equal(kVK_End);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"pagedown")).to.equal(kVK_PageDown);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"left")).to.equal(kVK_LeftArrow);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"right")).to.equal(kVK_RightArrow);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"down")).to.equal(kVK_DownArrow);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"up")).to.equal(kVK_UpArrow);
  });

  it(@"should convert mixed case named key bindings to key codes", ^{
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"F1")).to.equal(kVK_F1);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"F2")).to.equal(kVK_F2);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"F3")).to.equal(kVK_F3);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"F4")).to.equal(kVK_F4);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"F5")).to.equal(kVK_F5);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"F6")).to.equal(kVK_F6);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"F7")).to.equal(kVK_F7);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"F8")).to.equal(kVK_F8);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"F9")).to.equal(kVK_F9);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"F10")).to.equal(kVK_F10);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"F11")).to.equal(kVK_F11);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"F12")).to.equal(kVK_F12);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"F13")).to.equal(kVK_F13);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"F14")).to.equal(kVK_F14);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"F15")).to.equal(kVK_F15);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"F16")).to.equal(kVK_F16);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"F17")).to.equal(kVK_F17);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"F18")).to.equal(kVK_F18);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"F19")).to.equal(kVK_F19);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"F20")).to.equal(kVK_F20);

    expect(SplitConvertShortcutKeyBindingToKeyCode(@"KeypadDecimal")).to.equal(kVK_ANSI_KeypadDecimal);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"KeypadMultiply")).to.equal(kVK_ANSI_KeypadMultiply);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"KeypadPlus")).to.equal(kVK_ANSI_KeypadPlus);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"KeypadClear")).to.equal(kVK_ANSI_KeypadClear);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"KeypadDivide")).to.equal(kVK_ANSI_KeypadDivide);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"KeypadEnter")).to.equal(kVK_ANSI_KeypadEnter);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"KeypadMinus")).to.equal(kVK_ANSI_KeypadMinus);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"KeypadEquals")).to.equal(kVK_ANSI_KeypadEquals);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Keypad0")).to.equal(kVK_ANSI_Keypad0);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Keypad1")).to.equal(kVK_ANSI_Keypad1);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Keypad2")).to.equal(kVK_ANSI_Keypad2);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Keypad3")).to.equal(kVK_ANSI_Keypad3);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Keypad4")).to.equal(kVK_ANSI_Keypad4);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Keypad5")).to.equal(kVK_ANSI_Keypad5);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Keypad6")).to.equal(kVK_ANSI_Keypad6);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Keypad7")).to.equal(kVK_ANSI_Keypad7);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Keypad8")).to.equal(kVK_ANSI_Keypad8);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Keypad9")).to.equal(kVK_ANSI_Keypad9);

    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Return")).to.equal(kVK_Return);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Tab")).to.equal(kVK_Tab);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Space")).to.equal(kVK_Space);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Delete")).to.equal(kVK_Delete);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Escape")).to.equal(kVK_Escape);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Command")).to.equal(kVK_Command);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Shift")).to.equal(kVK_Shift);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"CapsLock")).to.equal(kVK_CapsLock);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Option")).to.equal(kVK_Option);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Control")).to.equal(kVK_Control);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"RightShift")).to.equal(kVK_RightShift);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"RightOption")).to.equal(kVK_RightOption);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"RightControl")).to.equal(kVK_RightControl);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Function")).to.equal(kVK_Function);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"VolumeUp")).to.equal(kVK_VolumeUp);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"VolumeDown")).to.equal(kVK_VolumeDown);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Mute")).to.equal(kVK_Mute);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Help")).to.equal(kVK_Help);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Home")).to.equal(kVK_Home);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"PageUp")).to.equal(kVK_PageUp);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"ForwardDelete")).to.equal(kVK_ForwardDelete);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"End")).to.equal(kVK_End);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"PageDown")).to.equal(kVK_PageDown);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Left")).to.equal(kVK_LeftArrow);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Right")).to.equal(kVK_RightArrow);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Down")).to.equal(kVK_DownArrow);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"Up")).to.equal(kVK_UpArrow);
  });

  it(@"should convert named key bindings with modifiers to key codes", ^{
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"cmd+up")).to.equal(kVK_UpArrow);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"shift+cmd+down")).to.equal(kVK_DownArrow);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"alt+shift+cmd+left")).to.equal(kVK_LeftArrow);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"ctrl+alt+shift+cmd+right")).to.equal(kVK_RightArrow);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"command+space")).to.equal(kVK_Space);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"shift+command+f1")).to.equal(kVK_F1);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"option+shift+command+keypad0")).to.equal(kVK_ANSI_Keypad0);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"control+option+shift+command+escape")).to.equal(kVK_Escape);
  });

  it(@"should convert mixed case named key bindings with modifiers to key codes", ^{
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"cmd+Up")).to.equal(kVK_UpArrow);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"shift+cmd+Down")).to.equal(kVK_DownArrow);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"alt+shift+cmd+left")).to.equal(kVK_LeftArrow);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"ctrl+alt+shift+cmd+Right")).to.equal(kVK_RightArrow);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"command+SPACE")).to.equal(kVK_Space);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"shift+command+F1")).to.equal(kVK_F1);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"option+shift+command+KEYPAD0")).to.equal(kVK_ANSI_Keypad0);
    expect(SplitConvertShortcutKeyBindingToKeyCode(@"control+option+shift+command+ESCAPE")).to.equal(kVK_Escape);
  });

  it(@"should convert empty shortcuts to nil key bindings", ^{
    expect(SplitConvertShortcutToKeyBinding(shortcutForKeyBinding(nil))).to.equal(nil);
  });

  it(@"should convert shortcuts to key bindings", ^{
    expect(SplitConvertShortcutToKeyBinding(shortcutForKeyBinding(@"alt+cmd+c"))).to.equal(@"alt+cmd+c");
    expect(SplitConvertShortcutToKeyBinding(shortcutForKeyBinding(@"alt+cmd+f"))).to.equal(@"alt+cmd+f");
    expect(SplitConvertShortcutToKeyBinding(shortcutForKeyBinding(@"alt+cmd+left"))).to.equal(@"alt+cmd+left");
    expect(SplitConvertShortcutToKeyBinding(shortcutForKeyBinding(@"alt+cmd+right"))).to.equal(@"alt+cmd+right");
    expect(SplitConvertShortcutToKeyBinding(shortcutForKeyBinding(@"alt+cmd+up"))).to.equal(@"alt+cmd+up");
    expect(SplitConvertShortcutToKeyBinding(shortcutForKeyBinding(@"alt+cmd+down"))).to.equal(@"alt+cmd+down");
    expect(SplitConvertShortcutToKeyBinding(shortcutForKeyBinding(@"ctrl+cmd+left"))).to.equal(@"ctrl+cmd+left");
    expect(SplitConvertShortcutToKeyBinding(shortcutForKeyBinding(@"ctrl+shift+cmd+left"))).to.equal(@"ctrl+shift+cmd+left");
    expect(SplitConvertShortcutToKeyBinding(shortcutForKeyBinding(@"ctrl+cmd+right"))).to.equal(@"ctrl+cmd+right");
    expect(SplitConvertShortcutToKeyBinding(shortcutForKeyBinding(@"ctrl+shift+cmd+right"))).to.equal(@"ctrl+shift+cmd+right");
    expect(SplitConvertShortcutToKeyBinding(shortcutForKeyBinding(@"ctrl+alt+cmd+right"))).to.equal(@"ctrl+alt+cmd+right");
    expect(SplitConvertShortcutToKeyBinding(shortcutForKeyBinding(@"ctrl+alt+cmd+left"))).to.equal(@"ctrl+alt+cmd+left");
    expect(SplitConvertShortcutToKeyBinding(shortcutForKeyBinding(@"ctrl+alt+right"))).to.equal(@"ctrl+alt+right");
    expect(SplitConvertShortcutToKeyBinding(shortcutForKeyBinding(@"ctrl+alt+left"))).to.equal(@"ctrl+alt+left");
    expect(SplitConvertShortcutToKeyBinding(shortcutForKeyBinding(@"ctrl+alt+shift+right"))).to.equal(@"ctrl+alt+shift+right");
    expect(SplitConvertShortcutToKeyBinding(shortcutForKeyBinding(@"ctrl+alt+shift+left"))).to.equal(@"ctrl+alt+shift+left");
    expect(SplitConvertShortcutToKeyBinding(shortcutForKeyBinding(@"alt+cmd+z"))).to.equal(@"alt+cmd+z");
    expect(SplitConvertShortcutToKeyBinding(shortcutForKeyBinding(@"alt+shift+cmd+z"))).to.equal(@"alt+shift+cmd+z");
  });
});
SpecEnd

static SplitShortcut *shortcutForKeyBinding(NSString *keyBinding)
{
  return [[SplitShortcut alloc] initWithShortcutName:nil shortcutKeyBinding:keyBinding];
}
