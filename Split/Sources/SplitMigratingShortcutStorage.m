#import "SplitMigratingShortcutStorage.h"

#import "SplitShortcutStorageMigrationDestination.h"

@implementation SplitMigratingShortcutStorage
{
  id<SplitShortcutStorage> _shortcutStorage;
  id<SplitShortcutStorageMigrationDestination> _migrationDestination;
}

- (instancetype)initWithShortcutStorage:(id<SplitShortcutStorage>)shortcutStorage
                   migrationDestination:(id<SplitShortcutStorageMigrationDestination>)migrationDestination
{
  if (self = [super init]) {
    _shortcutStorage = shortcutStorage;
    _migrationDestination = migrationDestination;
  }
  return self;
}

- (NSArray<SplitShortcut *> *)loadShortcutsWithAction:(SplitShortcutAction)action
{
  return _migrationDestination.isMigrationNeeded ? [_shortcutStorage loadShortcutsWithAction:action] : [_migrationDestination loadShortcutsWithAction:action];
}

- (void)storeShortcuts:(NSArray<SplitShortcut *> *)shortcuts
{
  [_migrationDestination storeShortcuts:shortcuts];
}

@end
