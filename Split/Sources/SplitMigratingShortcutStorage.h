#import <Foundation/Foundation.h>

#import "SplitMacros.h"
#import "SplitShortcutStorage.h"

@protocol SplitShortcutStorageMigrationDestination;

@interface SplitMigratingShortcutStorage : NSObject <SplitShortcutStorage>

- (instancetype)initWithShortcutStorage:(id<SplitShortcutStorage>)shortcutStorage
                   migrationDestination:(id<SplitShortcutStorageMigrationDestination>)migrationDestination NS_DESIGNATED_INITIALIZER;

SPECTACLE_INIT_AND_NEW_UNAVAILABLE

@end
