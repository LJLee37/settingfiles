#!/bin/bash
# server-automation 의 Claude Code mod(roles/agentic_coding/files/claude-mods)를 이 저장소의 claude-mods/ 로
# 복사합니다. 원본은 server-automation 입니다. 이 사본은 server-automation 을 받을 수 없는 기기(LJGaming, 공개
# 저장소만 받음)가 ljgaming/install.sh 로 등록해 씁니다(2026-11-17 사용자 결정). mod 를 고치면 이것을 돌리고
# 이 저장소에도 커밋합니다. install-control-node.sh 는 둘이 다르면 알립니다.
#
#   control-node/sync-claude-mods.sh          사본을 원본과 같게 맞춤
#   control-node/sync-claude-mods.sh --check  다른지만 봄(같으면 0, 다르면 1)
set -euo pipefail
HERE="$(dirname "$(dirname "$(readlink -f "$0")")")"
SRC="${SA:-$HOME/gitRepos/server-automation}/roles/agentic_coding/files/claude-mods"
DST="$HERE/claude-mods"
[ -d "$SRC" ] || { echo "원본이 없습니다: $SRC" >&2; exit 2; }
case "${1:-}" in
  --check) diff -r -q -x node_modules "$SRC" "$DST" ;;
  "")
    rsync -a --delete --exclude node_modules "$SRC/" "$DST/"
    diff -r -q -x node_modules "$SRC" "$DST"
    echo "맞춤: $DST (git -C \"$HERE\" status 로 바뀐 것을 보고 커밋하세요)" ;;
  *) sed -n 2,9p "$0"; exit 64 ;;
esac
