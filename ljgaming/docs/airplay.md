# LJGaming AirPlay 수신기 구성

작성: 2026-11-18, LJGaming 의 Claude Code. 사용자 결정으로 AirPlay 는 settingfiles 프로필로 만들지 않고 이 문서로 남깁니다. 공식 저장소 판이
오래돼 직접 빌드한 패키지를 쓰고, 설정이 이 기기의 DAC 와 방화벽에 묶여 있기 때문입니다. 저장소 판이 5.5.2 이상으로 올라오거나 두 번째 수신기를
만들 때 프로필로 옮길지 다시 정합니다. 조사와 계획은 `airplay-receiver-setup.md`, 시행착오는 `ljgaming-trial-and-error.md` 6절, 원본 기록은
`~/waydroid-setup-log.md` 입니다.

## 지금 상태 (2026-11-18)

- AirPlay 2 수신기 **"LJGaming" 하나**(사용자 결정). 클래식 AirPlay 설정(`classic.conf`, `shairport-sync-classic.service`)은 꺼진 채 남겨 둠.
- 경로: iPhone(iOS 27 은 AirPlay 2 에 AAC 48 kHz 를 보냄)에서 shairport-sync 의 PipeWire 백엔드를 거쳐 FX-AUDIO-D802C(USB DAC, 24bit/96 kHz 고정)로.
  볼륨은 늘 100%이고 소리 크기는 DAC 에서 조절합니다(사용자 결정).
- 1시간 시험 통과(2026-11-18 16:16~17:16, xrun 증가 0, 경고 0, `~/install-logs/airplay-1h-test-20261118.tsv`).
- 남은 확인: 로그아웃 뒤 다시 로그인했을 때 저절로 돌아오는지, 절전에서 깨어났을 때 D802C 잡음이 저절로 풀리는지.

## 구성 요소

| 무엇 | 어디 | 메모 |
| --- | --- | --- |
| shairport-sync 5.6.3-1 | 직접 빌드, `~/build/shairport-sync` | Arch 공식 PKGBUILD(5.0.4-4)에서 판만 올림. 5.0.4 에는 5.5 보안 수정과 5.5.2 Apple OS 27 호환 수정이 없음 |
| nqptp 1.2.9-1 | 직접 빌드, `~/build/nqptp` | shairport-sync 5.6 의 공유 메모리 인터페이스(smi11)에 맞춤. 시스템 서비스 `nqptp.service` 켬 |
| avahi-daemon | 시스템 서비스 켬 | mDNS 광고 |
| shairport-sync | **사용자 서비스** `shairport-sync.service` | 시스템 유닛은 끔. 사용자 설정 파일을 쓰도록 drop-in |
| 설정 | `~/.config/shairport-sync/shairport-sync.conf` | 아래 표 |
| 샘플레이트 | `audio-rate`(`/usr/local/bin/audio-rate`, 앱 "오디오 샘플레이트") | 규칙 `~/.config/wireplumber/wireplumber.conf.d/60-audio-rate.conf`. D802C 96 kHz S24_3LE 고정, 다른 장치는 최대 |
| 절전 복귀 | `/etc/systemd/system/ljlee-pipewire-resume.service` | 복귀 2초 뒤 ljlee 의 pipewire, pipewire-pulse, wireplumber 재시작(D802C 백색소음 해결). 수신기도 같이 재시작됨 |
| 방화벽 | `/etc/nftables.conf` 의 `lan_services` | LAN(사설, 링크 로컬) 출발지만 |

### PKGBUILD 에서 바꾼 것

- shairport-sync: `pkgver=5.6.3`, `pkgrel=1`, sha256 새 값. `--with-jack` 과 `jack` 의존성을 뺌(5.6 에서 Jack 백엔드 제거). makedepends 의 `vim` 을 `xxd` 로
  바꿈(tinyxxd 가 제공, 이 기기는 vim 을 지움).
- nqptp: `pkgver=1.2.9`, sha256 새 값.
- 빌드 순서: nqptp 를 먼저 설치한 뒤 shairport-sync 를 의존성 검사를 켠 채 빌드(`-d` 로 건너뛰지 않음). 빌드용 패키지는 빌드 뒤 지움.
- **보안 갱신은 직접 챙깁니다.** 저장소가 따라올 때까지 `pacman -Syu` 가 이 둘을 올려 주지 않습니다. 상류 릴리스를 보고 위 방법으로 다시 빌드합니다.

### shairport-sync.conf 의 요점

| 키 | 값 | 이유 |
| --- | --- | --- |
| `general.name` | `"LJGaming"` | iPhone 에 보이는 이름 |
| `service_type` | `"airplay2"` | 클래식 AirPlay 는 16bit/44.1 kHz 까지라 AirPlay 2 만 |
| `output_backend` | `"pipewire"` | PipeWire 를 거쳐 D802C 로 |
| `interpolation` | `"basic"` | 시간 보정은 프레임 하나를 넣거나 빼는 것뿐, 샘플 값은 리샘플하지 않음 |
| `ignore_volume_control` | `"yes"` | 늘 100%, 소리 크기는 DAC 에서 |
| `six_channel_mode`, `eight_channel_mode` | `"off"` | 스테레오 DAC. 서라운드를 광고하면 손실 AAC 로 옴 |
| `dbus_service_bus`, `mpris_service_bus` | `"session"` | 시스템 버스 정책은 shairport-sync 사용자만 이름을 가질 수 있음. 세션 버스라 데스크톱 미디어 컨트롤에 재생이 보임 |
| `pipewire.sink_target` | `alsa_output.usb-FX-AUDIO_FX-AUDIO-D802C-00.iec958-stereo` | 출력 장치 고정 |
| `diagnostics.log_verbosity` | `0` | 시험할 때는 2(들어오는 인코딩이 로그에 남음) |

### 사용자 서비스 drop-in (`~/.config/systemd/user/shairport-sync.service.d/`)

- `override.conf`: `ExecStart=/usr/bin/shairport-sync --log-to-syslog -c %h/.config/shairport-sync/shairport-sync.conf`. 패키지 유닛의 ExecStartPre
  (avahi-daemon, nqptp 가 active 인지)는 그대로.
- `10-follow-pipewire.conf`: `After=pipewire.service wireplumber.service`, `PartOf=pipewire.service`. 그리고
  `systemctl --user add-wants pipewire.service shairport-sync.service`. linger 가 켜져 있어 로그아웃해도 사용자 관리자가 남고,
  `default.target` 이 다음 로그인 때 다시 걸리지 않아서, PipeWire 가 뜰 때 같이 뜨게 한 것입니다.

### 방화벽 (LAN 출발지만, `lan_services` 체인)

```
udp dport 5353 accept comment "mDNS (avahi): .local names, printers"
tcp dport 7000 accept comment "AirPlay 2 RTSP (shairport-sync)"
udp dport { 319, 320 } accept comment "AirPlay 2 timing (nqptp)"
meta l4proto { tcp, udp } th dport 32768-60999 accept comment "AirPlay 2 event/data/control (shairport-sync binds ephemeral ports)"
```

shairport-sync 가 AirPlay 2 소켓을 임의 포트에 열기 때문에 마지막 줄이 필요합니다.

## 다시 깔 때의 순서

1. `~/build/nqptp`, `~/build/shairport-sync` 에서 위처럼 PKGBUILD 를 고쳐 빌드(nqptp 먼저). 설치는 root 스크립트로.
2. root: `systemctl enable --now avahi-daemon nqptp`, 방화벽 규칙, `ljlee-pipewire-resume.service` 설치와 enable.
3. 사용자: 설정 파일과 drop-in 두 개, `systemctl --user daemon-reload`, `systemctl --user add-wants pipewire.service shairport-sync.service`,
   `systemctl --user enable --now shairport-sync`. 샘플레이트는 `audio-rate` 로.
4. 확인: iPhone 에서 "LJGaming" 으로 재생, `pw-top` 에서 shairport-sync 노드가 D802C 로 가는지, `journalctl --user -u shairport-sync` 경고가 없는지.

## 되돌리기

- `systemctl --user disable --now shairport-sync`, 방화벽의 AirPlay 줄 지우기. 패키지는 snapper 로 되돌리거나 `pacman -R shairport-sync nqptp`.
