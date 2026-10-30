#!/bin/sh
# Builds the native module for Apple silicon and Intel and joins them into one file, so the
# universal app carries a single split-native.darwin-universal.node.
set -e
cd "$(dirname "$0")/.."
for TARGET in aarch64-apple-darwin x86_64-apple-darwin; do
  node_modules/.bin/napi build --manifest-path native/Cargo.toml --package-json-path native/package.json --platform --release --output-dir native --no-js --target "$TARGET" >/dev/null
done
lipo -create native/split-native.darwin-arm64.node native/split-native.darwin-x64.node -output native/split-native.darwin-universal.node
