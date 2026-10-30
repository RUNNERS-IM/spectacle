#!/usr/bin/env bash
# App Store 판(샌드박스, Sparkle 없음)을 아카이브해 App Store Connect 에 올린다. 심사 제출은 하지 않는다.
#
#   scripts/release-app-store.sh 1.3
#
# 필요한 것: App Store Connect 에 im.runners.Split 앱 등록, App Store Connect API 키
# (~/.runners/secrets/AuthKey_<ID>.p8). 배포용 인증서·프로필은 Xcode 가 API 키로 만들거나 받아 온다
# (-allowProvisioningUpdates). 키 권한이 Admin 이어야 인증서를 만들 수 있다.
set -euo pipefail

VERSION="${1:?버전을 적어 주세요. 예: scripts/release-app-store.sh 1.3}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASC_API_KEY_ID="${ASC_API_KEY_ID:-K8NGP73726}"
ASC_API_ISSUER_ID="${ASC_API_ISSUER_ID:-6474b3ad-9daa-4bf4-ba04-f1e12d35099c}"
ASC_KEY="$HOME/.runners/secrets/AuthKey_${ASC_API_KEY_ID}.p8"
OUT="$REPO_ROOT/build.noindex/app-store/$VERSION"
ARCHIVE="$OUT/Split-AppStore.xcarchive"
AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY" -authenticationKeyID "$ASC_API_KEY_ID" -authenticationKeyIssuerID "$ASC_API_ISSUER_ID")

[ -f "$ASC_KEY" ] || { echo "중단: App Store Connect API 키가 없습니다: $ASC_KEY" >&2; exit 1; }
rm -rf "$OUT"; mkdir -p "$OUT"

echo "== App Store 판 아카이브"
xcodebuild archive -project "$REPO_ROOT/Split.xcodeproj" -scheme "Split App Store" -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$ARCHIVE" "${AUTH[@]}" -quiet

echo "== App Store Connect 업로드"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$OUT/export" \
  -exportOptionsPlist "$REPO_ROOT/scripts/ExportOptions-AppStore.plist" "${AUTH[@]}"

echo "업로드했습니다. App Store Connect → Split → TestFlight 에서 처리 상태를 보고, 심사 제출은 직접 합니다."
