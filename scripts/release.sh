#!/usr/bin/env bash
# Spectacle 릴리스: 빌드 → Developer ID 서명 → 애플 공증 → zip/dmg → Sparkle 업데이트 서명 → appcast.
#
#   scripts/release.sh 2.0            # build/release/2.0/ 에 파일만 만든다 (GitHub 에 안 올림)
#   scripts/release.sh 2.0 --publish  # 위 + GitHub Releases v2.0 으로 올린다
#
# 필요한 것 (맥마다 한 번, ~/claude-config/bin/spectacle-keys 가 준비):
#   - 키체인의 Developer ID Application 인증서 (RGWVXJ8URP)
#   - notarytool 키체인 이름 "runners"
#   - ~/.runners/secrets/sparkle_eddsa_private.key
#
# 앱은 https://runners.im/spectacle/appcast.xml 을 읽고, runners.im 이 GitHub 의
# releases/latest/download/appcast.xml 로 넘겨 준다. 그래서 appcast.xml 은 매 릴리스에 같이 올린다.
set -euo pipefail

VERSION="${1:?버전을 적어 주세요. 예: scripts/release.sh 2.0}"
PUBLISH="${2:-}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GITHUB_REPO="RUNNERS-IM/spectacle"
NOTARY_PROFILE="runners"
SPARKLE_KEY="$HOME/.runners/secrets/sparkle_eddsa_private.key"
INFO_PLIST="$REPO_ROOT/Spectacle/Supporting Files/Info.plist"

OUT="$REPO_ROOT/build/release/$VERSION"
DERIVED="$REPO_ROOT/build/DerivedData"
ARCHIVE="$OUT/Spectacle.xcarchive"
APP="$OUT/export/Spectacle.app"
ZIP="$OUT/Spectacle-$VERSION.zip"
DMG="$OUT/Spectacle-$VERSION.dmg"

step() { printf '\n== %s\n' "$*"; }
fail() { printf '중단: %s\n' "$*" >&2; exit 1; }

step "준비물 확인"
security find-identity -v -p codesigning | grep -q "Developer ID Application" \
  || fail "Developer ID Application 인증서가 없습니다. Xcode → 설정 → Accounts → Manage Certificates 에서 만드세요."
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
  || fail "공증 키체인 이름 '$NOTARY_PROFILE' 이 동작하지 않습니다. ~/claude-config/bin/spectacle-keys 실행, 애플 약관 동의를 확인하세요."
[ -f "$SPARKLE_KEY" ] || fail "Sparkle 서명 키가 없습니다: $SPARKLE_KEY"
PLIST_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$INFO_PLIST")
[ "$PLIST_VERSION" = "$VERSION" ] \
  || fail "Info.plist 버전($PLIST_VERSION)과 요청한 버전($VERSION)이 다릅니다. Info.plist 를 먼저 올리고 커밋하세요."
[ -z "$(git -C "$REPO_ROOT" status --porcelain)" ] || fail "커밋하지 않은 변경이 있습니다."

rm -rf "$OUT"; mkdir -p "$OUT"

step "테스트"
xcodebuild test -project "$REPO_ROOT/Spectacle.xcodeproj" -scheme Spectacle \
  -destination 'platform=macOS' -derivedDataPath "$DERIVED" -quiet

step "아카이브 (유니버설 Release)"
xcodebuild archive -project "$REPO_ROOT/Spectacle.xcodeproj" -scheme Spectacle -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$DERIVED" -archivePath "$ARCHIVE" -quiet

step "Developer ID 서명으로 내보내기"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$OUT/export" \
  -exportOptionsPlist "$REPO_ROOT/scripts/ExportOptions.plist" -quiet
codesign --verify --deep --strict --verbose=2 "$APP"

step "앱 공증"
ditto -c -k --keepParent "$APP" "$OUT/notarize.zip"
xcrun notarytool submit "$OUT/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
rm "$OUT/notarize.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

step "dmg 만들고 공증"
STAGE="$OUT/dmg"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"; ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Spectacle $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
codesign --sign "Developer ID Application" --timestamp "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
spctl -a -t open --context context:primary-signature -v "$DMG"

step "Sparkle appcast"
SPARKLE_BIN=$(find "$DERIVED/SourcePackages/artifacts" -type d -path "*Sparkle/bin" | head -1)
[ -n "$SPARKLE_BIN" ] || fail "Sparkle 도구를 찾지 못했습니다."
FEED="$OUT/feed"; mkdir -p "$FEED"; cp "$ZIP" "$FEED/"
"$SPARKLE_BIN/generate_appcast" --ed-key-file "$SPARKLE_KEY" \
  --download-url-prefix "https://github.com/$GITHUB_REPO/releases/download/v$VERSION/" \
  -o "$OUT/appcast.xml" "$FEED"
rm -rf "$FEED"

step "결과"
ls -lh "$ZIP" "$DMG" "$OUT/appcast.xml"

if [ "$PUBLISH" = "--publish" ]; then
  step "GitHub Releases v$VERSION 에 올리기"
  git -C "$REPO_ROOT" tag -a "v$VERSION" -m "Spectacle $VERSION"
  git -C "$REPO_ROOT" push origin "v$VERSION"
  gh release create "v$VERSION" "$ZIP" "$DMG" "$OUT/appcast.xml" \
    --repo "$GITHUB_REPO" --title "Spectacle $VERSION" --generate-notes --latest
else
  echo "GitHub 에는 올리지 않았습니다. 올리려면: scripts/release.sh $VERSION --publish"
fi
