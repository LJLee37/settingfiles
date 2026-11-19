# CLAUDE.md - LJGaming (게이밍 데스크탑)

> 이 파일(`~/.claude/CLAUDE.md`)은 settingfiles 의 `ljgaming/install.sh` 가 `ljgaming/CLAUDE.md` 에서 깝니다(2026-11-17).
> 직접 고치면 다음 실행 때 "다름"으로 나오니, 고칠 것이 있으면 사용자에게 말씀드리고 컨트롤 노드에서 settingfiles 를
> 고칩니다.

## 이 기기

- **LJGaming**: i5-14400F(내장 그래픽 없음), RTX 2080. Windows 와 듀얼 부팅하는 Arch 입니다.
  - Samsung NVMe 의 p1~p4 는 Windows 입니다(ESP, MSR, C:, 복구).
  - p5 는 Arch 로, btrfs `ljgaming-root` 에 서브볼륨 `@ @home @snapshots @var_log @pkg` 가 있습니다.
- **부팅**: GRUB(`EFI/Arch`)과 os-prober 를 씁니다. Windows ESP 를 `/efi` 에 같이 마운트하고, `/boot` 는 btrfs 루트 안에
  있습니다. Secure Boot 는 꺼져 있습니다.
- **그래픽과 데스크톱**: nvidia-open(systemd 기반 initramfs, HOOKS 에 `kms` 없음). Plasma 6(Wayland)만
  씁니다. GNOME 은 2026-11-19 에 지웠고(사용자 승인), 로그인 화면은 plasma-login-manager 입니다.
- **프로필**: settingfiles 의 `base snapshots cpu-intel gpu-nvidia desktop plasma gaming apps office` 입니다(2026-11-19). 이 기기는
  `hosts/*.env` 가 없으니 `./install-profile.sh --check <위 목록>` 으로 빠진 것을 봅니다. 프로필에 없이 손으로 깐 것(os-prober,
  pam-u2f, shairport-sync 와 nqptp, waydroid-nvidia-bin 과 waydroid-script-git)은 아래 문서에 있습니다.
- **설치 방법**: LJINST 임시 USB 에서 `~/docs` 의 문서대로 깔았습니다(2026-11-17). settingfiles 의 설치 스크립트
  (install0~2)는 쓰지 않았고 `set.sh` 만 돌렸습니다. 기록은 `~/waydroid-setup-log.md` 와 `~/install-logs/` 에 있습니다.
- **server-automation 이 관리하지 않습니다**(사용자 결정 2026-11-17).
  - sshd 는 꺼 두고, nftables 가 들어오는 연결을 막습니다.
  - 포트를 열거나 sshd 를 켜는 것은 사용자 승인을 받은 뒤에만 합니다. 지금 여는 것은 모두 LAN(사설, 링크 로컬)
    출발지에만 엽니다.
    - mDNS(UDP 5353)와 Steam 포트
    - AirPlay 2: TCP 7000, UDP 319 와 320, TCP 와 UDP 32768-60999. shairport-sync 가 AirPlay 2 소켓을 임의
      포트에 열기 때문입니다(2026-11-18).
    - WayDroid: `waydroid0` 의 DNS 와 DHCP 입력, 그리고 forward(컨테이너에서 나가는 것과 그 응답만)(2026-11-18).

## 할 일과 문서

사용자에게는 한국어 존댓말로 답합니다. 문서와 실제가 다르면 추측하지 말고 묻습니다.

다시 깔 때의 절차는 settingfiles 의 문서 셋에 있습니다(2026-11-18). 이 기기의 `~/docs/ljgaming-waydroid.md`,
`~/docs/ljgaming-airplay.md`, `~/docs/pam-u2f-setup.md` 와 같은 내용이고, 바꿀 것은 컨트롤 노드에서 저장소 쪽을 고칩니다.

- `ljgaming/docs/waydroid.md`: WayDroid(원스토어용). waydroid-nvidia-bin 0.2.0 `--mode venus`, GAPPS(LineageOS 20,
  Android 13), libhoudini, 창 1280x720 고정이고 Plasma 에서만 씁니다(GNOME 에서는 hwcomposer 가 죽음, #21). 소리는 안
  나고(사용자가 미룸), 재부팅 뒤 컨테이너는 저절로 뜨고, binder 는 세션을 시작할 때 생깁니다(2026-11-19 확인).
- `ljgaming/docs/airplay.md`: AirPlay 2 수신기 "LJGaming" 하나(직접 빌드한 shairport-sync 5.6.3 과 nqptp 1.2.9, 보안
  갱신은 직접 챙김). 1시간 시험 통과(2026-11-18). 남은 확인은 로그아웃 뒤 다시 로그인했을 때 저절로 돌아오는지, 절전
  복귀 뒤 D802C 잡음이 없어지는지입니다. AirPlay 2 모드에서는 수신기가 원격 제어(다음 곡 등)를 보낼 수 없어, 곡이
  저절로 넘어가면 보내는 기기 쪽을 먼저 봅니다.
- `docs/pam-u2f.md`: sudo 와 polkit 의 토큰 터치(아래 "root 권한"). 토큰을 바꾸거나 되돌리는 법도 있습니다.

이 기기의 `~/docs` 에 있는 것:

- `~/docs/handoff-ljinst-to-desktop.md`: USB 에서 넘어올 때의 상태와 다음 할 일입니다.
- `~/docs/dualboot-waydroid-plan.md`: 이중 부팅과 WayDroid 계획, 단계별 경과입니다.
- `~/docs/gaming-daily-setup.md`: Steam, 일상 패키지.
- `~/docs/airplay-receiver-setup.md`: AirPlay 수신기 조사와 계획. 목표는 사용자가 "24bit/48kHz 또는 96kHz 비트퍼펙트"로
  바꿨습니다.
- `~/docs/ljgaming-trial-and-error.md`: 이 기기에서 겪은 시행착오(증상, 원인, 해결).
- 한 일은 `~/waydroid-setup-log.md` 에 이어 적습니다(실행한 명령, 판, 결과, 실패와 조치).

## root 권한

- 이 Claude Code 에서는 `! sudo` 로 비밀번호를 넣을 수 없습니다(터미널이 없음).
- root 가 필요한 일은 명령과 목적, 영향을 먼저 보여 승인받습니다. 승인받으면 둘 중 하나로 돌립니다(2026-11-19 사용자 결정,
  이 기기에서 시험함).
  - **한 줄짜리**: `sudo -A <명령>`. 비밀번호는 ksshaskpass 창이 묻습니다(`SUDO_ASKPASS`, desktop 프로필). 명령마다 다시
    묻습니다(터미널이 없어 sudo 시간표가 이어지지 않음).
  - **여러 단계**: 스크립트 파일로 묶어 `pkexec /usr/bin/bash <스크립트>`. 비밀번호와 터치가 한 번이고 스크립트와 출력이
    `~/install-logs` 에 남습니다.
  - 어느 쪽이든 사용자가 로그인 비밀번호를 넣고 이어서 FIDO2 토큰(A 나 B)을 터치합니다(2026-11-17, 토큰은 2026-11-18 부터).
- **돌리기 전에 사용자에게 토큰을 꽂아 달라고 말하고, "비밀번호 다음에 토큰 터치"라고 미리 알립니다.** sudo -A 의 터치
  안내("Please touch the FIDO authenticator.")는 창으로 오지 않고 Claude 의 명령 출력에만 나옵니다. 토큰이 없으면
  비밀번호가 맞아도 실패하고, 화면에는 비밀번호가 틀린 것처럼 보입니다.
- askpass 창은 어떤 명령을 허가하는지 보여 주지 않으므로, 실행 직전에 돌릴 명령을 대화에 그대로 다시 보입니다. 창의
  "Remember password" 는 sudo 비밀번호에 켜지 말라고 알립니다(켜면 로그인 비밀번호가 KWallet 에 들어감).
- sudo 와 polkit 은 `/etc/pam.d/sudo` 와 `/etc/pam.d/polkit-1` 에서 비밀번호(system-auth) 다음에 pam_u2f 를
  요구합니다(`/etc/u2f_mappings`, root 소유, origin 과 appid `pam://LJGaming`). 등록 정보를 사용자 홈
  (`~/.config/Yubico`)에 두지 않는 것은 약한 로그인 비밀번호만으로 바꿔칠 수 있기 때문입니다. 로그인 화면(plasma-login-manager), su,
  콘솔 로그인은 그대로이고, root 비밀번호가 비상구입니다. 절차와 토큰 교체, 되돌리기는 settingfiles 의 `docs/pam-u2f.md`
  입니다.
- 파티션, 포맷, 부트로더, 펌웨어 부트 항목은 명령 하나씩 승인받습니다. Windows 파티션과 ESP 의 `EFI/Microsoft` 는
  건드리지 않습니다.
- `grub-mkconfig` 는 `LC_ALL=C` 로 돌립니다. 한국어 로케일에서는 번역문의 서식(`%1$s`) 때문에 실패하고, grub.cfg 는
  그대로 남습니다.

## 패키지

- 그룹째 깔지 않고 쓰는 것만 이름으로 깝니다. 기준은 settingfiles 의 `profiles/*.txt` 입니다. 설치 때 `gnome` 그룹을
  통째로 깔았다가 원치 않는 앱이 들어와 정리한 적이 있습니다.
- 이 기기는 settingfiles 스크립트 없이 깔아서 base 의 패키지도 다른 것의 의존성으로만 들어와 있을 수 있습니다. 프로필을
  통째로 지울 때는 지울 목록을 남는 프로필 목록과 맞춰 보고, 남길 것은 먼저 `pacman -D --asexplicit` 로 표시합니다
  (2026-11-19 GNOME 을 지울 때 openssh 가 같이 빠져 다시 깔았음).
- 터미널은 Ghostty 하나만 씁니다. 편집기는 nvim 이고, `vim` 은 nvim 을 가리키는 링크입니다. gnome-text-editor 는
  지웠습니다(nvim 으로 충분, 사용자 2026-11-17).
- AUR 헬퍼(yay, paru)는 쓰지 않습니다. `git clone https://aur.archlinux.org/<이름>.git ~/aur/<이름>` 를 한 뒤 PKGBUILD 를
  보여 드리고, 승인을 받으면 `makepkg -si` 를 돌립니다.
- snapper 와 snap-pac 이 pacman 전후에 스냅샷을 남깁니다. 되돌릴 때는 `snapper list` 를 봅니다. 루트를 되돌리는 것은
  LJINST USB 로 부팅해 ArchWiki 「Snapper」 의 서브볼륨 교체 절차로 합니다.

## 로그인, 비밀 저장소, SSH (2026-11-18)

- **비밀 저장소는 KWallet** 입니다. `/etc/pam.d/plasmalogin` 의 pam_kwallet5 로 로그인 비밀번호와 함께 저절로 열립니다.
  gnome-keyring 과 옛 키링 파일(`~/.local/share/keyrings`)은 2026-11-19 GNOME 과 함께 지웠습니다.
- **SSH 에이전트**는 OpenSSH 의 `ssh-agent.socket` 과 ksshaskpass 입니다(`~/.config/environment.d/61-ssh-agent.conf`).
  gcr-ssh-agent 는 FIDO2(sk) 키로 서명하지 못합니다. `~/.ssh/config` 의 main-server 블록이 이 에이전트와 토큰 A, B 의
  sk 키를 씁니다. 같은 파일의 `SSH_ASKPASS_REQUIRE=prefer` 로 터미널에서 돌려도 토큰 PIN 을 ksshaskpass 창으로 묻습니다
  (2026-11-19, desktop 프로필. pull 뒤 `./install-profile.sh desktop` 과 다시 로그인부터). 토큰 PIN 은 창의 Remember
  password 를 켜지 않습니다. 에이전트에 올린 토큰 키도 쓸 때마다 PIN 과 터치를 묻습니다.
- **herdr** 에 main-server 가 머신으로 등록돼 켜져 있습니다. 연결이 끊기면 약 30초마다 다시 붙으려 하고, 그때 토큰이
  꽂혀 있으면 PIN 을 묻습니다(연결돼 있는 동안은 묻지 않음). 끄려면 `herdr machine disable <id>` 입니다.
- **linger**(`loginctl enable-linger ljlee`)로 herdr 서버가 로그아웃 뒤에도 남습니다. 그래서 사용자 관리자와 세션 D-Bus
  도 남습니다. `WantedBy=default.target` 서비스는 다음 로그인 때 다시 뜨지 않고, D-Bus 서비스 파일은 ReloadConfig
  전까지 반영되지 않습니다.
- **한글 입력**: `~/.config/environment.d/60-ibus-xim.conf` 의 `XMODIFIERS=@im=ibus`(plasma 프로필의 `plasma.sh` 가
  만듦)와, Steam 에만 둔 `GTK_IM_MODULE=ibus`(데스크톱 파일 사본, 이것도 `plasma.sh` 가 만듦)입니다. Plasma Wayland 에서 XWayland 앱(Steam)의
  한글 입력 때문입니다.
- **Discord** 는 기본값(네이티브 Wayland)으로 씁니다. 한글 조합 중 Shift+Enter 가 줄바꿈이 아니라 전송이 되는 문제는
  감수합니다(사용자 결정 2026-11-18). XWayland 로 고정하는 우회(`--ozone-platform=x11` 과 `GTK_IM_MODULE=ibus`)는
  시험해 보고 되돌렸고, 그 파일은 `~/install-logs/discord-x11-20261118/` 에 있습니다.

## Plasma 화면 (2026-11-18)

테마, 패널, Dolphin 미리보기, 전원과 화면 잠금, 자연 스크롤, 한/영 키, Steam 한글 입력 사본은 plasma 프로필의
`plasma.sh` 가 맞춥니다(`./install-profile.sh --check plasma` 로 확인). 프로필에 넣지 않은 것은 배경 이미지와 모니터별
설정(HDR, 밝기, 주사율. `~/.config/kwinoutputconfig.json` 과 `kwinrc` 의 `[Windows_HDR]`)입니다.

- **테마**: Breeze 어두운 테마 위에 색 구성표 "하늘보라 다크"(저장소 `profiles/plasma/SkyVioletDark.colors`, Breeze Dark
  바탕에 선택, 포커스, 링크는 하늘색, 마우스 올림과 방문 링크는 보라색), 아이콘은 Tela-circle-purple-dark
  (`tela-circle-icon-theme-purple`)입니다. 바꾸기 전 설정은 `~/install-logs/theme-backup-20261118/` 에 있습니다.
- **터미널 앱**: Konsole 이 없으므로 `kdeglobals` 의 `[General] TerminalApplication=ghostty` 입니다(desktop 프로필의
  `desktop.sh` 가 정함). Terminal=true 앱
  (메뉴의 htop)과 Dolphin 의 "터미널 열기"가 이 값을 쓰고, 없으면 konsole 을 찾다가 실패합니다. `TerminalService` 는
  비워 둡니다. Ghostty 데스크톱 파일이 `--gtk-single-instance=true` 로 열어 작업 폴더가 넘어가지 않을 수 있습니다.
- **패널**: 두 화면(LG 2560x1080, Samsung 1920x1080) 모두 하단 패널이고 위젯 구성과 순서가 같습니다(`profiles/plasma/panels.js`).
  작업 표시줄은 모든 화면의 창을 보여 줍니다. 트레이 설정은 패널마다 따로 저장되며 서로 맞추지 않습니다(사용자 결정).
- **전원과 잠금**: 전원 연결 때 15분 뒤 화면 어둡게, 30분 뒤 끄기, 자동 절전 안 함. 30분 뒤 화면 잠금(잠그면 바로 비밀번호).
- **마우스**: 모든 마우스가 자연 스크롤입니다(사용자 2026-11-18, `kcminputrc` 의 `[Libinput][Defaults][Pointer]`). 장치별
  그룹에 값이 있으면 그것이 우선합니다.
- **모니터**(프로필에 없음, 다시 깔면 손으로. 2026-11-19 `kscreen-doctor -o` 기준): 화면 0 은 LG(DP-3, 주 모니터, 오른쪽
  1920,0) 2560x1080 74.99 Hz 에 HDR 과 넓은 색 영역을 켜고 SDR 밝기 250 nits, 최대 밝기를 250 nits 로 덮어씀(EDID 248),
  DDC 밝기 90% 입니다. 화면 1 은 Samsung(HDMI-A-1, 왼쪽 0,241) 1920x1080 60 Hz, HDR 없음, 밝기 100% 입니다. 둘 다 배율 1,
  sRGB. HDR 값은 사용자가 직접 맞춘 것이고 `kwinrc` 의 `[Windows_HDR] MaxLuminance=250`, `Reference=250` 과 함께 갑니다.
- **배경**: 바탕화면과 잠금 화면은 `~/Pictures` 아래 배경 모음 폴더의 파일입니다. 폴더를 옮기거나 이름을 바꾸면 배경이
  풀립니다. 같은 모음이 NAS 의 `ljlee/10-Media/Photos` 아래에도 있습니다.
- **Dolphin**: `kdeglobals` 의 `[PreviewSettings] MaximumRemoteSize=52428800` 으로 원격 파일도 50 MiB 까지 미리보기를
  만듭니다.
- **키보드**: 오른쪽 Alt 를 한/영 키로 씁니다(`kxkbrc` 의 `[Layout] Options=korean:ralt_hangul`, `ResetOldOptions=true`,
  `Use=true`, `plasma.sh` 가 정함). 그 전에는 한/영 전환이 KRunner 를 열었습니다. KWin 은 `kwriteconfig6 --notify` 로 값이
  실제로 바뀔 때만 다시 읽습니다. 값이 같으면 빈 값으로 바꿨다가 되돌립니다.

## settingfiles(닷파일)

- `~/gitRepos/settingfiles` 는 공개 저장소의 `arch` 브랜치 사본입니다. 이 기기에는 GitHub 로그인이 없어 push 하지 않습니다.
- 닷파일(`.zshrc`, `init.vim`, Ghostty, herdr, tmux)은 이 저장소를 가리키는 링크입니다. 여기서 고치지 않습니다. 바꿀 것은
  사용자에게 말씀드리고, 컨트롤 노드에서 고친 뒤 이 기기는 `git pull` 하고 필요하면 `zsh set.sh` 를 다시 돌립니다.
- `set.sh` 는 패키지를 깔지 않습니다. 필요한 명령(git, curl, nvim, tmux, pnpm, fastfetch)이 base 프로필에 있습니다.
- 이 파일과 Claude Code mod 는 `ljgaming/install.sh` 가 깝니다. `git pull` 뒤에 다시 돌리면 이 파일이 새 판이 됩니다.
  mod 는 저장소의 `claude-mods/` 폴더에서 바로 읽으므로 pull 만으로 새 세션부터 새 판입니다.
- `git pull` 은 커밋 서명을 확인합니다(2026-11-19, `ljgaming/install.sh` 가 `~/.config/git/allowed_signers` 와
  `merge.verifySignatures` 를 둠, 토큰 A, B 의 공개 키는 저장소의 `git-allowed-signers`). 서명이 없거나 모르는 키라서 pull 이
  멈추면 우회하지 말고 사용자에게 알립니다. `allowed_signers` 는 저장소 파일이 바뀌어도 저절로 바꾸지 않습니다.
- GitHub 는 로그인 없이 받을 수 있는 공개 저장소만 클론합니다. 비공개 저장소의 내용이 필요해 보이면 멈추고 사용자에게
  말씀드립니다.

## 세션 보드

`session-board` mod 가 세션의 목표, 진행중, 기다림, 남음, 완료를 대화 옆 pane 에 보여 줍니다. pane 이 화면에
없으면 프롬프트 위 한 줄로 보여 줍니다. 내용은 Claude 가 `mcp__session-board__update` 로 적습니다. `usage-meter` mod 는
프롬프트 아래 상태줄에 사용량을 띄웁니다. 두 mod 는 컨트롤 노드와 같은 것입니다.

- 사소하지 않은 작업은 시작할 때 목표와 완료 기준을 적고, 계획이 승인되면 항목으로 풉니다.
- 항목 상태가 바뀌면 바로 갱신합니다. 완료에는 근거(명령 결과, 로그, 경로)를 붙입니다.
- 기다리는 항목에는 누구를 기다리는지(사용자, 다른 세션) 적습니다.
- 목표가 바뀌면 덮어쓰지 않고 새 목표(`startNewGoal`)로 올립니다.
- 보드는 세션 동안의 현황판입니다. 세션 뒤에도 남길 것은 원래 자리(`~/waydroid-setup-log.md`, `~/docs`)에 따로 적습니다.
- 이 도구가 없는 세션(비대화형 실행, mod 가 설치되지 않은 때)에서는 이 절을 건너뜁니다.
- 터미널이 144칸보다 좁으면 pane 이 저절로 열리지 않습니다. 사용자에게 `/board` 를 한 번 입력하면 열린다고
  알립니다.

## 알게 된 것은 컨트롤 노드의 llm-wiki 로 보냅니다

사용자의 개인 위키(llm-wiki, 비공개)는 이 기기에 없습니다. 조사 결과, 사건의 원인과 해결, 결정의 근거처럼 남길 만한
것이 생기면 후보(자료, 한 줄 이유)로 사용자에게 말씀드립니다. 넣는 일은 컨트롤 노드에서 합니다.

## Arch 위키는 오프라인 사본을 먼저 봅니다

wiki.archlinux.org 는 봇 차단(Anubis)으로 WebFetch 를 거절하곤 하므로, 이 기기의 사본(`arch-wiki-docs`, `arch-wiki-lite`)을
먼저 봅니다.

- 찾기: `wiki_width=100 wiki-search <낱말>`. `wiki_width` 를 주면 dialog 메뉴 없이 목록만 찍습니다. 한국어 문서는
  `wiki_lang=ko` 를 함께 줍니다.
- 읽기: 바로 앞 검색의 번호로 `wiki-search <번호>`, 또는 `w3m -dump /usr/share/doc/arch-wiki/html/en/<제목>.html`
  (제목의 빈칸은 `_`).
- 답할 때 사본의 판(`pacman -Q arch-wiki-docs`)을 함께 말합니다. 그 뒤에 바뀌었을 수 있는 내용(패키지 판, 드라이버
  지원)이 결론을 좌우하면 사용자에게 온라인 위키 확인을 부탁합니다.

## 그 밖에

- **소리**: FX-AUDIO-D802C(USB DAC)는 24bit/96kHz 로 고정입니다. 다른 장치는 각자 최대 레이트를 씁니다. 바꿀 때는
  `audio-rate`(앱 "오디오 샘플레이트")를 씁니다. 규칙은 `~/.config/wireplumber/wireplumber.conf.d/60-audio-rate.conf`
  에 있습니다.
  절전 복귀 뒤 D802C 가 백색소음을 내서, `/etc/systemd/system/ljlee-pipewire-resume.service` 가 복귀 2초 뒤 사용자
  PipeWire 를 다시 시작합니다.
- **herdr**: `~/.local/bin/herdr` 에 있고 Claude 통합이 깔려 있습니다. 설정은 settingfiles 의 `herdr-config` 링크입니다.
- **GPU 사용량**은 nvtop(settingfiles 의 gpu-nvidia 프로필)이나 nvidia-smi 로 봅니다. htop 의 GPU 미터는 `/proc/*/fdinfo` 의 `drm-engine-*` 를 더하는데
  NVIDIA 드라이버는 그 키를 내지 않아 늘 0 입니다.
- **네트워크**: iPhone, iPad, 컨트롤 노드가 이 기기와 같은 서브넷에 있습니다(사용자 2026-11-17).
- **NAS**: main-server 의 NAS 는 IKEv2 VPN 연결 "main-server VPN"(networkmanager-strongswan, EAP 사용자 ljlee,
  비밀번호는 저장하지 않음)을 켠 뒤 SMB 로 봅니다. 공유는 public, ljlee, timemachine-ljlee 입니다. 주소는
  NetworkManager 연결 정보에 있습니다(공개 저장소라 여기 적지 않음).
- **비밀값**: Wi-Fi 비밀번호와 로그인 정보는 출력하거나 문서에 적지 않습니다.
