# Contributing

Issues and pull requests are welcome at [RUNNERS-IM/split](https://github.com/RUNNERS-IM/split).

## Issues

Search the existing issues first. When reporting a defect, include the Split version (Split → About), the macOS version, the shortcut or menu item you used, and what you expected to happen.

## Pull requests

- Branch from `master` and keep each pull request to one change.
- Run the tests before sending: `xcodebuild test -project Split.xcodeproj -scheme Split -destination 'platform=macOS'`.
- New text shown to users goes into `Split/Resources/Localizations/*/App.strings` for all 18 languages.
- Releases are made by merging `master` into `release`; do not bump versions by hand.
