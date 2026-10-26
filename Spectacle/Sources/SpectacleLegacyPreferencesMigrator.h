#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kSpectacleLegacyBundleIdentifier;

/// The RUNNERS-IM fork ships as im.runners.Spectacle. The original app stored its preferences
/// under com.divisiblebyzero.Spectacle; this copies them over once so that the status item,
/// login item and per-application settings carry over. Shortcuts live in
/// ~/Library/Application Support/Spectacle and need no migration.
@interface SpectacleLegacyPreferencesMigrator : NSObject

/// Copies the legacy preferences into the standard user defaults once.
/// Returns YES when something was copied.
+ (BOOL)migrateIfNeeded;

/// Testable core: copies persistent values from `legacyDomain` into `defaults`, whose own
/// persistent domain is `currentDomain`.
+ (BOOL)migrateFromDomain:(NSString *)legacyDomain
               toDefaults:(NSUserDefaults *)defaults
            currentDomain:(NSString *)currentDomain;

/// Running copies of the original app, which would register the same shortcuts.
+ (NSArray<NSRunningApplication *> *)runningLegacyApplications;

@end

NS_ASSUME_NONNULL_END
