#!/usr/bin/env bash
# 이 컨트롤 노드에서 한 Claude Code 작업을 헤르메스 노드의 장부 시간 기록(cc-timelog)으로 보냅니다.
# install-control-node.sh 가 ~/.local/bin/cc-timelog-push 로 두고, user 타이머 cc-timelog-push.timer 가
# 30분마다 부릅니다(hosts/*.env 의 CONTROL_CC_TIMELOG_PUSH=yes 인 기기만, 2026-10-26 사용자 결정).
#
# server-automation clone 의 cc-activity 로 지난 7일의 turn 목록(시각, cwd, 세션 id, 세션 제목. 프롬프트
# 내용은 없음)을 JSON 으로 뽑아, 노드마다 ~/.local/state/hermes-cc-timelog/inbox/<이 기기 이름>.json 에 ssh
# 로 씁니다(임시 파일에 쓴 뒤 mv). 노드의 22:30 하루 마무리가 그 파일을 검사해 노드의 작업과 합칩니다
# (server-automation roles/hermes_agent/templates/timelog-context.sh.j2).
#
# 늘 0 으로 끝냅니다. 인증서가 끝났거나 노드가 꺼져 있으면 그 노드만 건너뛰고 다음 차례에 다시 보냅니다.
# 노드는 7일 안의 turn 이면 늦게 와도 받습니다.
#
# 환경변수: CC_ACTIVITY(cc-activity 경로), CC_TIMELOG_NODES(보낼 노드, 빈칸으로 구분),
#   CC_TIMELOG_NAME(파일 이름, 기본은 이 기기의 호스트 이름), CC_TIMELOG_DAYS(기본 7), SSH(시험용)
set -uo pipefail

CC_ACTIVITY="${CC_ACTIVITY:-$HOME/gitRepos/server-automation/roles/hermes_agent/files/scripts/cc-activity}"
NODES="${CC_TIMELOG_NODES:-server.ljlee37.com rpi.ljlee37.com}"
NAME="${CC_TIMELOG_NAME:-$(cat /etc/hostname 2>/dev/null)}"
DAYS="${CC_TIMELOG_DAYS:-7}"
SSH="${SSH:-ssh}"
INBOX=.local/state/hermes-cc-timelog/inbox   # 받는 노드의 홈 기준

if [ ! -x "$CC_ACTIVITY" ]; then
  echo "cc-activity 가 없어 보내지 않음: $CC_ACTIVITY"
  exit 0
fi
# 노드가 받는 이름 규칙과 같습니다. 파일 이름이 되고 원격 명령에 그대로 들어가므로 먼저 확인합니다.
if ! [[ "$NAME" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,31}$ ]]; then
  echo "기기 이름이 영문, 숫자, - 로 된 32자 이하가 아니어서 보내지 않음: '$NAME'"
  exit 0
fi

doc=$(mktemp "${TMPDIR:-/tmp}/cc-timelog-push.XXXXXX") || { echo "임시 파일을 만들지 못해 보내지 않음"; exit 0; }
trap 'rm -f "$doc"' EXIT
# cc-activity 의 경고(transcript 형식이 바뀐 듯함 등)는 stderr 로 나와 이 유닛의 journal 에 남습니다.
if ! "$CC_ACTIVITY" turns --since "$(date -d "$DAYS days ago" -Iseconds)" --until "$(date -Iseconds)" \
    --host "$NAME" >"$doc"; then
  echo "cc-activity turns 가 실패해 보내지 않음(server-automation clone 이 turns 전 판이면 pull 하세요)"
  exit 0
fi
turns=$(python3 -c 'import json, sys; print(len(json.load(sys.stdin)["turns"]))' <"$doc" 2>/dev/null || echo "?")

# 그 노드에 쓰는 사용자 인증서(ssh -G 의 certificatefile)가 있는데 모두 끝났으면 붙지 않습니다. 붙어 봐야
# 노드에 인증 실패 기록만 남깁니다. 인증서를 쓰지 않는 설정이면 그냥 붙어 봅니다.
cert_ok() {  # cert_ok <노드>
  local f to now seen=0
  now=$(date +%Y-%m-%dT%H:%M:%S)
  while read -r f; do
    f="${f/#\~/$HOME}"
    [ -r "$f" ] || continue
    seen=1
    to=$(ssh-keygen -L -f "$f" 2>/dev/null | sed -n 's/^ *Valid: forever$/forever/p; s/^ *Valid: from .* to \(.*\)$/\1/p')
    if [ "$to" = forever ] || [[ -n "$to" && "$to" > "$now" ]]; then
      return 0
    fi
  done < <("$SSH" -G "$1" 2>/dev/null | sed -n 's/^certificatefile //p')
  [ "$seen" -eq 0 ]
}

for node in $NODES; do
  if ! cert_ok "$node"; then
    echo "$node: 사용자 인증서가 끝나 건너뜀(ssh-cert-issue.sh 로 새로 받으면 다음 차례에 보냄)"
    continue
  fi
  # BatchMode 라 묻지 않고 실패합니다. sk(FIDO2) 알고리즘을 빼서, 인증서로 안 될 때 ~/.ssh/config 의 토큰
  # 키로 넘어가 터치를 기다리지 않게 합니다. 한 노드가 실패해도 다음 노드로 갑니다.
  err=$("$SSH" -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=10 -o ServerAliveCountMax=3 \
      -o 'PubkeyAcceptedAlgorithms=-sk-*,webauthn-sk-*' "$node" \
      "umask 077 && mkdir -p $INBOX && cat >| $INBOX/$NAME.json.tmp && mv -f $INBOX/$NAME.json.tmp $INBOX/$NAME.json" \
      <"$doc" 2>&1 >/dev/null)
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "$node: turn ${turns}개 보냄"
  else
    echo "$node: 못 보냄(종료 $rc: $(printf '%s\n' "$err" | tail -n 1)), 다음 차례에 다시 보냄"
  fi
done
exit 0
