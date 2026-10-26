#import <Foundation/Foundation.h>

#import "SplitShortcutStorage.h"

@protocol SplitShortcutStorageMigrationDestination <SplitShortcutStorage>

@property (nonatomic, readonly, assign, getter=isMigrationNeeded) BOOL migrationNeeded;

@end
