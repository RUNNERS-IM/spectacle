#import "SplitUtilities.h"

NSString *SplitLocalized(NSString *key)
{
  return [NSBundle.mainBundle localizedStringForKey:key value:nil table:@"App"];
}

@implementation SplitUtilities

+ (NSString *)applicationVersion
{
  NSBundle *mainBundle = NSBundle.mainBundle;
  NSString *bundleVersion = mainBundle.infoDictionary[@"CFBundleShortVersionString"];
  if (!bundleVersion) {
    bundleVersion = mainBundle.infoDictionary[@"CFBundleVersion"];
  }
  return bundleVersion;
}

+ (void)registerDefaultsForBundle:(NSBundle *)bundle
{
  NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
  NSString *path = [bundle pathForResource:@"Defaults" ofType:@"plist"];
  [defaults registerDefaults:[[NSDictionary alloc] initWithContentsOfFile:path]];
}

+ (void)displayRunningInBackgroundAlertWithCallback:(void (^)(BOOL, BOOL))callback
{
  NSAlert *alert = [NSAlert new];
  alert.alertStyle = NSAlertStyleInformational;
  alert.showsSuppressionButton = YES;
  alert.messageText = SplitLocalized(@"AlertMessageTextRunningInBackground");
  alert.informativeText = SplitLocalized(@"AlertInformativeTextRunningInBackground");
  [alert addButtonWithTitle:SplitLocalized(@"ButtonLabelAffirmative")];
  [alert addButtonWithTitle:SplitLocalized(@"ButtonLabelNegative")];
  NSInteger response = [alert runModal];
  BOOL isAlertSuppressed = [alert.suppressionButton state] == NSControlStateValueOn;
  switch (response) {
    case NSAlertFirstButtonReturn:
      callback(YES, isAlertSuppressed);
      break;
    case NSAlertSecondButtonReturn:
      callback(NO, isAlertSuppressed);
      break;
    default:
      break;
  }
}

+ (void)displayRestoreDefaultsAlertWithConfirmationCallback:(void (^)(void))callback
{
  NSAlert *alert = [NSAlert new];
  alert.messageText = SplitLocalized(@"AlertMessageTextRestoreDefaults");
  alert.informativeText = SplitLocalized(@"AlertInformativeTextRestoreDefaults");
  [alert addButtonWithTitle:SplitLocalized(@"ButtonLabelAffirmative")];
  [alert addButtonWithTitle:SplitLocalized(@"ButtonLabelNegative")];
  NSInteger response = [alert runModal];
  switch (response) {
    case NSAlertFirstButtonReturn:
      callback();
      break;
    case NSAlertSecondButtonReturn:
      break;
    default:
      break;
  }
}


@end
