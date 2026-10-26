#import "SpectacleLegacyPreferencesMigrator.h"

#import <AppKit/AppKit.h>

NSString *const kSpectacleLegacyBundleIdentifier = @"com.divisiblebyzero.Spectacle";

static NSString *const kMigrationDoneKey = @"LegacyPreferencesMigrated";

@implementation SpectacleLegacyPreferencesMigrator

+ (BOOL)migrateIfNeeded
{
  NSString *currentIdentifier = NSBundle.mainBundle.bundleIdentifier;
  if (!currentIdentifier || [currentIdentifier isEqualToString:kSpectacleLegacyBundleIdentifier]) {
    return NO;
  }
  return [self migrateFromDomain:kSpectacleLegacyBundleIdentifier
                      toDefaults:NSUserDefaults.standardUserDefaults
                   currentDomain:currentIdentifier];
}

+ (BOOL)migrateFromDomain:(NSString *)legacyDomain
               toDefaults:(NSUserDefaults *)defaults
            currentDomain:(NSString *)currentDomain
{
  if ([defaults boolForKey:kMigrationDoneKey]) {
    return NO;
  }
  [defaults setBool:YES forKey:kMigrationDoneKey];

  NSDictionary<NSString *, id> *legacyValues = [self persistentValuesInDomain:legacyDomain];
  NSDictionary<NSString *, id> *currentValues = [defaults persistentDomainForName:currentDomain] ?: @{};
  __block BOOL copied = NO;
  [legacyValues enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
    // Sparkle keeps its own state (last check time, feed) that must not follow the new app,
    // and anything already set in the new app wins.
    if ([key hasPrefix:@"SU"] || [key isEqualToString:kMigrationDoneKey] || currentValues[key] != nil) {
      return;
    }
    [defaults setObject:value forKey:key];
    copied = YES;
  }];

  // Spectacle turns its shortcuts off while it is itself frontmost; keep that for the new identifier.
  NSArray<NSString *> *blacklisted = legacyValues[@"BlacklistedApplications"];
  if (copied && [blacklisted isKindOfClass:NSArray.class] && ![blacklisted containsObject:currentDomain]) {
    [defaults setObject:[blacklisted arrayByAddingObject:currentDomain] forKey:@"BlacklistedApplications"];
  }
  return copied;
}

+ (NSDictionary<NSString *, id> *)persistentValuesInDomain:(NSString *)domain
{
  CFArrayRef keys = CFPreferencesCopyKeyList((__bridge CFStringRef)domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
  if (!keys) {
    return @{};
  }
  CFDictionaryRef values = CFPreferencesCopyMultiple(keys, (__bridge CFStringRef)domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
  CFRelease(keys);
  return values ? (NSDictionary *)CFBridgingRelease(values) : @{};
}

+ (NSArray<NSRunningApplication *> *)runningLegacyApplications
{
  return [NSRunningApplication runningApplicationsWithBundleIdentifier:kSpectacleLegacyBundleIdentifier];
}

@end
