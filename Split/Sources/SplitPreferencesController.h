#import <Cocoa/Cocoa.h>

#import "SplitShortcutRecorderDelegate.h"

@class SplitAppDelegate;
@class SplitShortcutManager;
@class SplitShortcutRecorder;
@class SplitWindowPositionManager;

@protocol SplitShortcutStorage;

@interface SplitPreferencesController : NSWindowController <SplitShortcutRecorderDelegate>

@property (nonatomic, strong) IBOutlet SplitShortcutRecorder *moveToCenterShortcutRecorder;
@property (nonatomic, strong) IBOutlet SplitShortcutRecorder *moveToFullscreenShortcutRecorder;
@property (nonatomic, strong) IBOutlet SplitShortcutRecorder *moveToLeftShortcutRecorder;
@property (nonatomic, strong) IBOutlet SplitShortcutRecorder *moveToRightShortcutRecorder;
@property (nonatomic, strong) IBOutlet SplitShortcutRecorder *moveToTopShortcutRecorder;
@property (nonatomic, strong) IBOutlet SplitShortcutRecorder *moveToBottomShortcutRecorder;
@property (nonatomic, strong) IBOutlet SplitShortcutRecorder *moveToUpperLeftShortcutRecorder;
@property (nonatomic, strong) IBOutlet SplitShortcutRecorder *moveToLowerLeftShortcutRecorder;
@property (nonatomic, strong) IBOutlet SplitShortcutRecorder *moveToUpperRightShortcutRecorder;
@property (nonatomic, strong) IBOutlet SplitShortcutRecorder *moveToLowerRightShortcutRecorder;
@property (nonatomic, strong) IBOutlet SplitShortcutRecorder *moveToNextDisplayShortcutRecorder;
@property (nonatomic, strong) IBOutlet SplitShortcutRecorder *moveToPreviousDisplayShortcutRecorder;
@property (nonatomic, strong) IBOutlet SplitShortcutRecorder *moveToNextThirdShortcutRecorder;
@property (nonatomic, strong) IBOutlet SplitShortcutRecorder *moveToPreviousThirdShortcutRecorder;
@property (nonatomic, strong) IBOutlet SplitShortcutRecorder *makeLargerShortcutRecorder;
@property (nonatomic, strong) IBOutlet SplitShortcutRecorder *makeSmallerShortcutRecorder;
@property (nonatomic, strong) IBOutlet SplitShortcutRecorder *undoLastMoveShortcutRecorder;
@property (nonatomic, strong) IBOutlet SplitShortcutRecorder *redoLastMoveShortcutRecorder;

@property (nonatomic, strong) IBOutlet NSView *footerView;
@property (nonatomic, strong) IBOutlet NSView *shortcutModifierLegendFooterView;
@property (nonatomic, strong) IBOutlet NSView *optionsFooterView;

@property (nonatomic, strong) IBOutlet NSButton *loginItemEnabled;
@property (nonatomic, strong) IBOutlet NSPopUpButton *statusItemEnabled;

- (instancetype)initWithShortcutManager:(SplitShortcutManager *)shortcutManager
                  windowPositionManager:(SplitWindowPositionManager *)windowPositionManager
                        shortcutStorage:(id<SplitShortcutStorage>)shortcutStorage;

- (void)loadRegisteredShortcuts;

- (IBAction)swapFooterViews:(id)sender;

- (IBAction)restoreDefaults:(id)sender;

- (IBAction)toggleLoginItem:(id)sender;
- (IBAction)toggleStatusItem:(id)sender;

@end
