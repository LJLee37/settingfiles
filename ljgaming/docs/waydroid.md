# LJGaming WayDroid 구성 (원스토어용)

작성: 2026-11-18, LJGaming 의 Claude Code. 사용자 결정으로 WayDroid 는 settingfiles 프로필로 만들지 않고 이 문서로 남깁니다
(설치 뒤 관리자 권한 설정과 결정할 것이 많아서). 계획과 경과는 `dualboot-waydroid-plan.md` 3, 4단계, 시행착오는 `ljgaming-trial-and-error.md`
8절, 명령과 결과의 원본은 `~/waydroid-setup-log.md` 의 "(7)" 이후입니다.

## 지금 상태 (2026-11-18)

- **동작:** 원스토어 설치와 로그인, 게임 실행, ONE pay 결제와 혜택(페이백) 표시까지 정상(사용자). 계획의 목표를 달성했습니다.
- **구성:** waydroid-nvidia-bin 0.2.0(AUR) `--mode venus`, Plasma 6 Wayland 세션, LineageOS 20 **GAPPS**(안드로이드 13), ARM 번역 libhoudini,
  창 1280x720 고정.
- **안 되는 것:** 소리(사용자가 미룸, 원인 미조사). 창을 끌어서 크기 바꾸기(venus 모드의 한계).
- **재부팅 뒤(2026-11-19 확인):** 컨테이너가 부팅 때 저절로 뜨고 wd-venus 도 active. 부팅 직후에는 binder 가 없고
  `waydroid session start` 때 binderfs 를 올리고 링크를 만들어 안드로이드가 부팅함(#45 는 이 기기에 해당 없음). 창 속성도 그대로.
- **확인 안 한 것:** GLES 렌더러 문자열(`nvidia-smi` 로 GPU 사용만 확인).

## 왜 이 조합인가

| 결정 | 이유 |
| --- | --- |
| waydroid-nvidia(기본 waydroid 아님) | 안드로이드를 RTX 2080 에서 렌더링. 기본 waydroid 는 NVIDIA 에서 소프트웨어 렌더링 |
| `--mode venus` | v0.2.0 의 기본 모드(nvidia-prolapse)가 드라이버 620.70.06 을 거부(이슈 #41) |
| Plasma(GNOME 아님) | GNOME(Mutter)에서는 hwcomposer 가 죽어 앱이 안 뜸(#21) |
| GAPPS(VANILLA 아님) | 원스토어가 Google 서비스 없이는 작동하지 않음(사용자 2026-11-18) |
| libhoudini | 원스토어 서비스 APK 는 ARM 라이브러리뿐. Intel CPU 라 Arch 위키가 libhoudini 를 권함 |

## 다시 깔 때의 순서

root 작업은 한 스크립트로 묶어 `pkexec /usr/bin/bash <스크립트>` 로 돌립니다(토큰을 먼저 꽂음, settingfiles 의 `docs/pam-u2f.md`). AUR 은 헬퍼 없이 받아
PKGBUILD 를 사용자에게 보여 승인받습니다. 2026-11-18 의 스크립트는 `~/install-logs/root-20261118-waydroid*.sh`, `-libhoudini.sh` 입니다.

1. **패키지:** 공식 저장소 `lxc python-gbinder dnsmasq`(--asdeps). AUR `waydroid-nvidia-bin` 을 사용자 권한으로 `makepkg` 한 뒤 `pacman -U`.
   배포판 `waydroid` 가 깔려 있으면 먼저 지웁니다(대체 관계).
2. **방화벽:** nftables `inet filter` 의 input 과 forward 정책이 drop 이라 아래를 더합니다. waydroid-net 이 자기 표(`inet lxc`, `ip lxc` NAT)를 만들어도
   우리 표의 drop 이 이깁니다.
   ```
   # chain input
   iifname "waydroid0" udp dport { 53, 67 } accept comment "WayDroid: DNS and DHCP (dnsmasq on the waydroid0 bridge)"
   iifname "waydroid0" tcp dport 53 accept comment "WayDroid: DNS over TCP"
   # chain forward (policy drop)
   iifname "waydroid0" accept comment "WayDroid: container to the network (masqueraded by waydroid-net)"
   oifname "waydroid0" ct state { established, related } accept comment "WayDroid: replies only, nothing new into the container"
   ```
3. **설정과 이미지:** `waydroid init -s GAPPS` 뒤 `waydroid-nvidia-setup --mode venus`(root). setup 이 `waydroid init` 을 직접 부르기도 하므로, VANILLA 로
   이미 받았다면 `waydroid init -f -s GAPPS` 를 하고 setup 을 다시 돌립니다(앱과 데이터, libhoudini 는 남음). 결과 cfg:
   `nvidia_driver_mode=venus`, `nvidia_native_gl=off`, `drm_device=/dev/dri/renderD128`, `suspend_action=none`.
4. **렌더러(사용자):** `systemctl --user enable --now wd-venus.service`(소켓 `/run/waydroid-venus/venus.sock`).
5. **ARM 번역:** AUR `python-inquirerpy`(의존성)와 `waydroid-script-git` 를 빌드. waydroid-script-git 은 source 가 git HEAD 라, 검토한 상류 커밋으로
   고정합니다(`source=("git+${url}.git#commit=4a50dab")`). 그다음 root 로 `waydroid-extras -a 13 install libhoudini`.
   - 이 스크립트는 `/var/lib/waydroid/overlay/system` 에 libhoudini 를, waydroid.cfg [properties] 에 abilist, native.bridge 등 7개를 넣고,
     공통으로 resetprop(Magisk 도구) 바이너리도 overlay 에 넣습니다.
   - libhoudini.zip 은 사용자 권한으로 `~/.cache/waydroid-script/downloads/` 에 미리 받아 md5 를 맞춰 두면 root 가 내려받지 않습니다.
6. **세션과 창(사용자):** `waydroid session start`, 그다음 `waydroid show-full-ui`(또는 앱 메뉴의 Waydroid). 창 크기는 세션을 시작할 때 정해지므로
   먼저 정해 둡니다:
   ```bash
   waydroid prop set persist.waydroid.width 1280
   waydroid prop set persist.waydroid.height 720
   waydroid prop set persist.waydroid.window_decorations true   # 제목 표시줄(창을 끌어 옮김)
   ```
   바꾼 뒤에는 `waydroid session stop` 하고 다시 엽니다.
7. **Google 기기 등록:** GApps 로그인 뒤 "Play Protect 인증 안 됨"이면, GSF 의 android_id 를 https://www.google.com/android/uncertified 에
   등록합니다(Google 이 커스텀 ROM 용으로 둔 공식 절차, 사용자가 함). 값은 `~/.local/share/waydroid/data/data/com.google.android.gsf/databases/gservices.db`
   의 `main` 표 `android_id`(root 로 읽고, -wal, -shm 과 같이 사본을 떠서 읽음). 등록 뒤 반영까지 시간이 걸릴 수 있습니다.
8. **원스토어:** 브라우저 다운로드가 안 되면 공식 주소를 안드로이드 UA 로 받습니다(302 로 공식 farm71.ids.onestore.co.kr).
   - 클라이언트 앱: `https://m.onestore.co.kr/mobilepoc/binary/download.omp?type=V01`, 받는 파일 `ONEstoreClient_SKT_v<판>.apk`(com.skt.skaf.A000Z00040)
   - 원스토어 서비스: 같은 주소의 `type=OSQ`, 받는 파일 `ONEstore_service_v<판>.apk`(com.skt.skaf.OA00018282, 런처 없음, ARM 전용)
   - 둘 다 SK Telecom 인증서(SKT Signed System Level3)로 서명. 미러 APK 는 쓰지 않습니다. 설치는 `waydroid app install <apk>`(출력 없이 끝남).
   - 로그인, 게임, 결제는 사용자가 합니다.

## 지킬 것 (계획 문서의 규칙)

- 루팅(Magisk), 기기 정보 위조, 보안 검사 우회는 하지 않습니다. 원스토어가 "보안 취약 단말"로 막으면 멈추고 Windows 원게임루프로 씁니다.
- 커널이나 NVIDIA 드라이버를 올린 뒤에는 `waydroid-nvidia-setup --mode venus` 를 다시 돌립니다(root).

## 되돌리기

- 데이터 초기화: `waydroid session stop`, root 로 `systemctl stop waydroid-container`, `rm -rf ~/.local/share/waydroid`,
  `rm -rf /var/lib/waydroid/overlay*`, `waydroid init -f -s GAPPS`, `waydroid-nvidia-setup --mode venus`. 앱과 로그인이 모두 사라집니다.
- cfg 백업: `/var/lib/waydroid/waydroid.cfg.bak-20261118-pre-houdini`, `waydroid.cfg.bak-20261118-pre-gapps`. 방화벽 백업: `/etc/nftables.conf.bak-20261118-pre-waydroid`.
- 패키지는 snapper 로도 되돌릴 수 있습니다(2026-11-18: 43, 44 의존성, 45, 46 waydroid-nvidia-bin, 51~54 libhoudini 도구).
