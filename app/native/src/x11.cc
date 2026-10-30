// Not yet moved over from desktop/src-tauri/src/platform; Split's Electron build starts with macOS.
#include "platform.h"

namespace split {

std::string TakeSnapshot(bool, Snapshot &) { return "not supported yet"; }
std::string Apply(const std::vector<Move> &) { return "not supported yet"; }
bool IsTrusted(bool) { return true; }
std::optional<AppInfo> FrontmostApp() { return std::nullopt; }
void StartWatching(EventSink) {}

}  // namespace split
