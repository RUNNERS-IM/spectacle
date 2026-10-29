#!/usr/bin/env bash
# release 빌드 전에 Info.plist 버전을 올린다. 센스·푸딩과 같은 규칙:
# 출시일(KST) 기준 2.{연도 끝자리}.{MMDD}. 같은 날 이미 낸 버전이 있으면 뒤에 .2, .3 을 붙인다
# (GitHub 태그는 겹칠 수 없어서). 빌드 번호는 따로 올리지 않는다 — 빌드할 때 커밋 수로 정해진다.
# 새 버전을 한 줄로 출력한다.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INFO_PLIST="$REPO_ROOT/Split/Supporting Files/Info.plist"

YEAR=$(TZ=Asia/Seoul date +%Y)
BASE="2.$((YEAR % 10)).$(TZ=Asia/Seoul date +%m%d)"
VERSION="$BASE"
N=2
while git -C "$REPO_ROOT" rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null; do
  VERSION="$BASE.$N"
  N=$((N + 1))
done

/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $VERSION" "$INFO_PLIST"
echo "$VERSION"
