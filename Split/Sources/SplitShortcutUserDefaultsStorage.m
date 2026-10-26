#import "SplitShortcutUserDefaultsStorage.h"

@implementation SplitShortcutUserDefaultsStorage

+ (void)initialize
{
  [NSKeyedUnarchiver setClass:[SplitShortcut class] forClassName:@"SpectacleHotKey"];
  [NSKeyedUnarchiver setClass:[SplitShortcut class] forClassName:@"SpectacleShortcut"];
  [NSKeyedUnarchiver setClass:[SplitShortcut class] forClassName:@"ZeroKitHotKey"];
  [NSKeyedUnarchiver setClass:[SplitShortcut class] forClassName:@"ZKHotKey"];
}

- (NSArray<SplitShortcut *> *)loadShortcutsWithAction:(SplitShortcutAction)action
{
  NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
  NSMutableDictionary<NSString *, NSData *> *shortcutsFromUserDefaults = [NSMutableDictionary new];
  for (NSString *shortcutName in [self shortcutNames]) {
    shortcutsFromUserDefaults[shortcutName] = [userDefaults dataForKey:shortcutName];
  }
  return [self shortcutsFromDictionary:shortcutsFromUserDefaults action:action];
}

- (void)storeShortcuts:(NSArray<SplitShortcut *> *)shortcuts
{
  NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
  for (SplitShortcut *shortcut in shortcuts) {
    NSError *error = nil;
    NSData *shortcutData = [NSKeyedArchiver archivedDataWithRootObject:shortcut requiringSecureCoding:NO error:&error];
    if (!shortcutData) {
      NSLog(@"Unable to archive shortcut %@: %@", shortcut.shortcutName, error);
      continue;
    }
    NSString *shortcutName = shortcut.shortcutName;
    if (![shortcutData isEqualToData:[userDefaults dataForKey:shortcutName]]) {
      [userDefaults setObject:shortcutData forKey:shortcutName];
    }
  }
}

- (BOOL)isMigrationNeeded
{
  return NO;
}

- (NSArray<NSString *> *)shortcutNames
{
  return @[
           @"MoveToCenter",
           @"MoveToFullscreen",
           @"MoveToLeftHalf",
           @"MoveToRightHalf",
           @"MoveToTopHalf",
           @"MoveToBottomHalf",
           @"MoveToUpperLeft",
           @"MoveToLowerLeft",
           @"MoveToUpperRight",
           @"MoveToLowerRight",
           @"MoveToNextDisplay",
           @"MoveToPreviousDisplay",
           @"MoveToNextThird",
           @"MoveToPreviousThird",
           @"MakeLarger",
           @"MakeSmaller",
           @"UndoLastMove",
           @"RedoLastMove",
           ];
}

- (NSArray<SplitShortcut *> *)shortcutsFromDictionary:(NSDictionary<NSString *, NSData *> *)dictionary
                                                   action:(SplitShortcutAction)action
{
  NSMutableArray<SplitShortcut *> *shortcuts = [NSMutableArray new];
  for (NSData *shortcutData in dictionary.allValues) {
    NSError *error = nil;
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:shortcutData error:&error];
    if (!unarchiver) {
      NSLog(@"Unable to read archived shortcut: %@", error);
      continue;
    }
    unarchiver.requiresSecureCoding = NO;
    SplitShortcut *shortcut = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
    [unarchiver finishDecoding];
    if (shortcut) {
      [shortcuts addObject:[shortcut copyWithShortcutAction:action]];
    }
  }
  return shortcuts;
}

@end
