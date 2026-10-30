// electron-builder settings for Split, in the same shape as the other RUNNERS apps (Prompt's
// config/electron-builder.config.cjs). Release builds set SPLIT_RELEASE=1 so signing and
// notarization are required; local builds stay unsigned-friendly.
const isRelease = process.env.SPLIT_RELEASE === '1'

module.exports = {
  appId: 'im.runners.Split',
  productName: 'Split',
  copyright: '© 2026 RUNNERS. All rights reserved.',
  // Why: .noindex keeps Spotlight from listing the test app next to the installed one.
  directories: { output: 'dist.noindex', buildResources: 'resources/build' },
  files: ['out/**', 'package.json'],
  extraResources: [
    // The native module (native/split-native.<os>-<cpu>*.node) is added per system below.
    { from: '../Split/Resources/Window Position Calculations', to: 'Window Position Calculations' },
    { from: 'resources/menu', to: 'menu' },
    { from: 'resources/tray', to: 'tray' },
  ],
  // The window math and icons sit outside app.asar, so nothing in node_modules is needed at run time but electron-updater.
  asar: true,
  mac: {
    category: 'public.app-category.utilities',
    artifactName: 'Split-${version}-mac.${ext}',
    icon: 'resources/build/icon.icns',
    minimumSystemVersion: '13.0',
    target: [
      { target: 'dmg', arch: ['universal'] },
      { target: 'zip', arch: ['universal'] },
    ],
    // Why: pnpm native:mac-universal joins both CPUs into one file, so both halves of the universal app carry the same one.
    extraResources: [{ from: 'native', to: 'native', filter: ['split-native.darwin-universal.node'] }],
    x64ArchFiles: 'Contents/Resources/native/*.node',
    hardenedRuntime: true,
    entitlements: 'resources/build/entitlements.mac.plist',
    entitlementsInherit: 'resources/build/entitlements.mac.plist',
    notarize: isRelease,
    extendInfo: {
      // Split lives in the menu bar and has no Dock icon, like the macOS app before it.
      LSUIElement: true,
      NSHumanReadableCopyright: '© 2026 RUNNERS. All rights reserved.',
    },
  },
  forceCodeSigning: isRelease,
  dmg: { artifactName: 'Split-${version}.${ext}' },
  publish: {
    provider: 'github',
    owner: 'RUNNERS-IM',
    repo: 'split',
  },
}
