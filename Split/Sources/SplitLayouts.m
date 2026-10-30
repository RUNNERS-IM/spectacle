#import "SplitLayouts.h"

#import "SplitAccessibilityElement.h"
#import "SplitWindowArranger.h"

SplitLayoutShape const SplitLayoutShapeHalves = @"Halves";
SplitLayoutShape const SplitLayoutShapeThirds = @"Thirds";
SplitLayoutShape const SplitLayoutShapeMainAndTwo = @"MainAndTwo";
SplitLayoutShape const SplitLayoutShapeGrid = @"Grid";
SplitLayoutShape const SplitLayoutShapeSingle = @"Single";

NSArray<SplitLayoutShape> *SplitLayoutShapes(void)
{
  return @[SplitLayoutShapeHalves, SplitLayoutShapeThirds, SplitLayoutShapeMainAndTwo, SplitLayoutShapeGrid, SplitLayoutShapeSingle];
}

static NSValue *ShapeCell(CGFloat x, CGFloat y, CGFloat width, CGFloat height)
{
  return [NSValue valueWithRect:NSMakeRect(x, y, width, height)];
}

NSArray<NSValue *> *SplitLayoutShapeFractions(SplitLayoutShape shape)
{
  if ([shape isEqualToString:SplitLayoutShapeHalves]) {
    return @[ShapeCell(0, 0, 0.5, 1), ShapeCell(0.5, 0, 0.5, 1)];
  }
  if ([shape isEqualToString:SplitLayoutShapeThirds]) {
    return @[ShapeCell(0, 0, 1.0 / 3, 1), ShapeCell(1.0 / 3, 0, 1.0 / 3, 1), ShapeCell(2.0 / 3, 0, 1.0 / 3, 1)];
  }
  if ([shape isEqualToString:SplitLayoutShapeMainAndTwo]) {
    return @[ShapeCell(0, 0, 0.6, 1), ShapeCell(0.6, 0, 0.4, 0.5), ShapeCell(0.6, 0.5, 0.4, 0.5)];
  }
  if ([shape isEqualToString:SplitLayoutShapeGrid]) {
    return @[ShapeCell(0, 0, 0.5, 0.5), ShapeCell(0.5, 0, 0.5, 0.5), ShapeCell(0, 0.5, 0.5, 0.5), ShapeCell(0.5, 0.5, 0.5, 0.5)];
  }
  return @[ShapeCell(0, 0, 1, 1)];
}

NSUInteger SplitApplyLayoutShape(SplitLayoutShape shape, NSScreen *screen, SplitWindowArranger *arranger)
{
  NSArray<NSValue *> *fractions = SplitLayoutShapeFractions(shape);
  NSArray<SplitArrangedWindow *> *windows = SplitVisibleWindows(screen);
  if (windows.count > fractions.count) {
    windows = [windows subarrayWithRange:NSMakeRange(0, fractions.count)];
  }
  CGRect frame = SplitTopLeftVisibleFrame(screen);
  CGFloat gap = SplitWindowGap();
  NSMutableArray<NSValue *> *rects = [NSMutableArray new];
  for (NSUInteger index = 0; index < windows.count; index++) {
    NSRect fraction = fractions[index].rectValue;
    CGRect rect = CGRectMake(CGRectGetMinX(frame) + fraction.origin.x * CGRectGetWidth(frame),
                             CGRectGetMinY(frame) + fraction.origin.y * CGRectGetHeight(frame),
                             fraction.size.width * CGRectGetWidth(frame),
                             fraction.size.height * CGRectGetHeight(frame));
    [rects addObject:[NSValue valueWithRect:NSRectFromCGRect(SplitRectWithGap(CGRectIntegral(rect), frame, gap))]];
  }
  [arranger moveWindows:windows toRects:rects];
  return windows.count;
}

#pragma mark - Saved layouts

@implementation SplitSavedWindow
@end

@implementation SplitSavedLayout
@end

static NSString *BundleIdentifierOfProcess(pid_t pid)
{
  return [NSRunningApplication runningApplicationWithProcessIdentifier:pid].bundleIdentifier ?: @"";
}

static NSString *TitleOfWindow(SplitArrangedWindow *window)
{
  return [window.element stringValueOfAttribute:kAXTitleAttribute] ?: @"";
}

static NSDictionary *DictionaryFromLayout(SplitSavedLayout *layout)
{
  NSMutableArray *windows = [NSMutableArray new];
  for (SplitSavedWindow *window in layout.windows) {
    [windows addObject:@{
      @"bundle": window.bundleIdentifier,
      @"title": window.title,
      @"index": @(window.indexInApp),
      @"rect": @[@(window.rect.origin.x), @(window.rect.origin.y), @(window.rect.size.width), @(window.rect.size.height)],
      @"display": window.displayID,
    }];
  }
  return @{
    @"id": layout.identifier,
    @"name": layout.name,
    @"displays": layout.displayIDs,
    @"restoresForDisplays": @(layout.restoresForDisplays),
    @"windows": windows,
  };
}

static SplitSavedLayout *LayoutFromDictionary(NSDictionary *dictionary)
{
  if (![dictionary isKindOfClass:NSDictionary.class] || ![dictionary[@"name"] isKindOfClass:NSString.class]) {
    return nil;
  }
  SplitSavedLayout *layout = [SplitSavedLayout new];
  layout.identifier = dictionary[@"id"] ?: NSUUID.UUID.UUIDString;
  layout.name = dictionary[@"name"];
  layout.displayIDs = [dictionary[@"displays"] isKindOfClass:NSArray.class] ? dictionary[@"displays"] : @[];
  layout.restoresForDisplays = [dictionary[@"restoresForDisplays"] boolValue];
  NSMutableArray *windows = [NSMutableArray new];
  for (NSDictionary *item in dictionary[@"windows"]) {
    NSArray<NSNumber *> *rect = item[@"rect"];
    if (![item isKindOfClass:NSDictionary.class] || ![rect isKindOfClass:NSArray.class] || rect.count != 4) {
      continue;
    }
    SplitSavedWindow *window = [SplitSavedWindow new];
    window.bundleIdentifier = item[@"bundle"] ?: @"";
    window.title = item[@"title"] ?: @"";
    window.indexInApp = [item[@"index"] unsignedIntegerValue];
    window.rect = CGRectMake(rect[0].doubleValue, rect[1].doubleValue, rect[2].doubleValue, rect[3].doubleValue);
    window.displayID = item[@"display"] ?: @"";
    [windows addObject:window];
  }
  layout.windows = windows;
  return layout;
}

@implementation SplitLayoutStore
{
  NSMutableArray<SplitSavedLayout *> *_layouts;
}

+ (SplitLayoutStore *)sharedStore
{
  static SplitLayoutStore *store;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    store = [SplitLayoutStore new];
  });
  return store;
}

static NSURL *LayoutsFileURL(void)
{
  NSURL *support = [NSFileManager.defaultManager URLForDirectory:NSApplicationSupportDirectory
                                                        inDomain:NSUserDomainMask
                                               appropriateForURL:nil
                                                          create:YES
                                                           error:NULL];
  NSURL *directory = [support URLByAppendingPathComponent:@"Split" isDirectory:YES];
  [NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:NULL];
  return [directory URLByAppendingPathComponent:@"Layouts.json"];
}

- (instancetype)init
{
  if (self = [super init]) {
    _layouts = [NSMutableArray new];
    NSData *data = [NSData dataWithContentsOfURL:LayoutsFileURL()];
    NSArray *items = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    if ([items isKindOfClass:NSArray.class]) {
      for (NSDictionary *item in items) {
        SplitSavedLayout *layout = LayoutFromDictionary(item);
        if (layout) {
          [_layouts addObject:layout];
        }
      }
    }
  }
  return self;
}

- (NSArray<SplitSavedLayout *> *)layouts
{
  return [_layouts copy];
}

- (void)write
{
  NSMutableArray *items = [NSMutableArray new];
  for (SplitSavedLayout *layout in _layouts) {
    [items addObject:DictionaryFromLayout(layout)];
  }
  NSData *data = [NSJSONSerialization dataWithJSONObject:items options:NSJSONWritingPrettyPrinted error:NULL];
  [data writeToURL:LayoutsFileURL() atomically:YES];
}

- (SplitSavedLayout *)saveCurrentLayoutNamed:(NSString *)name restoresForDisplays:(BOOL)restoresForDisplays
{
  NSMutableArray<SplitSavedWindow *> *saved = [NSMutableArray new];
  NSMutableDictionary<NSString *, NSNumber *> *countByApp = [NSMutableDictionary new];
  for (SplitArrangedWindow *window in SplitVisibleWindows(nil)) {
    NSScreen *screen = SplitScreenContainingPoint(CGPointMake(CGRectGetMidX(window.originalRect), CGRectGetMidY(window.originalRect)));
    if (!screen) {
      continue;
    }
    SplitSavedWindow *item = [SplitSavedWindow new];
    item.bundleIdentifier = BundleIdentifierOfProcess(window.pid);
    item.title = TitleOfWindow(window);
    item.indexInApp = countByApp[item.bundleIdentifier].unsignedIntegerValue;
    countByApp[item.bundleIdentifier] = @(item.indexInApp + 1);
    item.rect = window.originalRect;
    item.displayID = SplitDisplayIDOfScreen(screen);
    [saved addObject:item];
  }
  SplitSavedLayout *layout = [SplitSavedLayout new];
  layout.identifier = NSUUID.UUID.UUIDString;
  layout.name = name;
  layout.displayIDs = [SplitCurrentDisplayIDs().allObjects sortedArrayUsingSelector:@selector(compare:)];
  layout.restoresForDisplays = restoresForDisplays;
  layout.windows = saved;
  if (restoresForDisplays) {
    for (SplitSavedLayout *other in _layouts) {
      if ([[NSSet setWithArray:other.displayIDs] isEqualToSet:[NSSet setWithArray:layout.displayIDs]]) {
        other.restoresForDisplays = NO;
      }
    }
  }
  [_layouts addObject:layout];
  [self write];
  return layout;
}

- (void)removeLayout:(SplitSavedLayout *)layout
{
  [_layouts removeObject:layout];
  [self write];
}

- (SplitSavedLayout *)layoutRestoringForDisplays:(NSSet<NSString *> *)displayIDs
{
  for (SplitSavedLayout *layout in _layouts) {
    if (layout.restoresForDisplays && [[NSSet setWithArray:layout.displayIDs] isEqualToSet:displayIDs]) {
      return layout;
    }
  }
  return nil;
}

@end

NSUInteger SplitRestoreLayout(SplitSavedLayout *layout, SplitWindowArranger *arranger)
{
  NSSet<NSString *> *connected = SplitCurrentDisplayIDs();
  NSArray<SplitArrangedWindow *> *windows = SplitVisibleWindows(nil);
  NSMutableArray<NSString *> *bundles = [NSMutableArray new];
  NSMutableArray<NSString *> *titles = [NSMutableArray new];
  NSMutableArray<NSNumber *> *indexes = [NSMutableArray new];
  NSMutableDictionary<NSString *, NSNumber *> *countByApp = [NSMutableDictionary new];
  for (SplitArrangedWindow *window in windows) {
    NSString *bundle = BundleIdentifierOfProcess(window.pid);
    [bundles addObject:bundle];
    [titles addObject:TitleOfWindow(window)];
    [indexes addObject:countByApp[bundle] ?: @0];
    countByApp[bundle] = @(countByApp[bundle].unsignedIntegerValue + 1);
  }
  NSMutableIndexSet *used = [NSMutableIndexSet new];
  NSMutableIndexSet *placed = [NSMutableIndexSet new];
  NSMutableArray<SplitArrangedWindow *> *moved = [NSMutableArray new];
  NSMutableArray<NSValue *> *rects = [NSMutableArray new];
  // Two passes: same app and same title first, then same app and same place in its order.
  for (NSUInteger pass = 0; pass < 2; pass++) {
    for (NSUInteger savedIndex = 0; savedIndex < layout.windows.count; savedIndex++) {
      SplitSavedWindow *saved = layout.windows[savedIndex];
      if ([placed containsIndex:savedIndex] || ![connected containsObject:saved.displayID]) {
        continue;
      }
      for (NSUInteger index = 0; index < windows.count; index++) {
        if ([used containsIndex:index] || ![bundles[index] isEqualToString:saved.bundleIdentifier]) {
          continue;
        }
        BOOL matches = pass == 0 ? (saved.title.length > 0 && [titles[index] isEqualToString:saved.title])
                                 : indexes[index].unsignedIntegerValue == saved.indexInApp;
        if (matches) {
          [used addIndex:index];
          [placed addIndex:savedIndex];
          [moved addObject:windows[index]];
          [rects addObject:[NSValue valueWithRect:NSRectFromCGRect(saved.rect)]];
          break;
        }
      }
    }
  }
  [arranger moveWindows:moved toRects:rects];
  return moved.count;
}
