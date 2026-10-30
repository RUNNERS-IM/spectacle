// macOS: monitors from NSScreen, windows through the Accessibility API (needs the Accessibility
// permission). Only public API, so the same code can go to the Mac App Store.
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>

#include <cmath>
#include <vector>

#include "platform.h"

namespace split {
namespace {

constexpr double kMinimumWindowSide = 80;
constexpr double kSameWindowTolerance = 2;
// Why: a window id must stay the same between the shortcut that moves it and a later undo,
// but the Accessibility API has no public window number, so the elements themselves are kept.
constexpr NSTimeInterval kForgetAfter = 60 * 60;

struct Known {
  uint64_t id;
  AXUIElementRef element;
  NSTimeInterval lastSeen;
};

std::vector<Known> known;
uint64_t nextId = 1;

uint64_t IdFor(AXUIElementRef element) {
  NSTimeInterval now = NSDate.timeIntervalSinceReferenceDate;
  for (auto &k : known) {
    if (CFEqual(k.element, element)) {
      k.lastSeen = now;
      return k.id;
    }
  }
  for (auto it = known.begin(); it != known.end();) {
    if (now - it->lastSeen > kForgetAfter) {
      CFRelease(it->element);
      it = known.erase(it);
    } else {
      ++it;
    }
  }
  CFRetain(element);
  known.push_back({nextId, element, now});
  return nextId++;
}

AXUIElementRef ElementFor(uint64_t id) {
  for (auto &k : known) {
    if (k.id == id) return k.element;
  }
  return nullptr;
}

double PrimaryHeight() { return NSScreen.screens.firstObject.frame.size.height; }

Rect TopLeft(NSRect r) { return {r.origin.x, PrimaryHeight() - NSMaxY(r), r.size.width, r.size.height}; }

bool Contains(const Rect &r, double x, double y) {
  return x >= r.x && x < r.x + r.width && y >= r.y && y < r.y + r.height;
}

bool RectOf(AXUIElementRef element, Rect &out) {
  CFTypeRef position = nullptr, size = nullptr;
  bool ok = AXUIElementCopyAttributeValue(element, kAXPositionAttribute, &position) == kAXErrorSuccess &&
            AXUIElementCopyAttributeValue(element, kAXSizeAttribute, &size) == kAXErrorSuccess;
  CGPoint p{};
  CGSize s{};
  ok = ok && AXValueGetValue((AXValueRef)position, (AXValueType)kAXValueCGPointType, &p) &&
       AXValueGetValue((AXValueRef)size, (AXValueType)kAXValueCGSizeType, &s);
  if (position) CFRelease(position);
  if (size) CFRelease(size);
  if (ok) out = {p.x, p.y, s.width, s.height};
  return ok;
}

AXError SetRect(AXUIElementRef element, const Rect &r) {
  CGPoint p = CGPointMake(r.x, r.y);
  CGSize s = CGSizeMake(r.width, r.height);
  AXValueRef position = AXValueCreate((AXValueType)kAXValueCGPointType, &p);
  AXValueRef size = AXValueCreate((AXValueType)kAXValueCGSizeType, &s);
  AXError sizeError = AXUIElementSetAttributeValue(element, kAXSizeAttribute, size);
  AXError positionError = AXUIElementSetAttributeValue(element, kAXPositionAttribute, position);
  CFRelease(position);
  CFRelease(size);
  return positionError != kAXErrorSuccess ? positionError : sizeError;
}

id Attribute(AXUIElementRef element, CFStringRef attribute) {
  CFTypeRef value = nullptr;
  if (AXUIElementCopyAttributeValue(element, attribute, &value) != kAXErrorSuccess || !value) return nil;
  return CFBridgingRelease(value);
}

std::vector<Screen> Screens() {
  std::vector<Screen> result;
  NSArray<NSScreen *> *screens = NSScreen.screens;
  for (NSUInteger i = 0; i < screens.count; i++) {
    result.push_back({TopLeft(screens[i].frame), TopLeft(screens[i].visibleFrame), screens[i].backingScaleFactor, i == 0});
  }
  return result;
}

/// Ordinary windows of one app, front to back: not minimized and not in full screen.
std::vector<AXUIElementRef> StandardWindowsOf(pid_t pid) {
  std::vector<AXUIElementRef> result;
  AXUIElementRef application = AXUIElementCreateApplication(pid);
  CFArrayRef windows = nullptr;
  if (AXUIElementCopyAttributeValues(application, kAXWindowsAttribute, 0, 100, &windows) == kAXErrorSuccess && windows) {
    for (CFIndex i = 0; i < CFArrayGetCount(windows); i++) {
      auto window = (AXUIElementRef)CFArrayGetValueAtIndex(windows, i);
      if (![Attribute(window, kAXSubroleAttribute) isEqual:(__bridge NSString *)kAXStandardWindowSubrole]) continue;
      if ([Attribute(window, kAXMinimizedAttribute) boolValue] || [Attribute(window, CFSTR("AXFullScreen")) boolValue]) continue;
      CFRetain(window);
      result.push_back(window);
    }
    CFRelease(windows);
  }
  CFRelease(application);
  return result;
}

/// The window server lists windows in the order they were last used; the Accessibility window
/// that sits exactly at a listed frame is taken as that window, since only public API is used.
std::vector<Window> VisibleWindows(const std::vector<Screen> &screens) {
  std::vector<Window> result;
  pid_t ownPid = NSProcessInfo.processInfo.processIdentifier;
  NSArray<NSDictionary *> *infos = CFBridgingRelease(
      CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID));
  NSMutableDictionary<NSNumber *, NSValue *> *byPid = [NSMutableDictionary new];
  std::vector<std::vector<AXUIElementRef>> pools;
  for (NSDictionary *info in infos) {
    if ([info[(id)kCGWindowLayer] integerValue] != 0 || [info[(id)kCGWindowAlpha] doubleValue] <= 0) continue;
    pid_t pid = [info[(id)kCGWindowOwnerPID] intValue];
    if (pid == ownPid) continue;
    CGRect bounds = CGRectNull;
    if (!CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)info[(id)kCGWindowBounds], &bounds)) continue;
    if (bounds.size.width < kMinimumWindowSide || bounds.size.height < kMinimumWindowSide) continue;
    bool onScreen = false;
    for (const auto &s : screens) onScreen = onScreen || Contains(s.frame, CGRectGetMidX(bounds), CGRectGetMidY(bounds));
    if (!onScreen) continue;
    NSValue *index = byPid[@(pid)];
    if (!index) {
      pools.push_back(StandardWindowsOf(pid));
      index = [NSValue valueWithPointer:(void *)(pools.size() - 1)];
      byPid[@(pid)] = index;
    }
    auto &pool = pools[(size_t)index.pointerValue];
    for (auto it = pool.begin(); it != pool.end(); ++it) {
      Rect r;
      if (RectOf(*it, r) && std::fabs(r.x - bounds.origin.x) <= kSameWindowTolerance &&
          std::fabs(r.y - bounds.origin.y) <= kSameWindowTolerance &&
          std::fabs(r.width - bounds.size.width) <= kSameWindowTolerance &&
          std::fabs(r.height - bounds.size.height) <= kSameWindowTolerance) {
        NSString *name = [NSRunningApplication runningApplicationWithProcessIdentifier:pid].localizedName ?: @"";
        result.push_back({IdFor(*it), r, name.UTF8String});
        CFRelease(*it);
        pool.erase(it);
        break;
      }
    }
  }
  for (auto &pool : pools) {
    for (auto element : pool) CFRelease(element);
  }
  return result;
}

std::string refusingApp;

AppInfo InfoOf(NSRunningApplication *application) {
  return {application.bundleIdentifier.UTF8String ?: "", application.localizedName.UTF8String ?: ""};
}

int FlagsOf(NSEventModifierFlags modifiers) {
  return ((modifiers & NSEventModifierFlagControl) ? 1 : 0) | ((modifiers & NSEventModifierFlagOption) ? 2 : 0) |
         ((modifiers & NSEventModifierFlagShift) ? 4 : 0) | ((modifiers & NSEventModifierFlagCommand) ? 8 : 0);
}

EventSink sink;
id globalMonitor;
id localMonitor;
id activationObserver;

}  // namespace

std::optional<AppInfo> FrontmostApp() {
  NSRunningApplication *front = NSWorkspace.sharedWorkspace.frontmostApplication;
  if (!front) return std::nullopt;
  return InfoOf(front);
}

void StartWatching(EventSink newSink) {
  sink = std::move(newSink);
  if (activationObserver) return;
  auto modifiers = ^(NSEvent *event) {
    if (sink) sink(Event{Event::Modifiers, FlagsOf(event.modifierFlags), {}});
  };
  // Why: the global monitor only hears keys meant for other apps; the local one covers Split's own windows.
  globalMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskFlagsChanged handler:modifiers];
  localMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskFlagsChanged
                                                       handler:^NSEvent *(NSEvent *event) {
                                                         modifiers(event);
                                                         return event;
                                                       }];
  activationObserver = [NSWorkspace.sharedWorkspace.notificationCenter
      addObserverForName:NSWorkspaceDidActivateApplicationNotification
                  object:nil
                   queue:NSOperationQueue.mainQueue
              usingBlock:^(NSNotification *note) {
                NSRunningApplication *application = note.userInfo[NSWorkspaceApplicationKey];
                if (sink && application) sink(Event{Event::Activated, 0, InfoOf(application)});
              }];
}

bool IsTrusted(bool prompt) {
  NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt : @(prompt)};
  return AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
}

std::string TakeSnapshot(bool withWindows, Snapshot &out) {
  @autoreleasepool {
    out.screens = Screens();
    NSRunningApplication *front = NSWorkspace.sharedWorkspace.frontmostApplication;
    if (front) {
      std::string name = front.localizedName.UTF8String ?: "";
      AXUIElementRef application = AXUIElementCreateApplication(front.processIdentifier);
      CFTypeRef window = nullptr;
      AXError error = AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute, &window);
      CFRelease(application);
      // Why: an app started before the permission was given can keep refusing until it restarts.
      if (error == kAXErrorAPIDisabled && AXIsProcessTrusted()) {
        refusingApp = name;
      } else if (window && refusingApp == name) {
        refusingApp.clear();
      }
      Rect rect;
      if (window && RectOf((AXUIElementRef)window, rect)) {
        out.active = Window{IdFor((AXUIElementRef)window), rect, name};
      }
      if (window) CFRelease(window);
    }
    out.refusingApp = refusingApp;
    if (withWindows) out.windows = VisibleWindows(out.screens);
    return "";
  }
}

std::string Apply(const std::vector<Move> &moves) {
  @autoreleasepool {
    auto screens = Screens();
    for (const auto &move : moves) {
      AXUIElementRef element = ElementFor(move.id);
      if (!element) return "unknown window";
      Rect target = move.rect;
      AXError error = SetRect(element, target);
      if (error != kAXErrorSuccess) return "could not move window (" + std::to_string(error) + ")";
      // Why: terminals and similar apps only take sizes in whole character cells, so they end up
      // larger than asked. Shrink a little at a time and centre what is left, as Spectacle did.
      Rect moved;
      if (RectOf(element, moved) && (moved.width > target.width || moved.height > target.height)) {
        Rect adjusted = target;
        while (moved.width > target.width || moved.height > target.height) {
          if (moved.width > target.width) adjusted.width -= 2;
          if (moved.height > target.height) adjusted.height -= 2;
          if (adjusted.width < target.width * 0.85 || adjusted.height < target.height * 0.85) break;
          SetRect(element, adjusted);
          if (!RectOf(element, moved)) break;
        }
        adjusted.x += std::floor((target.width - moved.width) / 2);
        adjusted.y += std::floor((target.height - moved.height) / 2);
        SetRect(element, adjusted);
      }
      // Why: some apps keep a minimum size, so the window may stick out of the screen; pull it back in.
      const Screen *screen = nullptr;
      for (const auto &s : screens) {
        if (Contains(s.frame, target.x + target.width / 2, target.y + target.height / 2)) screen = &s;
      }
      if (screen && RectOf(element, moved)) {
        Rect visible = screen->workArea, fixed = moved;
        if (fixed.x < visible.x) fixed.x = visible.x;
        else if (fixed.x + fixed.width > visible.x + visible.width) fixed.x = visible.x + visible.width - fixed.width;
        if (fixed.y < visible.y) fixed.y = visible.y;
        else if (fixed.y + fixed.height > visible.y + visible.height) fixed.y = visible.y + visible.height - fixed.height;
        if (fixed.x != moved.x || fixed.y != moved.y) SetRect(element, fixed);
      }
    }
    return "";
  }
}

}  // namespace split
