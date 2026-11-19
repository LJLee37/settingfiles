#!/bin/bash
# LJGaming(게이밍 데스크탑)의 Claude Code 설정을 깔고, 다시 돌리면 최신으로 맞춥니다(2026-11-17 사용자 결정).
# 이 기기는 server-automation 이 관리하지 않고 공개 저장소만 받으므로 이 저장소에 있는 것을 씁니다.
#   - ~/.claude/CLAUDE.md 를 ljgaming/CLAUDE.md 에서 복사합니다.
#   - Claude Code mod(usage-meter, session-board)는 claude-mods/(server-automation 원본의 사본)를 로컬 폴더
#     마켓플레이스로 등록해 user scope 로 깝니다. 폴더에서 바로 읽으므로 git pull 하면 새 세션부터 새 판입니다.
#   - 이 clone 의 git pull 이 커밋 서명(토큰 A, B)을 확인하게 합니다(2026-11-19).
#
#   ljgaming/install.sh          설치와 갱신(이미 된 것은 건너뜀)
#   ljgaming/install.sh --check  아무것도 바꾸지 않고 상태만 봄
#
# sudo 는 쓰지 않습니다. 평소 사용자로 돌립니다.
set -euo pipefail
HERE="$(dirname "$(dirname "$(readlink -f "$0")")")"

CHECK=0
case "${1:-}" in
  --check) CHECK=1 ;;
  "") ;;
  *) sed -n 2,12p "$0"; exit 64 ;;
esac
[ "$(id -u)" -ne 0 ] || { echo "root 가 아니라 평소 사용자로 돌리세요" >&2; exit 1; }

step() { printf '\n== %s\n' "$*"; }
ok() { printf '   됨    %s\n' "$*"; }
todo() { printf '   필요  %s\n' "$*"; }
did() { printf '   바꿈  %s\n' "$*"; }
doing() { [ "$CHECK" -eq 0 ]; }

# --- 1. 전역 CLAUDE.md --------------------------------------------------------------
# 손으로 둔 다른 파일(이 스크립트 이름이 없는 것)은 덮어쓰지 않고 알립니다. install-control-node.sh 10절과 같습니다.
step "전역 CLAUDE.md (~/.claude/CLAUDE.md)"
claude_md="$HOME/.claude/CLAUDE.md"
if cmp -s "$HERE/ljgaming/CLAUDE.md" "$claude_md"; then
  ok "$claude_md"
elif [ -e "$claude_md" ] && ! grep -q 'ljgaming/install.sh' "$claude_md"; then
  todo "$claude_md 가 손으로 둔 파일이라 덮어쓰지 않음(ljgaming/CLAUDE.md 와 합쳐 주세요)"
elif doing; then
  install -D -m 644 "$HERE/ljgaming/CLAUDE.md" "$claude_md"
  did "$claude_md (새 세션부터)"
else
  todo "$claude_md 없음 또는 다름"
fi

# --- 2. Claude Code mod -------------------------------------------------------------
# install-control-node.sh 8절과 같고, 마켓플레이스 폴더만 이 저장소의 사본입니다.
step "Claude Code mod"
mods="$HERE/claude-mods"
claude_version=$(claude --version 2>/dev/null | awk '{print $1}' || true)
if [ -z "$claude_version" ] || [ "$(printf '%s\n' 2.1.287 "$claude_version" | sort -V | head -1)" != 2.1.287 ]; then
  todo "claude ${claude_version:-없음} 은 mod 를 돌리지 못함(2.1.287 이상 필요)"
else
  has_name() {  # json-on-stdin key value
    python3 -c 'import json,sys; sys.exit(0 if any(x.get(sys.argv[1]) == sys.argv[2] for x in json.load(sys.stdin)) else 1)' "$1" "$2"
  }
  if claude plugin marketplace list --json | has_name name local-mods; then
    ok "마켓플레이스 local-mods"
  elif doing; then
    claude plugin marketplace add "$mods" >/dev/null && did "마켓플레이스 local-mods ($mods)"
  else
    todo "마켓플레이스 local-mods 등록 안 됨"
  fi
  for mod in usage-meter session-board; do
    if claude plugin list --json | has_name id "$mod@local-mods"; then
      ok "$mod"
    elif doing; then
      claude plugin install "$mod@local-mods" --scope user >/dev/null && did "$mod 설치(새 세션부터)"
    else
      todo "$mod 설치 안 됨"
    fi
  done
fi

# --- 3. settingfiles 커밋 서명 확인 -------------------------------------------------------
# 저장소의 git-allowed-signers(토큰 A, B 의 공개 키)를 ~/.config/git/allowed_signers 로 처음 한 번만 복사하고, 이 clone 의
# git pull 이 서명을 확인하게 합니다(merge.verifySignatures). 서명이 없거나 모르는 키로 서명한 커밋이면 pull 이 멈춥니다.
# 이미 있는 파일은 덮어쓰지 않습니다. 저장소가 바뀌어도 저절로 믿지 않게 하려는 것이라, 키가 다르면 알리기만 합니다.
step "settingfiles 커밋 서명 확인"
signers="$HOME/.config/git/allowed_signers"
keys_of() { grep -v -E '^\s*(#|$)' "$1" 2>/dev/null | awk '{print $(NF-1), $NF}' | sort; }
if [ -f "$signers" ]; then
  if [ "$(keys_of "$signers")" = "$(keys_of "$HERE/git-allowed-signers")" ]; then
    ok "$signers"
  else
    todo "$signers 의 키가 git-allowed-signers 와 다름(확인한 뒤 손으로 맞추세요)"
  fi
elif doing; then
  install -D -m 644 "$HERE/git-allowed-signers" "$signers"
  did "$signers"
else
  todo "$signers 없음"
fi
repo_set() {  # key value
  local cur
  cur=$(git -C "$HERE" config --local --get "$1" || true)
  if [ "$cur" = "$2" ]; then
    ok "settingfiles $1 = $2"
  elif doing; then
    git -C "$HERE" config --local "$1" "$2"
    did "settingfiles $1 = $2${cur:+ (전: $cur)}"
  else
    todo "settingfiles $1 = $2${cur:+ (지금: $cur)}"
  fi
}
repo_set gpg.ssh.allowedSignersFile "$signers"
repo_set merge.verifySignatures true
if [ -f "$signers" ]; then
  sig=$(git -C "$HERE" -c gpg.ssh.allowedSignersFile="$signers" log -1 --format='%G? %h' 2>/dev/null || true)
  case $sig in
    G\ *) ok "지금 커밋 ${sig#G } 의 서명 확인됨" ;;
    *) todo "지금 커밋의 서명이 확인되지 않음(${sig:-알 수 없음})" ;;
  esac
fi
