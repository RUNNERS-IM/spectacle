# Spectacle

[English](README.md) · **한국어**

키보드 단축키로 macOS 창을 옮기고 크기를 맞추는 앱입니다. 마우스가 필요 없습니다.

Spectacle 은 [Eric Czarny](https://github.com/eczarny) 가 만들었고 2016년 1.2 버전이 마지막이었습니다. 원본 저장소([eczarny/spectacle](https://github.com/eczarny/spectacle))는 보관(archived) 상태입니다. 이 포크는 [RUNNERS-IM](https://github.com/RUNNERS-IM) 이 유지보수하며, 새 버전·버그 수정·기능 추가는 모두 여기서 진행합니다.

## 설치

1. [Releases](https://github.com/RUNNERS-IM/spectacle/releases) 에서 `Spectacle-1.2.pkg` 를 받아 더블클릭합니다. "확인되지 않은 개발자" 경고가 뜨면 파일을 우클릭하고 **열기**를 누릅니다.
2. 애플 실리콘 맥에서는 처음 실행할 때 로제타 설치를 물을 수 있습니다. 설치하면 됩니다. 애플 실리콘 네이티브 빌드는 아래 로드맵에 있습니다.
3. **시스템 설정 → 개인 정보 보호 및 보안 → 손쉬운 사용** 에서 Spectacle 을 켭니다. 이 권한이 없으면 다른 앱의 창을 움직일 수 없습니다.

Homebrew 설치(`brew install --cask runners-im/tap/spectacle`)는 준비 중입니다.

## 기본 단축키

| 기호 | 키 |
|:---:|:---|
| ⌘ | 커맨드 |
| ⌃ | 컨트롤 |
| ⌥ | 옵션 |
| ⇧ | 시프트 |

모든 단축키는 환경설정에서 바꾸거나 비울 수 있습니다.

### 기본 동작

- 가운데 — ⌥⌘C (크기는 그대로)
- 전체 화면 — ⌥⌘F
- 왼쪽 반 — ⌥⌘←
- 오른쪽 반 — ⌥⌘→
- 위쪽 반 — ⌥⌘↑
- 아래쪽 반 — ⌥⌘↓
- 왼쪽 위 — ⌃⌘←
- 왼쪽 아래 — ⌃⇧⌘←
- 오른쪽 위 — ⌃⌘→
- 오른쪽 아래 — ⌃⇧⌘→

반·모서리 단축키를 반복해서 누르면 그 영역에서 1/2 → 1/3 → 2/3 로 번갈아 바뀝니다.

### 3등분

- 다음 1/3 — ⌃⌥→
- 이전 1/3 — ⌃⌥←

### 크기 조절

- 키우기 — ⌃⌥⇧→
- 줄이기 — ⌃⌥⇧←

크기를 바꿀 때 창이 이미 닿아 있는 화면 가장자리는 계속 붙어 있습니다.

### 여러 모니터

- 다음 모니터 — ⌃⌥⌘→
- 이전 모니터 — ⌃⌥⌘←

### 되돌리기

- 마지막 동작 취소 — ⌥⌘Z
- 다시 실행 — ⌥⇧⌘Z

## 로드맵

다음 버전들에서 이 순서로 진행합니다.

1. 애플 실리콘 네이티브 빌드, Carthage 대신 Swift Package Manager, Sparkle 2
2. Developer ID 서명·공증, runners.im 에서 제공하는 자동 업데이트
3. Homebrew tap
4. 새 비율(1/4, 2/3)과 메뉴바 격자 선택
5. 명령줄 도구와 URL 스킴(`spectacle left`, `spectacle://center`) — Raycast·단축어·스크립트 연동
6. 설정 JSON 내보내기·가져오기
7. 자동 배치: 단축키 하나(⌥⌘A)로 현재 모니터의 열린 창 전부를 개수에 맞게 배치
8. 창을 화면 가장자리로 끌면 자동 정렬(드래그 스냅)
9. 환경설정 창 현대화와 다국어

이슈와 풀 리퀘스트는 이 저장소에 올려 주세요.

## 자주 생기는 문제

### 손쉬운 사용 권한을 요구합니다

Spectacle 은 macOS 의 손쉬운 사용(Accessibility) 프로토콜로 다른 앱의 창을 움직입니다. **시스템 설정 → 개인 정보 보호 및 보안 → 손쉬운 사용** 에서 허용하기 전에는 동작하지 않습니다.

### 창이 생각한 크기로 안 바뀝니다

앱은 자기 창의 최소·최대 크기를 정해 둘 수 있습니다. Spectacle 은 그 제한을 항상 지키므로, 최소 폭이 1600px 인 창은 1440px 인 화면 절반에 들어갈 수 없습니다. 앱이 허용하는 한도 안에서 가장 가깝게 맞춥니다.

### 터미널 창이 이상하게 움직입니다

터미널과 비슷한 앱(iTerm2 등)은 글자 행·열이 온전히 보이는 크기만 허용합니다. Spectacle 은 먼저 정확한 크기를 시도하고, 안 되면 들어갈 때까지 조금씩 줄입니다. 그래서 살짝 덜컹거려 보일 수 있고, 결과는 목표 영역 가운데에 놓입니다.

### 어떤 앱은 아예 안 됩니다

화면을 비표준 방식으로 그리는 앱은 손쉬운 사용 프로토콜로 창을 드러내지 않습니다. 그런 창은 Spectacle 이 움직일 수 없습니다.

## 소스에서 빌드하기

지금 프로젝트는 아직 [Carthage](https://github.com/Carthage/Carthage) 를 씁니다.

```sh
carthage bootstrap --platform Mac
open Spectacle.xcodeproj
```

Xcode 에서 ⌘R 로 실행합니다. 로드맵 1번(Swift Package Manager 전환)이 끝나면 Carthage 는 필요 없어집니다.

## 라이선스

Spectacle 은 MIT 라이선스로 배포됩니다. [LICENSE.md](LICENSE.md) 를 보세요.

Copyright (c) 2017 Eric Czarny. Modifications copyright (c) 2026 RUNNERS-IM.
