#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>
#import <Expecta/Expecta.h>
#import <Specta/Specta.h>

#import "SplitShortcut.h"

SpecBegin(SplitShortcut)
describe(@"SplitShortcut", ^{
  it(@"should be initialized with a key binding", ^{
    SplitShortcut *shortcut = [[SplitShortcut alloc] initWithShortcutName:@"MoveToCenter"
                                                               shortcutKeyBinding:@"option+command+c"];
    expect(shortcut.shortcutKeyCode).to.equal(kVK_ANSI_C);
    expect(shortcut.shortcutModifiers).to.equal(optionKey | cmdKey);
  });

  it(@"should be copied with a new shortcut action", ^{
    SplitShortcut *shortcut = [[SplitShortcut alloc] initWithShortcutName:@"MoveToCenter"
                                                                  shortcutKeyCode:kVK_ANSI_C
                                                                shortcutModifiers:NSEventModifierFlagOption | NSEventModifierFlagCommand];
    expect(shortcut.shortcutAction).to.beFalsy;
    expect([shortcut copyWithShortcutAction:^(SplitShortcut *shortcut) {}].shortcutAction).to.beTruthy;
  });

  it(@"should trigger shortcut actions", ^{
    __block BOOL shortcutActionTriggered;
    SplitShortcut *shortcut = [[SplitShortcut alloc] initWithShortcutName:@"MoveToCenter"
                                                                  shortcutKeyCode:kVK_ANSI_C
                                                                shortcutModifiers:NSEventModifierFlagOption | NSEventModifierFlagCommand
                                                                   shortcutAction:^(SplitShortcut *shortcut) {
                                                                     shortcutActionTriggered = YES;
                                                                   }];
    [shortcut triggerShortcutAction];
    expect(shortcutActionTriggered).to.beTruthy;
  });

  it(@"should determine if the shortcut is cleared", ^{
    expect([[[SplitShortcut alloc] initWithShortcutName:nil shortcutKeyBinding:nil] isClearedShortcut]).to.beTruthy;
    expect([[[SplitShortcut alloc] initWithShortcutName:nil shortcutKeyBinding:@""] isClearedShortcut]).to.beTruthy;
    expect([[[SplitShortcut alloc] initWithShortcutName:nil
                                            shortcutKeyCode:-1
                                          shortcutModifiers:0] isClearedShortcut]).to.beTruthy;
    expect([[[SplitShortcut alloc] initWithShortcutName:@"MoveToCenter"
                                            shortcutKeyCode:-1
                                          shortcutModifiers:0] isClearedShortcut]).to.beTruthy;
  });

  it(@"should provide a display string", ^{
    expect([[[SplitShortcut alloc] initWithShortcutName:@"MoveToCenter"
                                            shortcutKeyCode:kVK_ANSI_C
                                          shortcutModifiers:NSEventModifierFlagOption | NSEventModifierFlagCommand] displayString]).to.equal(@"⌥⌘C");
  });

  it(@"should provide a key binding", ^{
    SplitShortcut *shortcut = [[SplitShortcut alloc] initWithShortcutName:@"MoveToCenter"
                                                               shortcutKeyBinding:@"alt+cmd+c"];
    expect(shortcut.shortcutKeyBinding).to.equal(@"alt+cmd+c");
  });

  it(@"should support equality", ^{
    SplitShortcut *shortcut1 = [[SplitShortcut alloc] initWithShortcutName:@"MoveToCenter"
                                                                   shortcutKeyCode:kVK_ANSI_C
                                                                 shortcutModifiers:NSEventModifierFlagOption | NSEventModifierFlagCommand];
    SplitShortcut *shortcut2 = [[SplitShortcut alloc] initWithShortcutName:@"MoveToCenter"
                                                                   shortcutKeyCode:kVK_ANSI_C
                                                                 shortcutModifiers:NSEventModifierFlagOption | NSEventModifierFlagCommand];
    SplitShortcut *shortcut3 = [[SplitShortcut alloc] initWithShortcutName:nil
                                                                   shortcutKeyCode:kVK_ANSI_C
                                                                 shortcutModifiers:NSEventModifierFlagOption | NSEventModifierFlagCommand];
    expect(shortcut1).to.equal(shortcut2);
    expect(shortcut1).to.equal(shortcut3);
    expect(shortcut1).notTo.equal([[SplitShortcut alloc] initWithShortcutName:nil
                                                                  shortcutKeyCode:-1
                                                                shortcutModifiers:0]);
  });

  it(@"should determine if the shortcut is contains modifiers", ^{
    SplitShortcut *shortcut = [[SplitShortcut alloc] initWithShortcutName:@"MoveToCenter"
                                                                  shortcutKeyCode:kVK_ANSI_C
                                                                shortcutModifiers:NSEventModifierFlagOption | NSEventModifierFlagCommand];
    expect([shortcut containsModifiers:NSEventModifierFlagOption]).to.beTruthy;
    expect([shortcut containsModifiers:NSEventModifierFlagOption | NSEventModifierFlagCommand]).to.beTruthy;
    expect([shortcut containsModifiers:NSEventModifierFlagControl]).to.beFalsy;
  });
});
SpecEnd
