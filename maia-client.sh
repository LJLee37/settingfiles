#!/bin/bash
# 이 기기의 체스 프로그램을 main-server 의 Maia-3 체스 엔진(사람처럼 두는 엔진)에 붙입니다.
#
#   ./maia-client.sh          설정(이미 된 것은 건너뜀)
#   ./maia-client.sh --check  아무것도 바꾸지 않고 상태만 봄
#
# 1. ~/.ssh/config 에 main-server 별칭의 연결 재사용(ControlMaster)을 둡니다. 서버 주소는 이 저장소에 두지
#    않으므로, 별칭이 아직 주소로 풀리지 않으면 처음 한 번 묻습니다(MAIN_SERVER_HOST 로 줄 수도 있음).
# 2. Knights 가 깔려 있으면 Elo 마다 엔진을 하나씩 넣습니다(MAIA_ELOS, 기본 "500 700 900", 모델 MAIA_MODEL,
#    기본 79m). 무엇을 왜 하는지는 docs/maia-client.md 에 있습니다.
#
# 어느 키로 main-server 에 붙는지(키, 인증서)는 다루지 않습니다. 그것은 server-automation 의 ssh-cert-setup.sh
# 가 관리하는 ~/.ssh/config 블록이나 기기마다 둔 블록이 정합니다.
set -euo pipefail

ALIAS=main-server
MODEL="${MAIA_MODEL:-79m}"
read -r -a ELOS <<<"${MAIA_ELOS:-500 700 900}"
CONF="$HOME/.ssh/config"
BEGIN="# >>> settingfiles: maia-client.sh >>>"
END="# <<< settingfiles: maia-client.sh <<<"

CHECK=0
case "${1:-}" in
  --check) CHECK=1 ;;
  "") ;;
  *) sed -n 2,13p "$0"; exit 64 ;;
esac
[ "$(id -u)" -ne 0 ] || { echo "root 가 아니라 평소 사용자로 돌리세요" >&2; exit 1; }

step() { printf '\n== %s\n' "$*"; }
ok() { printf '   됨    %s\n' "$*"; }
todo() { printf '   필요  %s\n' "$*"; }
did() { printf '   바꿈  %s\n' "$*"; }
doing() { [ "$CHECK" -eq 0 ]; }

# --- 1. SSH 연결 재사용 ----------------------------------------------------------------
# 체스 프로그램은 판마다 엔진을 새로 띄우므로(ssh 한 번) 로그인에 토큰 터치가 필요하면 판마다 터치하게 됩니다.
# 첫 접속이 연결을 4시간 열어 두고 그 뒤의 접속은 그 연결을 다시 씁니다. 그 동안은 이 사용자로 도는 프로그램이
# 터치 없이 main-server 에 붙을 수 있으니, 자리를 뜨기 전에 닫으려면 ssh -O exit main-server.
step "SSH: $ALIAS 연결 재사용"
ssh_value() { ssh -G "$ALIAS" 2>/dev/null | awk -v k="$1" '$1 == k { print $2; exit }'; }
block_host() { awk -v b="$BEGIN" -v e="$END" '$0 == b { f = 1; next } $0 == e { f = 0 } f && $1 == "HostName" { print $2; exit }' "$CONF" 2>/dev/null; }

# 이 블록이 HostName 을 줄지: 이미 이 블록에 있으면 그대로, 다른 블록이 주소를 주면 두지 않음, 아니면 묻습니다.
host="${MAIN_SERVER_HOST:-$(block_host)}"
if [ -z "$host" ] && [ "$(ssh_value hostname)" = "$ALIAS" ] && doing; then
  if [ -t 0 ]; then
    read -rp "   $ALIAS 의 주소(도메인이나 IP, 이 저장소에는 남지 않음): " host || true
  fi
fi
want="$BEGIN
# 체스 엔진(maia-human)을 판마다 ssh 로 부르므로 연결을 4시간 열어 두고 다시 씁니다(settingfiles docs/maia-client.md).
# 바로 닫기: ssh -O exit $ALIAS
Host $ALIAS${host:+
    HostName $host}
    ControlMaster auto
    ControlPath ~/.ssh/cm-%C
    ControlPersist 4h
$END"
have=$(awk -v b="$BEGIN" -v e="$END" '$0 == b { f = 1 } f { print } $0 == e { f = 0 }' "$CONF" 2>/dev/null)
if [ "$have" = "$want" ]; then
  ok "~/.ssh/config 의 $ALIAS 블록"
elif doing; then
  if [ -z "$host" ] && [ "$(ssh_value hostname)" = "$ALIAS" ]; then
    todo "$ALIAS 의 주소를 모름: 터미널에서 다시 돌리거나 MAIN_SERVER_HOST=<주소> ./maia-client.sh"
  else
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    [ ! -f "$CONF" ] || cp -p "$CONF" "$CONF.bak-maia-$(date +%Y%m%d%H%M)"
    # 옛 블록을 빼고 새 블록을 맨 뒤에 붙입니다. ssh 는 키워드마다 처음 본 값을 쓰므로, 맨 위 블록들(키, 인증서)은
    # 그대로 먼저 읽힙니다.
    # 끝의 빈 줄은 지워, 다시 돌릴 때마다 빈 줄이 쌓이지 않게 합니다.
    { awk -v b="$BEGIN" -v e="$END" '$0 == b { f = 1; next } f && $0 == e { f = 0; next } !f' "$CONF" 2>/dev/null |
        sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' || true
      printf '\n%s\n' "$want"; } > "$CONF.new"
    chmod 600 "$CONF.new" && mv "$CONF.new" "$CONF"
    did "~/.ssh/config 의 $ALIAS 블록(백업 $CONF.bak-maia-*)"
  fi
else
  todo "~/.ssh/config 에 $ALIAS 블록이 없거나 다름"
fi
# 다른 블록이 먼저 다른 값을 주면 이 블록의 값은 쓰이지 않습니다.
if [ "$(ssh_value hostname)" = "$ALIAS" ]; then
  todo "$ALIAS 가 주소로 풀리지 않음"
elif [ "$(ssh_value controlmaster)" != auto ]; then
  todo "$ALIAS 의 ControlMaster 가 auto 가 아님(위쪽 블록이 먼저 정함): ssh -G $ALIAS 로 확인"
else
  ok "ssh -G $ALIAS: 주소 있음, ControlMaster auto, ControlPersist $(ssh_value controlpersist)초"
fi

# --- 2. Knights -----------------------------------------------------------------------
# Knights 는 엔진 목록을 knightsrc 의 [Protocols] engineConfigurations 에 "이름:명령:프로토콜" 을 쉼표로 이어
# 둡니다. 엔진 옵션을 바꾸는 화면이 없어(KDE 버그 494243) Elo 를 명령에 넣고 Elo 마다 엔진을 따로 둡니다.
# 이름이 "Maia " 로 시작하는 항목만 이 스크립트가 맡고, 나머지 엔진은 그대로 둡니다.
step "Knights 엔진"
if ! command -v knights >/dev/null; then
  ok "Knights 가 없어 건너뜀(쓰려면 sudo pacman -S knights 뒤 다시 실행)"
else
  maia=()
  for elo in "${ELOS[@]}"; do maia+=("Maia $elo:ssh $ALIAS maia-human $MODEL $elo:uci"); done
  cur=$(kreadconfig6 --file knightsrc --group Protocols --key engineConfigurations 2>/dev/null || true)
  keep=()
  IFS=',' read -r -a items <<<"$cur"
  for item in "${items[@]}"; do
    [ -n "$item" ] && [[ $item != "Maia "* ]] && keep+=("$item")
  done
  new=$(IFS=,; echo "${keep[*]+${keep[*]},}${maia[*]}")
  if [ "$cur" = "$new" ]; then
    ok "Maia ${ELOS[*]} ($MODEL)"
  elif pgrep -x knights >/dev/null; then
    todo "Knights 가 켜져 있음: 닫은 뒤 다시 실행(켜진 채 바꾸면 Knights 가 끝날 때 덮어씀)"
  elif doing; then
    kwriteconfig6 --file knightsrc --group Protocols --key engineConfigurations "$new"
    did "Maia ${ELOS[*]} ($MODEL)"
  else
    todo "Maia 엔진 없음 또는 다름"
  fi
fi

cat <<EOF

새 게임에서 상대를 컴퓨터로, 엔진을 "Maia <Elo>" 로 고릅니다. 첫 판은 ssh 로그인(인증서가 없으면 토큰 터치)이
있고, 그 뒤 4시간은 연결을 다시 씁니다. 엔진이 뜨는 데 몇 초 걸립니다.
EOF
