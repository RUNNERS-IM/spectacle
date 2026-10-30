// What each operating system gives Split: where the monitors and windows are, and moving windows.
// The math, history and arrange live in TypeScript (app/src/core); this is only the OS part.
#pragma once

#include <cstdint>
#include <functional>
#include <optional>
#include <string>
#include <vector>

namespace split {

struct Rect {
  double x = 0, y = 0, width = 0, height = 0;
};

/// One monitor, top-left based in the coordinates windows are moved in.
struct Screen {
  Rect frame;
  Rect workArea;
  double scale = 1;
  bool primary = false;
};

struct Window {
  /// Whatever finds the window again on a later call.
  uint64_t id = 0;
  Rect rect;
  std::string app;
};

struct Snapshot {
  std::optional<Window> active;
  std::vector<Screen> screens;
  /// Ordinary visible windows, front to back. Only filled when asked for.
  std::vector<Window> windows;
  /// The app that refused to hand over its window although Split has permission, if any.
  std::string refusingApp;
};

struct Move {
  uint64_t id = 0;
  Rect rect;
};

/// The app in front: bundle id (macOS), executable name (Windows/Linux) and the name people see.
struct AppInfo {
  std::string id;
  std::string name;
};

/// Something the main process wants to hear about without polling.
struct Event {
  enum Kind { Modifiers, Activated } kind = Modifiers;
  /// For Modifiers: ctrl = 1, alt = 2, shift = 4, logo (⌘ / Super) = 8.
  int flags = 0;
  /// For Activated: the app now in front.
  AppInfo app;
};

using EventSink = std::function<void(const Event &)>;

/// Each returns an empty string on success, or a message saying what went wrong.
std::string TakeSnapshot(bool withWindows, Snapshot &out);
std::string Apply(const std::vector<Move> &moves);
/// Whether Split may move other apps' windows; `prompt` asks the user where the OS can.
bool IsTrusted(bool prompt);
std::optional<AppInfo> FrontmostApp();
/// Starts sending modifier and app-switch events to `sink` on the main thread. Calling it again replaces the sink.
void StartWatching(EventSink sink);

}  // namespace split
