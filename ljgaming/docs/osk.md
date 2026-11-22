# LJGaming 화상 키보드 (Plasma Keyboard)

작성: 2026-11-22, LJGaming 의 Claude Code. 사용자가 마우스만으로도 쓰려고 화상 키보드를 깔았고, 그때 걸린 것과
우회한 것을 남깁니다. 시행착오는 `ljgaming-trial-and-error.md` 7.14, 명령과 결과의 원본은 `~/waydroid-setup-log.md` 의
2026-11-22 의 화상 키보드 절입니다.

## 지금 상태 (2026-11-22)

- **패키지:** plasma-keyboard 6.8.3(plasma 프로필, Qt Virtual Keyboard 6.12 위에서 돎). 언어(한글 배치 포함)는 시스템 설정의
  Plasma Keyboard 페이지에서 고릅니다.
- **평소에는 IBus**(실제 키보드의 한글 입력)이고, 화상 키보드가 필요할 때만 작업 표시줄의 **"화상 키보드 켜기/끄기"** 를 눌러
  바꿉니다. 다시 누르면 IBus 로 돌아옵니다. 바꿀 때마다 알림이 뜹니다.
- **되는 곳:** Wayland 로 뜨는 Qt, KDE 앱(입력 칸을 마우스로 누르면 뜸).
- **안 되는 곳:** 아래 "안 되는 곳과 우회" 표.

## 왜 바꿔 끼워야 하나

- KWin 의 입력기 자리는 하나입니다(`kwinrc` 의 `[Wayland] InputMethod`, 시스템 설정 > 키보드 > 가상 키보드). IBus Wayland 를
  고르면 화상 키보드가 없고, Plasma Keyboard 를 고르면 KWin 이 IBus 를 끄므로 실제 키보드로 한글을 칠 수 없습니다.
- plasma 프로필(`plasma.sh`)은 IBus Wayland 를 기본으로 맞춥니다. 화상 키보드를 켜 둔 동안 `./install-profile.sh --check plasma`
  는 "kwinrc InputMethod 가 IBus Wayland 가 아님" 을 냅니다(정상). 그때 `./install-profile.sh plasma` 를 돌리면 IBus 로 돌아갑니다.
- **마우스로 뜨게 하는 값:** KWin 의 "가상 키보드 표시:"(`kwinrc` 의 `[Wayland] VirtualKeyboardMode`, D-Bus
  `org.kde.KWin /VirtualKeyboard` 의 `mode`)는 0 하지 않음, 1 터치와 태블릿(기본값), 2 터치, 태블릿, 마우스 사용 시 입니다.
  1 이면 마우스로 입력 칸을 눌러도 뜨지 않습니다(처음 "적용했는데 안 보인다"). 2 로 둔 값이 몇 분 뒤 1 로 돌아가 있던 일이 있어
  (원인 못 찾음, 시스템 설정의 가상 키보드 페이지에서 적용한 것으로 짐작), `osk-toggle` 이 켤 때마다 2 로 맞춥니다.

## 켜고 끄기: `osk-toggle`

| 파일 | 저장소 | 이 기기 |
| --- | --- | --- |
| 스크립트 | `ljgaming/osk/osk-toggle` | `~/.local/bin/osk-toggle` (링크) |
| 실행기 | `ljgaming/osk/osk-toggle.desktop` | `~/.local/share/applications/osk-toggle.desktop` (링크) |

- `osk-toggle on`: `InputMethod` 를 Plasma Keyboard 로 쓰고(`kwriteconfig6 --notify` 라 KWin 이 바로 다시 읽음),
  `mode` 가 2 가 아니면 2 로 맞춥니다.
- `osk-toggle off`: `InputMethod` 를 IBus Wayland 로 되돌립니다. 인수가 없으면 지금 값의 반대로 바꿉니다.
- 시험(2026-11-22): 켜면 plasma-keyboard 1개, ibus-daemon 0개, `mode` 2. 끄면 반대. `mode` 를 일부러 1 로 둔 뒤 켜도 2 가 됨.
- 실행기의 `Exec` 는 절대 경로입니다. plasmashell 의 PATH 에 `~/.local/bin` 이 없기 때문입니다.

다시 깔 때(settingfiles 사본에서, root 필요 없음):

```sh
ln -sf ~/gitRepos/settingfiles/ljgaming/osk/osk-toggle ~/.local/bin/osk-toggle
ln -sf ~/gitRepos/settingfiles/ljgaming/osk/osk-toggle.desktop ~/.local/share/applications/osk-toggle.desktop
```

그다음 앱 메뉴에서 "화상 키보드 켜기/끄기" 를 작업 표시줄로 끌어 고정합니다. 고정 앱 목록은 기기마다 다르고 프로필이 건드리지
않습니다(2026-11-22 에는 두 화면의 작업 표시줄 `launchers` 끝에 `applications:osk-toggle.desktop` 을 넣음).

## 안 되는 곳과 우회

| 어디 | 증상 | 이유 | 우회 |
| --- | --- | --- | --- |
| Ghostty(이 기기의 터미널, Claude 대화도 여기) | 입력 칸을 눌러도 안 뜸 | GTK 앱은 ibus 패키지의 GTK 입력 모듈(`/usr/lib/gtk-4.0/4.0.0/immodules/libim-ibus.so`)을 골라 ibus-daemon 과 바로 이야기하고 KWin 의 text-input 을 쓰지 않음. 떠 있는 Ghostty 가 이 모듈을 불러 둔 것을 확인했고, 그때 KWin 은 `activeClientSupportsTextInput=false` | `GTK_IM_MODULE=wayland` 로 띄운 Ghostty 창에서는 뜸(2026-11-22 시험). 아래 "남은 것" |
| 터미널의 한글 | 화상 키보드로 치면 자모가 조합되지 않고 낱자로 들어감 | Qt Virtual Keyboard 의 한글 조합은 앞 글자(surrounding text)를 고쳐 쓰는 방식으로 보이고, 터미널은 주변 글을 주지 않음(짐작, 확인 안 함) | Claude 에게는 영문 배치로 두벌식 자리를 눌러 보냄(`dkssud` 로 안녕). Claude 가 읽음 |
| XWayland(X11) 앱: Steam, X11 로 뜨는 게임 | 안 뜸 | KWin 화상 키보드는 Wayland 의 text-input 으로만 닿음 | 게임은 마우스로. Steam 빅 픽처 모드에는 Steam 자체 화상 키보드가 있음(시험 안 함) |
| 다른 GTK 앱 | 안 뜰 수 있음 | Ghostty 와 같은 이유(Ghostty 만 확인) | 같은 우회(`GTK_IM_MODULE=wayland`) |

## 남은 것

- **이 기기의 Ghostty 에서 뜨게 하기(사용자 결정 대기):** Ghostty 는 systemd 사용자 서비스 `app-com.mitchellh.ghostty.service`
  (단일 인스턴스, `--gtk-single-instance=true --initial-window=false`)로 떠 있습니다. 바꾸려면 drop-in 으로
  `Environment=GTK_IM_MODULE=wayland` 를 넣고 서비스를 다시 띄워야 하고, 그러면 열린 Ghostty 창이 모두 닫힙니다. herdr 서버와 그
  안의 Claude 세션은 남을 것으로 보지만 시험하지 않았습니다. 바꾸면 평소 한글 입력도 KWin 을 거쳐 IBus 로 가는 길로 바뀌므로 한글
  입력을 다시 시험해야 합니다.
- **화상 키보드용 터미널을 따로 띄우는 것은 안 됨:** `GTK_IM_MODULE=wayland ghostty --gtk-single-instance=false` 창에서 `herdr`
  를 붙이면 두 번째 클라이언트가 바로 끝납니다(이미 붙은 클라이언트가 있을 때). 그래서 이 방법의 실행기는 만들었다가 지웠습니다.

## 되돌리기

- 화상 키보드를 끄고 IBus 로: `osk-toggle off`(또는 `./install-profile.sh plasma`).
- 마우스로 뜨지 않게: 시스템 설정 > 키보드 > 가상 키보드 > "가상 키보드 표시:" 를 "With Touch and Tablet" 으로.
- 지우기: 작업 표시줄에서 고정을 풀고 두 링크를 지운 뒤, plasma 프로필에서 `plasma-keyboard` 를 빼고 패키지를 지웁니다.
