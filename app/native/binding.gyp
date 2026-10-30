{
  "targets": [
    {
      "target_name": "split_native",
      "sources": ["src/addon.cc"],
      "include_dirs": ["<!(node -p \"require('node-addon-api').include_dir\")"],
      "defines": ["NAPI_VERSION=8", "NAPI_DISABLE_CPP_EXCEPTIONS"],
      "conditions": [
        ["OS=='mac'", {
          "sources": ["src/mac.mm"],
          "xcode_settings": {
            "MACOSX_DEPLOYMENT_TARGET": "13.0",
            "CLANG_ENABLE_OBJC_ARC": "YES",
            "OTHER_CPLUSPLUSFLAGS": ["-std=c++20"]
          },
          "link_settings": {
            "libraries": ["-framework AppKit", "-framework ApplicationServices"]
          }
        }],
        ["OS=='win'", {
          "sources": ["src/win.cc"],
          "libraries": ["user32.lib", "dwmapi.lib", "shcore.lib"],
          "msvs_settings": { "VCCLCompilerTool": { "AdditionalOptions": ["/std:c++20"] } }
        }],
        ["OS=='linux'", {
          "sources": ["src/x11.cc"],
          "libraries": ["-lX11", "-lXrandr"],
          "cflags_cc": ["-std=c++20"]
        }]
      ]
    }
  ]
}
