#import "SplitShortcutManager.h"

#import <Carbon/Carbon.h>

#import "SplitShortcutHolder.h"
#import "SplitShortcut.h"
#import "SplitShortcutStorage.h"

static EventHotKeyID currentShortcutID = {
  .signature = 'ZERO',
  .id = 0
};

@implementation SplitShortcutManager
{
  id<SplitShortcutStorage> _shortcutStorage;
  NSMutableDictionary<NSString *, SplitShortcutHolder *> *_registeredShortcutsByName;
  NSMutableDictionary<NSString *, SplitShortcut *> *_shortcutsFailedToRegisterByName;
  BOOL _areShorcutsEnabled;
}

- (instancetype)initWithShortcutStorage:(id<SplitShortcutStorage>)shortcutStorage
{
  if (self = [super init]) {
    _shortcutStorage = shortcutStorage;
    _registeredShortcutsByName = [NSMutableDictionary new];
    _shortcutsFailedToRegisterByName = [NSMutableDictionary new];
    _areShorcutsEnabled = YES;
    [self installApplicationEventHandler];
  }
  return self;
}

- (void)manageShortcuts:(NSArray<SplitShortcut *> *)shortcuts
{
  for (SplitShortcut *shortcut in shortcuts) {
    NSString *shortcutName = shortcut.shortcutName;
    SplitShortcutHolder *shortcutHolder = _registeredShortcutsByName[shortcutName];
    if (shortcutHolder) {
      NSLog(@"Unable to add shortcut %@ as it already exists.", shortcutName);
      continue;
    }
    currentShortcutID.id = ++currentShortcutID.id;
    shortcutHolder = [[SplitShortcutHolder alloc] initWithShortcutID:currentShortcutID shortcut:shortcut];
    _registeredShortcutsByName[shortcutName] = _areShorcutsEnabled ? [self registerEventHotKey:shortcutHolder] : shortcutHolder;
  }
  [self storeShortcuts];
}

- (void)updateShortcut:(SplitShortcut *)shortcut
{
  NSString *shortcutName = shortcut.shortcutName;
  SplitShortcutHolder *shortcutHolder = _registeredShortcutsByName[shortcutName];
  if (!shortcutHolder) {
    NSLog(@"Unable to update shortcut %@ as it does not exists.", shortcutName);
    return;
  }
  if (_areShorcutsEnabled && [self unregisterEventHotKey:shortcutHolder]) {
    NSLog(@"Unable to unregister event hot key for shortcut: %@", shortcutName);
    return;
  }
  SplitShortcutHolder *registeredShortcutHolder = _areShorcutsEnabled ? [self registerEventHotKey:shortcutHolder] : shortcutHolder;
  _registeredShortcutsByName[shortcutName] = [registeredShortcutHolder
                                              copyWithShortcut:
                                              [shortcut
                                               copyWithShortcutAction:
                                               shortcut.shortcutAction ?: shortcutHolder.shortcut.shortcutAction]];
  [self storeShortcuts];
}

- (void)updateShortcuts:(NSArray<SplitShortcut *> *)shortcuts
{
  for (SplitShortcut *shortcut in shortcuts) {
    [self updateShortcut:shortcut];
  }
}

- (void)clearShortcut:(SplitShortcut *)shortcut
{
  NSString *shortcutName = shortcut.shortcutName;
  SplitShortcutHolder *shortcutHolder = _registeredShortcutsByName[shortcutName];
  if (!shortcutHolder) {
    NSLog(@"Unable to clear shortcut %@ as it does not exists.", shortcutName);
    return;
  }
  BOOL eventHotKeyUnregistered = NO;
  if (_areShorcutsEnabled) {
    eventHotKeyUnregistered = [self unregisterEventHotKey:shortcutHolder];
  }
  _registeredShortcutsByName[shortcutName] = [shortcutHolder copyWithClearedShortcut];
  [_shortcutsFailedToRegisterByName removeObjectForKey:shortcutName];
  if (_areShorcutsEnabled && !eventHotKeyUnregistered) {
    _registeredShortcutsByName[shortcutName] = shortcutHolder;
  }
  [self storeShortcuts];
}

- (NSArray<SplitShortcut *> *)shortcuts
{
  NSMutableArray<SplitShortcut *> *shortcuts = [NSMutableArray new];
  for (SplitShortcutHolder *shortcutHolder in _registeredShortcutsByName.allValues) {
    [shortcuts addObject:shortcutHolder.shortcut];
  }
  return shortcuts;
}

- (SplitShortcut *)shortcutForShortcutName:(NSString *)shortcutName
{
  SplitShortcutHolder *shortcutHolder = _registeredShortcutsByName[shortcutName];
  SplitShortcut *shortcut = shortcutHolder.shortcut;
  if (shortcut.isClearedShortcut) {
    return nil;
  }
  return shortcut;
}

- (BOOL)doesShortcutExist:(SplitShortcut *)shortcut
{
  for (SplitShortcutHolder *shortcutHolder in _registeredShortcutsByName.allValues) {
    if ([shortcutHolder.shortcut isEqualToShortcut:shortcut]) {
      return YES;
    }
  }
  return NO;
}

- (NSArray<SplitShortcut *> *)shortcutsFailedToRegister
{
  NSMutableArray<SplitShortcut *> *shortcuts = [NSMutableArray new];
  for (NSString *name in [_shortcutsFailedToRegisterByName.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
    [shortcuts addObject:_shortcutsFailedToRegisterByName[name]];
  }
  return shortcuts;
}

- (void)registerShortcuts
{
  if (_areShorcutsEnabled) {
    return;
  }
  for (SplitShortcutHolder *shortcutHolder in _registeredShortcutsByName.allValues) {
    _registeredShortcutsByName[shortcutHolder.shortcut.shortcutName] = [self registerEventHotKey:shortcutHolder];
  }
  _areShorcutsEnabled = YES;
}

- (void)unregisterShortcuts
{
  if (!_areShorcutsEnabled) {
    return;
  }
  for (SplitShortcutHolder *shortcutHolder in _registeredShortcutsByName.allValues) {
    [self unregisterEventHotKey:shortcutHolder];
  }
  _areShorcutsEnabled = NO;
}

- (void)installApplicationEventHandler
{
  EventTypeSpec typeSpec;
  typeSpec.eventClass = kEventClassKeyboard;
  typeSpec.eventKind = kEventHotKeyPressed;
  InstallApplicationEventHandler(&hotKeyEventHandler, 1, &typeSpec, (__bridge void*)self, NULL);
}

- (void)storeShortcuts
{
  [_shortcutStorage storeShortcuts:self.shortcuts];
}

- (SplitShortcut *)shortcutForShortcutID:(EventHotKeyID)shortcutID
{
  for (SplitShortcutHolder *shortcut in _registeredShortcutsByName.allValues) {
    if (shortcut.shortcutID.id == shortcutID.id) {
      return shortcut.shortcut;
    }
  }
  return nil;
}

- (SplitShortcutHolder *)registerEventHotKey:(SplitShortcutHolder *)shortcutHolder
{
  SplitShortcut *shortcut = shortcutHolder.shortcut;
  if (shortcut.isClearedShortcut) {
    return shortcutHolder;
  }
  EventHotKeyRef shortcutRef;
  OSStatus err;
  err = RegisterEventHotKey((unsigned int)shortcut.shortcutKeyCode,
                            (unsigned int)shortcut.shortcutModifiers,
                            shortcutHolder.shortcutID,
                            GetEventDispatcherTarget(),
                            kEventHotKeyNoOptions,
                            &shortcutRef);
  if (err) {
    NSLog(@"There was a problem registering shortcut %@.", shortcut.shortcutName);
    _shortcutsFailedToRegisterByName[shortcut.shortcutName] = shortcut;
    // Keep the keys rather than clearing them, so they are not saved as cleared and lost the
    // next time Split opens, when the other app may have let go of them.
    return [shortcutHolder copyWithShortcutRef:NULL];
  }
  [_shortcutsFailedToRegisterByName removeObjectForKey:shortcut.shortcutName];
  return [shortcutHolder copyWithShortcutRef:shortcutRef];
}

- (BOOL)unregisterEventHotKey:(SplitShortcutHolder *)shortcutHolder
{
  NSString *shortcutName = shortcutHolder.shortcut.shortcutName;
  EventHotKeyRef shortcutRef = shortcutHolder.shortcutRef;
  OSStatus err;
  if (shortcutRef) {
    err = UnregisterEventHotKey(shortcutRef);
    if (err) {
      NSLog(@"Received the following error code when unregistering shortcut %@: %d", shortcutName, err);
      return NO;
    }
  }
  return YES;
}

- (OSStatus)handleHotKeyEvent:(EventRef)event
{
  SplitShortcut *shortcut;
  EventHotKeyID shortcutID;
  OSStatus err = GetEventParameter(event,
                                   kEventParamDirectObject,
                                   typeEventHotKeyID,
                                   NULL,
                                   sizeof(EventHotKeyID),
                                   NULL,
                                   &shortcutID);
  if (err) {
    return err;
  }
  shortcut = [self shortcutForShortcutID:shortcutID];
  if (!shortcut) {
    NSLog(@"Unable to handle event for shortcut with handle %d, the registered shortcut does not exist.", shortcutID.id);
  }
  switch (GetEventKind(event)) {
    case kEventHotKeyPressed:
      [shortcut triggerShortcutAction];
      break;
    default:
      break;
  }
  return noErr;
}

OSStatus hotKeyEventHandler(EventHandlerCallRef handlerCall, EventRef event, void *shortcutManager)
{
  return [(__bridge SplitShortcutManager *)shortcutManager handleHotKeyEvent:event];
}

@end
