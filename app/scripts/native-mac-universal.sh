#!/bin/sh
# Builds the window module for Apple silicon and Intel, then joins them into one file, so the
# universal Split.app loads it on both.
set -eu
cd "$(dirname "$0")/.."
ELECTRON=$(node -p "require('electron/package.json').version")
OUT=native/build/Release/split_native.node
TMP=$(mktemp -d)
for ARCH in arm64 x64; do
  node_modules/.bin/node-gyp rebuild --directory native --arch="$ARCH" --target="$ELECTRON" --dist-url=https://electronjs.org/headers >/dev/null
  cp "$OUT" "$TMP/$ARCH.node"
done
lipo -create "$TMP/arm64.node" "$TMP/x64.node" -output "$OUT"
rm -rf "$TMP"
lipo -archs "$OUT"
