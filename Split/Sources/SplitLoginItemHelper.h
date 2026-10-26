#import <Foundation/Foundation.h>

@interface SplitLoginItemHelper : NSObject

+ (BOOL)isLoginItemEnabledForBundle:(NSBundle *)bundle;

+ (void)enableLoginItemForBundle:(NSBundle *)bundle;
+ (void)disableLoginItemForBundle:(NSBundle *)bundle;

@end
