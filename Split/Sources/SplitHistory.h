#import <Foundation/Foundation.h>

@class SplitHistoryItem;

@interface SplitHistory : NSObject

- (void)addHistoryItem:(SplitHistoryItem *)historyItem;

- (SplitHistoryItem *)nextHistoryItem;
- (SplitHistoryItem *)previousHistoryItem;

- (BOOL)isEmpty;

@end
