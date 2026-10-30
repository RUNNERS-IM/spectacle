// Node binding for platform.h. Plain objects in, plain objects out.
#include <napi.h>

#include "platform.h"

namespace {

Napi::Object RectToJs(Napi::Env env, const split::Rect &r) {
  auto o = Napi::Object::New(env);
  o.Set("x", r.x);
  o.Set("y", r.y);
  o.Set("width", r.width);
  o.Set("height", r.height);
  return o;
}

split::Rect RectFromJs(const Napi::Object &o) {
  return {o.Get("x").As<Napi::Number>().DoubleValue(), o.Get("y").As<Napi::Number>().DoubleValue(),
          o.Get("width").As<Napi::Number>().DoubleValue(), o.Get("height").As<Napi::Number>().DoubleValue()};
}

Napi::Object WindowToJs(Napi::Env env, const split::Window &w) {
  auto o = Napi::Object::New(env);
  o.Set("id", Napi::Number::New(env, static_cast<double>(w.id)));
  o.Set("rect", RectToJs(env, w.rect));
  o.Set("app", w.app);
  return o;
}

Napi::Value Snapshot(const Napi::CallbackInfo &info) {
  auto env = info.Env();
  bool withWindows = info.Length() > 0 && info[0].ToBoolean().Value();
  split::Snapshot snapshot;
  auto error = split::TakeSnapshot(withWindows, snapshot);
  if (!error.empty()) {
    Napi::Error::New(env, error).ThrowAsJavaScriptException();
    return env.Undefined();
  }
  auto o = Napi::Object::New(env);
  o.Set("active", snapshot.active ? WindowToJs(env, *snapshot.active) : env.Null());
  auto screens = Napi::Array::New(env, snapshot.screens.size());
  for (size_t i = 0; i < snapshot.screens.size(); i++) {
    const auto &s = snapshot.screens[i];
    auto so = Napi::Object::New(env);
    so.Set("frame", RectToJs(env, s.frame));
    so.Set("workArea", RectToJs(env, s.workArea));
    so.Set("scale", s.scale);
    so.Set("primary", s.primary);
    screens.Set(i, so);
  }
  o.Set("screens", screens);
  auto windows = Napi::Array::New(env, snapshot.windows.size());
  for (size_t i = 0; i < snapshot.windows.size(); i++) {
    windows.Set(i, WindowToJs(env, snapshot.windows[i]));
  }
  o.Set("windows", windows);
  o.Set("refusingApp", snapshot.refusingApp.empty() ? env.Null() : Napi::String::New(env, snapshot.refusingApp));
  return o;
}

Napi::Value Apply(const Napi::CallbackInfo &info) {
  auto env = info.Env();
  std::vector<split::Move> moves;
  auto list = info[0].As<Napi::Array>();
  for (uint32_t i = 0; i < list.Length(); i++) {
    auto m = list.Get(i).As<Napi::Object>();
    moves.push_back({static_cast<uint64_t>(m.Get("id").As<Napi::Number>().DoubleValue()),
                     RectFromJs(m.Get("rect").As<Napi::Object>())});
  }
  auto error = split::Apply(moves);
  if (!error.empty()) {
    Napi::Error::New(env, error).ThrowAsJavaScriptException();
  }
  return env.Undefined();
}

Napi::Value IsTrusted(const Napi::CallbackInfo &info) {
  bool prompt = info.Length() > 0 && info[0].ToBoolean().Value();
  return Napi::Boolean::New(info.Env(), split::IsTrusted(prompt));
}

Napi::Value AppToJs(Napi::Env env, const split::AppInfo &app) {
  auto o = Napi::Object::New(env);
  o.Set("id", app.id);
  o.Set("name", app.name);
  return o;
}

Napi::Value FrontmostApp(const Napi::CallbackInfo &info) {
  auto app = split::FrontmostApp();
  return app ? AppToJs(info.Env(), *app) : info.Env().Null();
}

Napi::ThreadSafeFunction watcher;

// watch(callback): callback({type: "modifiers", flags} | {type: "activated", app}).
Napi::Value Watch(const Napi::CallbackInfo &info) {
  auto env = info.Env();
  if (watcher) watcher.Release();
  watcher = Napi::ThreadSafeFunction::New(env, info[0].As<Napi::Function>(), "split-watch", 0, 1);
  // Why: an open watcher would otherwise keep Node from ever exiting.
  watcher.Unref(env);
  split::StartWatching([](const split::Event &event) {
    auto copy = new split::Event(event);
    watcher.NonBlockingCall(copy, [](Napi::Env env, Napi::Function callback, split::Event *e) {
      auto o = Napi::Object::New(env);
      if (e->kind == split::Event::Modifiers) {
        o.Set("type", "modifiers");
        o.Set("flags", e->flags);
      } else {
        o.Set("type", "activated");
        o.Set("app", AppToJs(env, e->app));
      }
      delete e;
      callback.Call({o});
    });
  });
  return env.Undefined();
}

Napi::Object Init(Napi::Env env, Napi::Object exports) {
  exports.Set("snapshot", Napi::Function::New(env, Snapshot));
  exports.Set("apply", Napi::Function::New(env, Apply));
  exports.Set("isTrusted", Napi::Function::New(env, IsTrusted));
  exports.Set("frontmostApp", Napi::Function::New(env, FrontmostApp));
  exports.Set("watch", Napi::Function::New(env, Watch));
  return exports;
}

}  // namespace

NODE_API_MODULE(split_native, Init)
