#!/usr/bin/env bash
# Tests for bin/session-boards against a made-up ~/.claude: a running session, a
# registry file left by a dead process or by a pid now reused, boards from 0.1.0
# and 0.2.0, sessions known only from their transcripts, and a rebooted node with
# no registry at all. Run: bash tests/session-boards.test.sh
#
# The work folder is left in place (its path is printed) rather than removed.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
COMMAND=$HERE/../bin/session-boards
WORK=$(mktemp -d "${TMPDIR:-/tmp}/session-boards-test.XXXXXX")
FAKE_HOME=$WORK/home
CONFIG=$WORK/claude
NOW_MS=$(($(date +%s) * 1000))
failures=0
livePid=
otherPid=

stop_children() {
  [[ -z $livePid ]] || kill "$livePid" 2>/dev/null || true
  [[ -z $otherPid ]] || kill "$otherPid" 2>/dev/null || true
}
trap stop_children EXIT

mkdir -p "$FAKE_HOME" "$CONFIG/session-boards" "$CONFIG/projects/-p" "$CONFIG/sessions"

# A board as the mod writes it; $4 is the folder, empty for a 0.1.0 board.
write_board() {
  local id=$1 updatedAgoMs=$2 states=$3 cwd=$4
  jq -n --arg states "$states" --arg cwd "$cwd" --argjson at $((NOW_MS - updatedAgoMs)) '
    {version: 1, goal: "목표 \($states)", doneWhen: "", nextId: 9, pastGoals: [], updatedAt: $at, staleTurns: 0,
     items: ($states | split(",") | to_entries | map({id: (.key + 1), text: "일", state: .value}
       + (if .value == "waiting" then {waitingOn: "사용자"} elif .value == "done" then {evidence: "x"} else {} end)))}
    + (if $cwd == "" then {} else {cwd: $cwd} end)' >"$CONFIG/session-boards/$id.json"
}

# A transcript: a decoy line whose only cwd is nested, then the first real record.
write_chat() {
  local id=$1 cwd=$2 entrypoint=$3 title=$4 file=$CONFIG/projects/-p/$1.jsonl
  {
    jq -cn --arg id "$id" '{type: "attachment", sessionId: $id, attachment: {cwd: "/decoy"}}'
    jq -cn --arg id "$id" --arg cwd "$cwd" --arg e "$entrypoint" \
      '{type: "user", sessionId: $id, cwd: $cwd, entrypoint: $e, message: {content: "\"cwd\":\"/escaped\""}}'
    jq -cn --arg id "$id" '{type: "ai-title", sessionId: $id, aiTitle: "옛 제목"}'
    [[ -z $title ]] || jq -cn --arg id "$id" --arg t "$title" '{type: "ai-title", sessionId: $id, aiTitle: $t}'
  } >"$file"
}

write_registry() {
  local file=$1 id=$2 pid=$3 start=$4 kind=${5:-interactive}
  jq -n --arg id "$id" --argjson pid "$pid" --arg start "$start" --arg kind "$kind" --arg cwd "$FAKE_HOME/proj-a" \
    '{pid: $pid, sessionId: $id, procStart: $start, name: "live-\($id)", cwd: $cwd, kind: $kind}' >"$CONFIG/sessions/$file"
}

start_ticks() {
  awk '{print $22}' "/proc/$1/stat"
}

sleep 300 &
livePid=$!
sleep 300 &
otherPid=$!
true &
deadPid=$!
wait "$deadPid"

HOUR=3600000
write_board s-live $((5 * 60000)) doing,todo "$FAKE_HOME/proj-a"
write_registry "$livePid.json" s-live "$livePid" "$(start_ticks "$livePid")"
write_board s-dead $((72 * HOUR)) todo,todo,done "$FAKE_HOME/proj-b"
write_registry "$deadPid.json" s-dead "$deadPid" 12345
write_board s-reused $((2 * HOUR)) waiting "$FAKE_HOME/proj-b"
write_registry "$otherPid.json" s-reused "$otherPid" 1
write_board s-finished $((1 * HOUR)) done,done "$FAKE_HOME/proj-b"
write_board s-v1 $((1 * HOUR)) doing ""
write_chat s-v1 "$FAKE_HOME/proj-c" cli ""
write_board s-orphan $((1 * HOUR)) todo "$FAKE_HOME/proj-b"
write_board s-space $((1 * HOUR)) todo "$FAKE_HOME/my proj"
jq -n '{version: 1, goal: "", doneWhen: "", items: [], nextId: 1, pastGoals: [], updatedAt: 0, staleTurns: 0}' \
  >"$CONFIG/session-boards/s-empty.json"
printf 'not json\n' >"$CONFIG/session-boards/s-broken.json"
write_chat s-chat "$FAKE_HOME/proj-d" cli "대화만 있는 세션"
write_chat s-home "$FAKE_HOME" cli "홈에서 연 세션"
write_chat s-headless "$FAKE_HOME/proj-d" sdk-cli ""
write_chat s-old "$FAKE_HOME/proj-d" cli ""
touch -d '10 days ago' "$CONFIG/projects/-p/s-old.jsonl"
# A secret-shaped file beside the registry; the command must not read it.
jq -n --arg start "$(start_ticks "$livePid")" --argjson pid "$livePid" \
  '{pid: $pid, sessionId: "s-key", procStart: $start, kind: "interactive"}' >"$CONFIG/sessions/$livePid.abc.key"
chmod 600 "$CONFIG/sessions/$livePid.abc.key"

run() {
  HOME=$FAKE_HOME CLAUDE_CONFIG_DIR=$1 "$COMMAND" "${@:2}"
}

# tsv_field <tsv file> <session id> <column>
tsv_field() {
  awk -F '\t' -v id="$2" -v col="$3" 'NR == 1 { for (i = 1; i <= NF; i++) if ($i == col) c = i; next } $1 == id { print $c }' "$1"
}

has_row() {
  awk -F '\t' -v id="$2" 'NR > 1 && $1 == id { found = 1 } END { exit !found }' "$1"
}

check() {
  local label=$1
  shift

  if "$@"; then
    printf 'ok   %s\n' "$label"
  else
    printf 'FAIL %s\n' "$label"
    failures=$((failures + 1))
  fi
}

equals() {
  [[ $1 == "$2" ]] || {
    printf '     expected [%s], got [%s]\n' "$2" "$1"
    return 1
  }
}

contains() {
  [[ $1 == *"$2"* ]] || {
    printf '     [%s] has no [%s]\n' "$1" "$2"
    return 1
  }
}

not() {
  ! "$@" >/dev/null
}

run "$CONFIG" --tsv >"$WORK/default.tsv" 2>"$WORK/default.err"
run "$CONFIG" --tsv --all >"$WORK/all.tsv" 2>"$WORK/all.err"
run "$CONFIG" >"$WORK/table.txt" 2>"$WORK/table.err"
D=$WORK/default.tsv
A=$WORK/all.tsv

check 'a running session shows its pid and is no candidate' equals "$(tsv_field "$D" s-live pid)" "$livePid"
check 'a running session takes its name from the registry' equals "$(tsv_field "$D" s-live name)" live-s-live
check 'a running session is not a candidate' not contains "$(tsv_field "$D" s-live flags)" '다시 켤 후보'
check 'a dead pid counts as not running' equals "$(tsv_field "$D" s-dead pid)" ''
check 'open work and no process makes a candidate' contains "$(tsv_field "$D" s-dead flags)" '다시 켤 후보'
check 'a board idle for three days is stale' contains "$(tsv_field "$D" s-dead flags)" '낡음'
check 'a reused pid with another start time counts as not running' equals "$(tsv_field "$D" s-reused pid)" ''
check 'a finished board is hidden' not has_row "$D" s-finished
check 'a finished board shows with --all' contains "$(tsv_field "$A" s-finished flags)" '끝남'
check 'a 0.1.0 board takes its folder from the transcript' equals "$(tsv_field "$D" s-v1 cwd)" "$FAKE_HOME/proj-c"
check 'a board without a transcript keeps its own folder' equals "$(tsv_field "$D" s-orphan cwd)" "$FAKE_HOME/proj-b"
check 'the resume command quotes a folder with a space' \
  equals "$(tsv_field "$D" s-space resume)" 'cd ~/my\ proj && claude --resume s-space'
check 'a session known only from its transcript shows' contains "$(tsv_field "$D" s-chat flags)" '보드 없음'
check 'its title is the newest one' equals "$(tsv_field "$D" s-chat title)" '대화만 있는 세션'
check 'a headless run is hidden' not has_row "$D" s-headless
check 'a headless run shows with --all' has_row "$A" s-headless
check 'an old transcript without a board is hidden' not has_row "$D" s-old
check 'an old transcript shows with --all' has_row "$A" s-old
check 'an empty board is no board' not has_row "$A" s-empty
check 'the .key file is never read' not has_row "$A" s-key
check 'nothing is written to stderr' equals "$(cat "$WORK/default.err" "$WORK/all.err" "$WORK/table.err")" ''
check 'the table lists the candidates with resume commands' contains "$(cat "$WORK/table.txt")" '다시 켤 후보 5개'
check 'the table carries a resume line' contains "$(cat "$WORK/table.txt")" 'cd ~/proj-b && claude --resume s-dead'
check 'the table says what it hid' contains "$(cat "$WORK/table.txt")" '끝난 보드 1개'
check 'a stopped session without a board gets its resume command too' \
  contains "$(cat "$WORK/table.txt")" $'  대화만 있는 세션\n    cd ~/proj-d && claude --resume s-chat'
check 'both stopped sessions without a board are listed' contains "$(cat "$WORK/table.txt")" '보드 없이 멈춘 세션 2개'
check 'a session started in the home folder resumes from ~' \
  equals "$(tsv_field "$D" s-home resume)" 'cd ~ && claude --resume s-home'
check 'a running session gets no resume line' not contains "$(cat "$WORK/table.txt")" 'claude --resume s-live'

# After a reboot the registry is gone; boards and transcripts are all there is.
mkdir -p "$WORK/rebooted"
ln -s "$CONFIG/session-boards" "$WORK/rebooted/session-boards"
ln -s "$CONFIG/projects" "$WORK/rebooted/projects"
run "$WORK/rebooted" --tsv >"$WORK/rebooted.tsv"
check 'with no registry every open board is a candidate' contains "$(tsv_field "$WORK/rebooted.tsv" s-live flags)" '다시 켤 후보'
check 'with no registry the folder still comes from the board' \
  equals "$(tsv_field "$WORK/rebooted.tsv" s-live cwd)" "$FAKE_HOME/proj-a"

mkdir -p "$WORK/empty"
check 'a node with no sessions says so' equals "$(run "$WORK/empty" | head -n 1)" '보여 줄 세션이 없습니다.'
check 'a bad argument exits 2' equals "$(
  run "$CONFIG" --days x >/dev/null 2>&1
  echo $?
)" 2

printf '\n%s failed. Work folder: %s\n' "$failures" "$WORK"
((failures == 0))
