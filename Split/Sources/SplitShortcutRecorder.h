#import <Cocoa/Cocoa.h>

@class SplitShortcut;
@class SplitShortcutValidation;

@protocol SplitShortcutRecorderDelegate;

@interface SplitShortcutRecorder : NSView

@property (nonatomic, copy) NSString *shortcutName;
@property (nonatomic, strong) SplitShortcut *shortcut;
@property (nonatomic, strong) SplitShortcutValidation *shortcutValidation;
@property (nonatomic, weak) id<SplitShortcutRecorderDelegate> delegate;

@end
