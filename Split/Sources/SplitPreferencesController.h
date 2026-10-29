#import <Cocoa/Cocoa.h>

#import "SplitShortcutRecorderDelegate.h"
#import "SplitWindowAction.h"

@class SplitShortcutManager;
@class SplitWindowPositionManager;

@protocol SplitShortcutStorage;

NS_ASSUME_NONNULL_BEGIN

/// The settings window, built in code: a "General" tab (login item, menu bar icon, move
/// highlight, updates, live Accessibility status) and a "Shortcuts" tab grouped like the status
/// menu, each row with the same small picture the menu uses.
@interface SplitPreferencesController : NSWindowController <SplitShortcutRecorderDelegate>

/// Runs a window action (used when a shortcut recorded here is pressed). Set by the app delegate
/// so shortcuts behave the same everywhere, including the on-screen highlight.
@property (nonatomic, copy, nullable) void (^windowActionHandler)(SplitWindowAction *action);

- (instancetype)initWithShortcutManager:(SplitShortcutManager *)shortcutManager
                  windowPositionManager:(SplitWindowPositionManager *)windowPositionManager
                        shortcutStorage:(id<SplitShortcutStorage>)shortcutStorage;

- (void)loadRegisteredShortcuts;

@end

/// Shortcut groups in the order the status menu shows them. Each entry: section title key,
/// optional hint key, shortcut names.
NSArray<NSArray *> *SplitShortcutSections(void);

/// Posted when "Check for updates automatically" changes. The new value is in the user default
/// "AutomaticUpdateCheckEnabled".
extern NSNotificationName const SplitAutomaticUpdateCheckChangedNotification;

NS_ASSUME_NONNULL_END
