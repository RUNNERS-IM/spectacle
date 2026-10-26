#import "SplitHistory.h"

#import "SplitHistoryItem.h"

@implementation SplitHistory
{
  SplitHistoryItem *_lastHistoryItem;
  SplitHistoryItem *_currentHistoryItem;
  NSInteger _size;
}

- (void)addHistoryItem:(SplitHistoryItem *)historyItem
{
  if ([self isEmpty]) {
    _currentHistoryItem = historyItem;
    _lastHistoryItem = _currentHistoryItem;
  } else {
    historyItem.previousHistoryItem = _currentHistoryItem;
    _currentHistoryItem.nextHistoryItem.previousHistoryItem = historyItem;
    _currentHistoryItem.nextHistoryItem = historyItem;
    if (![historyItem previousHistoryItem]) {
      _lastHistoryItem = historyItem;
    }
    _currentHistoryItem = historyItem;
  }
  if (++_size > 50) {
    _lastHistoryItem.nextHistoryItem.previousHistoryItem = nil;
    _lastHistoryItem = _lastHistoryItem.nextHistoryItem;
    _size--;
  }
}

- (SplitHistoryItem *)nextHistoryItem
{
  SplitHistoryItem *historyItem = _currentHistoryItem.nextHistoryItem;
  if (historyItem) {
    _currentHistoryItem = historyItem;
    _size++;
  }
  return historyItem;
}

- (SplitHistoryItem *)previousHistoryItem
{
  SplitHistoryItem *historyItem = _currentHistoryItem.previousHistoryItem;
  if (historyItem) {
    _currentHistoryItem = historyItem;
    _size--;
  }
  return historyItem;
}

- (BOOL)isEmpty
{
  return _size == 0;
}

@end
