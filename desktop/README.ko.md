# Split (Windows · 리눅스)

[English](README.md) · **한국어**

키보드 단축키로 지금 쓰는 창을 옮기고 크기를 맞추는 앱의 Windows · 리눅스 판입니다. macOS 판은 이 저장소 맨 위([README](../README.ko.md))에 있고, 이 폴더(`desktop/`)는 Windows 와 리눅스만 다룹니다.

창이 어디로 갈지 계산하는 부분은 macOS 앱의 JavaScript 파일(`Split/Resources/Window Position Calculations/*.js`)을 그대로 돌립니다. 그래서 반 · 1/3 · 모서리 · 크기 조절 결과가 맥과 같습니다.

> 아직 시험 단계입니다. 설치 파일은 GitHub Actions 실행 기록의 첨부로만 나오고 Releases 에는 올라가 있지 않습니다.

## 용어

- **트레이(알림 영역)**: Windows 작업 표시줄 오른쪽 끝, 리눅스 상단 막대의 작은 아이콘 칸. Split 은 창 없이 여기에만 아이콘을 두고 돌아갑니다.
- **X11 / Wayland**: 리눅스에서 화면에 창을 그리는 두 가지 방식. X11 은 앱이 다른 앱의 창을 옮길 수 있고, Wayland 는 보안 때문에 막아 둡니다. 그래서 Wayland 에서는 데스크톱(GNOME · KDE) 쪽에 작은 도우미를 하나 더 깔아야 합니다.
- **GNOME 확장**: GNOME 데스크톱 안에서 도는 작은 프로그램. Split 의 확장은 Split 앱이 부탁하면 창을 옮겨 줍니다.
- **KWin 스크립트**: KDE Plasma 의 창 관리자(KWin) 안에서 도는 작은 프로그램. Split 의 스크립트는 단축키를 받아 Split 앱에 위치를 묻고 창을 옮깁니다.
- **Super 키**: 키보드의 Windows 로고 키. 리눅스에서는 Super 라고 부릅니다. macOS 판에서 ⌘ 를 쓰는 자리에 이 키를 씁니다.

## 설치

### Windows

1. 설치 파일 `split-desktop-<버전>-windows-x64-setup.exe`(또는 `.msi`)를 받아 실행합니다.
2. 아직 코드 서명을 하지 않아 처음에 SmartScreen 경고가 뜹니다. **추가 정보 → 실행** 을 누르면 됩니다.
3. 처음 켜면 설정 창이 열리고, 그다음부터는 작업 표시줄 오른쪽 트레이에만 아이콘이 있습니다.

Windows 10 · 11 (64비트)에서 돌도록 만들었습니다.

### 리눅스

배포판에 맞는 파일을 받습니다.

- Ubuntu · Debian: `sudo apt install ./split-desktop-<버전>-linux-amd64.deb`
- Fedora · openSUSE: `sudo dnf install ./split-desktop-<버전>-linux-x86_64.rpm`
- 그 밖: `split-desktop-<버전>-linux-x86_64.AppImage` 에 실행 권한을 주고(`chmod +x`) 엽니다.

트레이 아이콘이 보이려면 데스크톱에 AppIndicator 지원이 있어야 합니다. GNOME 은 "AppIndicator and KStatusNotifierItem Support" 확장(Ubuntu 는 기본으로 켜져 있음)이 필요합니다. 아이콘이 없어도 단축키는 돌고, Split 을 한 번 더 실행하면 설정 창이 열립니다.

#### 어떤 세션인지에 따라

Split 은 켜질 때 `XDG_SESSION_TYPE` · `XDG_CURRENT_DESKTOP` 환경 변수를 보고 방법을 고릅니다. 설정 → 일반 → **창 옮기기 연결** 에 지금 상태가 나옵니다.

| 세션 | 필요한 것 |
|:---|:---|
| X11 (GNOME on Xorg, KDE X11, Xfce, Cinnamon, MATE 등) | 없음. 바로 됩니다. |
| Wayland + GNOME 45 이상 | Split GNOME 확장 |
| Wayland + KDE Plasma (5.27 · 6) | Split KWin 스크립트 |
| 그 밖의 Wayland (sway, Hyprland 등) | 아직 지원하지 않음. 설정 창에 안내가 나옵니다. |

#### Wayland + GNOME: 확장 설치

GNOME 확장 파일 `split-gnome-extension-<버전>.zip` 을 받아서:

```sh
gnome-extensions install --force split-gnome-extension-<버전>.zip
# 로그아웃했다가 다시 로그인한 뒤
gnome-extensions enable split@runners.im
```

저장소에서 바로 넣으려면 `desktop/linux/gnome-extension/split@runners.im` 폴더를 `~/.local/share/gnome-shell/extensions/` 아래에 복사하면 됩니다.

GNOME 은 `Super+Alt+←/→` 와 `Ctrl+Alt+←/→` 를 "작업 공간 옮기기" 에 이미 씁니다. 이 단축키는 Split 이 받지 못하고 설정의 단축키 탭에 빨간 안내가 뜹니다. Split 쪽 단축키를 바꾸거나, GNOME 쪽을 비우려면:

```sh
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-left "['<Super>Page_Up']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-right "['<Super>Page_Down']"
```

#### Wayland + KDE Plasma: KWin 스크립트 설치

KWin 스크립트 파일 `split-kwin-script-<버전>.kwinscript` 를 받아서:

```sh
kpackagetool6 --type KWin/Script --install split-kwin-script-<버전>.kwinscript   # Plasma 5 는 kpackagetool5
```

그다음 **시스템 설정 → 창 관리 → KWin 스크립트** 에서 Split 을 켭니다. KDE 에서는 단축키를 KWin 이 가지고 있어서, 바꾸려면 **시스템 설정 → 단축키 → KWin** 에서 "Split" 을 찾아 바꿉니다. Split 앱은 켜 두어야 합니다(스크립트가 앱에 위치를 묻습니다).

## 기본 단축키

macOS 판과 같고, ⌘ 자리에 Win(Windows) · Super(리눅스) 키를 씁니다. 모두 설정 → 단축키에서 바꾸거나 지울 수 있습니다(KDE Wayland 는 시스템 설정에서).

| 동작 | Windows | 리눅스 | macOS |
|:---|:---|:---|:---|
| 가운데 | Win+Alt+C | Super+Alt+C | ⌥⌘C |
| 전체 화면 | Win+Alt+F | Super+Alt+F | ⌥⌘F |
| 왼쪽 반 | Win+Alt+← | Super+Alt+← | ⌥⌘← |
| 오른쪽 반 | Win+Alt+→ | Super+Alt+→ | ⌥⌘→ |
| 위쪽 반 | Win+Alt+↑ | Super+Alt+↑ | ⌥⌘↑ |
| 아래쪽 반 | Win+Alt+↓ | Super+Alt+↓ | ⌥⌘↓ |
| 왼쪽 위 | Win+Ctrl+← | Super+Ctrl+← | ⌃⌘← |
| 왼쪽 아래 | Win+Ctrl+Shift+← | Super+Ctrl+Shift+← | ⌃⇧⌘← |
| 오른쪽 위 | Win+Ctrl+→ | Super+Ctrl+→ | ⌃⌘→ |
| 오른쪽 아래 | Win+Ctrl+Shift+→ | Super+Ctrl+Shift+→ | ⌃⇧⌘→ |
| 다음 모니터 | Win+Ctrl+Alt+→ | Super+Ctrl+Alt+→ | ⌃⌥⌘→ |
| 이전 모니터 | Win+Ctrl+Alt+← | Super+Ctrl+Alt+← | ⌃⌥⌘← |
| 다음 1/3 | Ctrl+Alt+→ | Ctrl+Alt+→ | ⌃⌥→ |
| 이전 1/3 | Ctrl+Alt+← | Ctrl+Alt+← | ⌃⌥← |
| 크게 | Ctrl+Alt+Shift+→ | Ctrl+Alt+Shift+→ | ⌃⌥⇧→ |
| 작게 | Ctrl+Alt+Shift+← | Ctrl+Alt+Shift+← | ⌃⌥⇧← |
| 되돌리기 | Win+Alt+Z | Super+Alt+Z | ⌥⌘Z |
| 다시 하기 | Win+Alt+Shift+Z | Super+Alt+Shift+Z | ⌥⇧⌘Z |
| 창 모두 자동 배치 | Win+Alt+A | Super+Alt+A | ⌥⌘A |

같은 반 단축키를 다시 누르면 1/2 → 2/3 → 1/3 로 바뀌고, 전체 화면을 다시 누르면 원래 크기로 돌아갑니다(맥과 같음). 자동 배치는 지금 화면에 보이는 창을 9개까지 한 번에 놓고, 되돌리기 한 번이면 전부 원래 자리로 갑니다.

**겹치는 단축키**: Windows 는 `Win+Ctrl+←/→` 를 가상 데스크톱 전환에 씁니다. 그래서 "왼쪽 위 · 오른쪽 위" 기본 단축키는 Windows 가 먼저 가져가고, 설정의 단축키 탭에 "이미 쓰고 있어 켜지 못했어요" 가 뜰 수 있습니다. 그럴 때는 다른 단축키로 바꿔 주세요.

## 설정

- **일반**: 로그인할 때 열기, 트레이에 보이기, 창 사이 간격(없음 · 좁게 · 보통 · 넓게 = 0 · 8 · 16 · 24), 창 옮기기 연결 상태
- **효과**: 옮긴 창 둘레를 잠깐 표시(끔 · 은은하게 · 또렷하게), 색, 누른 단축키 띄우기, 보이는 시간, 글자 자리. Wayland 에서는 앱이 자기 창 자리를 정할 수 없어 표시가 나오지 않습니다.
- **단축키**: 동작마다 단축키를 눌러 바꾸고 × 로 지움, 기본값으로 되돌리기

설정은 `settings.json` 으로 저장됩니다. Windows 는 `%APPDATA%\im.runners.split\`, 리눅스는 `~/.config/im.runners.split/` 입니다.

## 소스에서 빌드하기

필요한 것: Node.js 22, pnpm, Rust(stable). 리눅스는 Tauri 가 요구하는 패키지도 깔아야 합니다.

```sh
sudo apt install libwebkit2gtk-4.1-dev libayatana-appindicator3-dev librsvg2-dev libxdo-dev libssl-dev patchelf  # Ubuntu
```

```sh
cd desktop
pnpm install
cargo test -p split-core          # 창 위치 계산 · 자동 배치 · 되돌리기 테스트 (맥에서도 돎)
pnpm tauri dev                    # 개발용으로 켜기
pnpm tauri build                  # 설치 파일 만들기 → target.noindex/release/bundle/
```

빌드 결과는 `target.noindex/` 에 생깁니다. 이름이 `.noindex` 로 끝나는 폴더는 macOS Spotlight 가 색인하지 않습니다.

### 폴더 구조

```
desktop/
├── core/                 공통 계산(운영체제와 상관없음): 맥 JS 실행, 간격, 자동 배치, 되돌리기, 단축키 글자
├── src-tauri/            Tauri 앱(Rust): 트레이, 설정 저장, 창 이동 표시
│   └── src/platform/     운영체제별: windows.rs, linux_x11.rs, linux_gnome.rs, linux_kde.rs
├── src/                  설정 창(React + TypeScript)
├── locales/              화면 글자(ko.json, en.json). Rust 와 TypeScript 가 같이 읽음
└── linux/
    ├── gnome-extension/  GNOME(Wayland) 확장
    └── kwin-script/      KDE Plasma(Wayland) KWin 스크립트
```

CI 는 `.github/workflows/desktop.yml` 입니다. `desktop/` 이 바뀐 PR 마다 Windows(nsis · msi) · 리눅스(deb · rpm · AppImage)를 빌드해 실행 기록에 첨부합니다.

## 문제 · 의견

[GitHub Issues](https://github.com/RUNNERS-IM/split/issues) 에 남겨 주세요. 트레이 메뉴의 **도움말 · 피드백** 은 이 문서를 엽니다.

## 라이선스

MIT. 저장소 맨 위 [LICENSE.md](../LICENSE.md) 를 보세요.
