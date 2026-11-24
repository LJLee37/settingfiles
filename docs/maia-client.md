# 체스 프로그램을 main-server 의 Maia 엔진에 붙이기 (maia-client.sh)

작성: 2026-11-24, LJTF 의 Claude Code(사용자 지시: "서버 주소 없이 기록 가능한 만큼은 settingfiles에도 남긴 후 문서를 작성하라").
처음 적용한 기기는 LJTF(2026-11-24)입니다. 서버 쪽(엔진 설치, VPN 안 TCP, 실측)은 server-automation README 의
「Maia-3 엔진 (maia_engine)」 절에 있습니다.

## 무엇을, 왜

- main-server 에 사람처럼 두는 체스 엔진 Maia-3 이 있습니다. 레이팅(Elo)을 받아 그 수준의 사람이 둘 법한 수를 확률대로
  뽑으므로 사람 같은 실수도 섞습니다. 엔진은 SSH 실행이나 TCP 연결 때만 뜨고 상주하지 않습니다.
- 이 기기의 체스 프로그램은 엔진 명령으로 `ssh main-server maia-human <모델> <Elo>` 를 씁니다. 엔진은 main-server 의
  그래픽카드에서 돌고, 이 기기와는 UCI 대화만 SSH 로 오갑니다. 모델은 `79m`(기본)과 `5m`, 아무것도 주지 않으면 `79m 700` 입니다.
- 서버 주소와 VPN 주소는 이 저장소에 두지 않습니다. 기기마다 처음 한 번 넣습니다.

## maia-client.sh 가 하는 것

1. **SSH 연결 재사용**: `~/.ssh/config` 맨 뒤에 관리 블록(`# >>> settingfiles: maia-client.sh >>>`)을 두고
   `main-server` 별칭에 `ControlMaster auto`, `ControlPath ~/.ssh/cm-%C`, `ControlPersist 4h` 를 줍니다.
   - **왜:** 체스 프로그램은 판마다 엔진을 새로 띄웁니다(ssh 한 번). main-server 로그인에 토큰 터치가 필요하면(그날 사용자
     인증서가 없을 때) 판마다 터치해야 합니다. 첫 접속이 연결을 4시간 열어 두고, 그 뒤의 접속은 그 연결을 다시 씁니다.
   - **대가:** 연결이 열린 4시간 동안은 이 사용자로 도는 프로그램이 터치 없이 main-server 에 붙을 수 있습니다. 자리를 뜨기
     전에 닫으려면 `ssh -O exit main-server`, 열려 있는지는 `ssh -O check main-server` 로 봅니다.
   - **주소:** 별칭이 아직 주소로 풀리지 않으면 처음 한 번 묻습니다(`MAIN_SERVER_HOST=<주소> ./maia-client.sh` 로 줄 수도
     있음). 주소는 그 기기의 `~/.ssh/config` 에만 남습니다. 다른 블록이 이미 주소를 주면 묻지 않고 `HostName` 도 두지 않습니다.
   - **키:** 어느 키로 붙는지는 다루지 않습니다. 컨트롤 노드는 server-automation 의 `ssh-cert-setup.sh` 관리 블록(그날
     인증서 먼저, 없으면 토큰 A)이 정하고, 다른 기기는 그 기기의 블록이 정합니다.
   - **함정:** ssh 는 키워드마다 처음 본 값을 씁니다. 위쪽 블록(예: `Host *`)이 `ControlMaster` 를 먼저 정하면 이 블록은 듣지
     않습니다. 스크립트가 마지막에 `ssh -G main-server` 로 실제 값을 확인해 알려 줍니다.
2. **Knights 엔진**: Knights 가 깔려 있으면 Elo 마다 엔진을 하나씩 넣습니다(기본 `Maia 500`, `Maia 700`, `Maia 900`).
   - Knights 에는 엔진 옵션을 바꾸는 화면이 없어(KDE 버그 494243) Elo 를 명령에 넣고, Elo 마다 엔진을 따로 둡니다.
   - 엔진 목록은 `~/.config/knightsrc` 의 `[Protocols]` `engineConfigurations` 에 `이름:명령:프로토콜` 을 쉼표로 이어 둡니다.
     이름이 `Maia ` 로 시작하는 항목만 이 스크립트가 맡고, 나머지 엔진은 그대로 둡니다.
   - Knights 가 켜져 있으면 바꾸지 않습니다(켜진 채 바꾸면 Knights 가 끝날 때 덮어씀).
   - Knights 는 이 저장소의 프로필에 없습니다. 쓰려면 `sudo pacman -S knights` 뒤 다시 돌립니다.
   - 다른 Elo 나 모델: `MAIA_ELOS="600 800" ./maia-client.sh`, `MAIA_MODEL=5m ./maia-client.sh`.

## 쓰는 법

```bash
./maia-client.sh --check   # 아무것도 바꾸지 않고 상태만
./maia-client.sh           # 처음이면 main-server 주소를 한 번 물음
```

Knights 의 새 게임에서 상대를 컴퓨터로, 엔진을 `Maia 700` 처럼 고릅니다. 엔진이 뜨는 데 몇 초(대부분 PyTorch 를 불러오는
시간) 걸립니다.

엔진만 따로 시험하려면(체스 프로그램 없이):

```bash
(printf 'uci\nisready\nucinewgame\nposition startpos moves e2e4\ngo movetime 1000\n'; sleep 10; printf 'quit\n') |
  ssh main-server maia-human 79m 700 | grep -E 'id name|uciok|readyok|bestmove'
```

`id name Maia3`, `uciok`, `readyok`, `bestmove ...` 넷이 나오면 됩니다.

## 이 스크립트가 다루지 않는 것

- **GNOME Chess**: `~/.config/gnome-chess/engines.conf` 에 `protocol=uci`, `binary=ssh`, 난이도마다
  `arg-<easy|normal|hard>-N`(별칭, `maia-human`, 모델)과 `option-<난이도>-0=Elo 700` 을 적습니다. 이 파일이 있으면 시스템
  파일(`/etc/gnome-chess/engines.conf`)을 읽지 않으므로 다른 엔진도 쓰려면 시스템 파일을 복사해 덧붙입니다.
- **명령을 띄울 수 없는 앱**(Android 의 DroidFish 같은 네트워크 엔진): VPN 에 붙은 뒤 main-server 의 VPN 서비스 주소, 포트
  9779 로 붙습니다. 기본은 `79m`, Elo 700 이고, Elo 는 UCI 옵션 `Elo` 로 바꿉니다. 동시에 2개까지 붙고 6시간이 넘은 연결은
  거둡니다. 엔진에 인증이 없어 VPN 안에서만 받습니다.

## 되돌리기

- SSH: `~/.ssh/config` 에서 `# >>> settingfiles: maia-client.sh >>>` 부터 `# <<< settingfiles: maia-client.sh <<<` 까지 지우고
  `ssh -O exit main-server`. 스크립트가 바꿀 때마다 `~/.ssh/config.bak-maia-<시각>` 을 남깁니다.
- Knights: 설정의 엔진 목록에서 지우거나, `knightsrc` 의 `Maia ` 항목을 지웁니다.

## 기록

- 2026-11-24 LJTF: `79m` 500, 700, 900 을 넣고, 위 시험이 `bestmove` 를 돌려줌. 연결 재사용 확인(`ssh -O check` 에
  `Master running`).
