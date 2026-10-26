#import <Expecta/Expecta.h>
#import <Specta/Specta.h>

#import "SplitLegacyPreferencesMigrator.h"

SpecBegin(SplitLegacyPreferencesMigrator)
describe(@"SplitLegacyPreferencesMigrator", ^{
  NSString *legacyDomain = @"im.runners.SplitSpecs.legacy";
  NSString *currentDomain = @"im.runners.SplitSpecs.current";
  __block NSUserDefaults *legacy;
  __block NSUserDefaults *current;

  beforeEach(^{
    [NSUserDefaults.standardUserDefaults removePersistentDomainForName:legacyDomain];
    [NSUserDefaults.standardUserDefaults removePersistentDomainForName:currentDomain];
    legacy = [[NSUserDefaults alloc] initWithSuiteName:legacyDomain];
    current = [[NSUserDefaults alloc] initWithSuiteName:currentDomain];
    [legacy setBool:NO forKey:@"StatusItemEnabled"];
    [legacy setObject:@[@"com.example.App"] forKey:@"DisabledApplications"];
    [legacy setObject:@[@"com.adobe.Photoshop", @"com.divisiblebyzero.Spectacle"] forKey:@"BlacklistedApplications"];
    [legacy setObject:[NSDate date] forKey:@"SULastCheckTime"];
    [legacy synchronize];
  });

  afterEach(^{
    [NSUserDefaults.standardUserDefaults removePersistentDomainForName:legacyDomain];
    [NSUserDefaults.standardUserDefaults removePersistentDomainForName:currentDomain];
  });

  it(@"should copy legacy preferences except Sparkle state", ^{
    BOOL copied = [SplitLegacyPreferencesMigrator migrateFromDomain:legacyDomain toDefaults:current currentDomain:currentDomain];
    expect(copied).to.beTruthy();
    expect([current objectForKey:@"StatusItemEnabled"]).to.equal(@NO);
    expect([current objectForKey:@"DisabledApplications"]).to.equal(@[@"com.example.App"]);
    expect([current objectForKey:@"SULastCheckTime"]).to.beNil();
    expect([current objectForKey:@"BlacklistedApplications"]).to.contain(currentDomain);
  });

  it(@"should not overwrite values already set in the new app", ^{
    [current setBool:YES forKey:@"StatusItemEnabled"];
    [SplitLegacyPreferencesMigrator migrateFromDomain:legacyDomain toDefaults:current currentDomain:currentDomain];
    expect([current boolForKey:@"StatusItemEnabled"]).to.beTruthy();
  });

  it(@"should only migrate once", ^{
    [SplitLegacyPreferencesMigrator migrateFromDomain:legacyDomain toDefaults:current currentDomain:currentDomain];
    [current removeObjectForKey:@"DisabledApplications"];
    BOOL copiedAgain = [SplitLegacyPreferencesMigrator migrateFromDomain:legacyDomain toDefaults:current currentDomain:currentDomain];
    expect(copiedAgain).to.beFalsy();
    // The test host registers app defaults, so look at the stored values only.
    expect([current persistentDomainForName:currentDomain][@"DisabledApplications"]).to.beNil();
  });
});
SpecEnd
