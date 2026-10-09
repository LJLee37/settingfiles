#!/bin/bash
# 이 기기를 server-automation 의 컨트롤 노드로 만들고, 다시 돌리면 최신으로 맞춥니다.
# 컨트롤 노드는 일부러 server-automation 인벤토리 밖에 있습니다(플레이북과 서명 키를 쥔 기기를
# 그 플레이북이 고치지 않게). 그래서 이 기기에만 사는 설정을 여기서 깔고 맞춥니다.
#
#   ./install-control-node.sh          설치와 갱신(이미 된 것은 건너뜀)
#   ./install-control-node.sh --check  아무것도 바꾸지 않고 상태만 봄
#
# sudo, FIDO2 토큰의 PIN 과 터치를 묻는 단계가 있으니 사람이 있는 터미널에서 돌리세요.
# set.sh(셸, 편집기)를 먼저 돌린 뒤에 돌립니다. 이 스크립트가 할 수 없는 것(저장소에 없는 비밀,
# 로그인)은 마지막에 "손으로 할 것" 으로 모아 보여 줍니다.
#
# 무엇을 왜 하는지는 server-automation README 의 「컨트롤 노드를 새로 세울 때」, 「커밋 서명은
# GPG 가 아니라 SSH 입니다」, TODO 6절(github.com 블록)을 따릅니다.
set -euo pipefail

REPOS="$HOME/gitRepos"
SA="$REPOS/server-automation"
WL="$REPOS/worklog"
FIDO_KEY="ljlee_sk_a"                 # 서명과 로그인에 쓰는 FIDO2 키(핸들 파일 이름)
AUR_DIR="$HOME/aur"
AUR_PKGS=(claude-code)
# 컨트롤 노드에서 쓰는 도구. ansible: 플레이북, libfido2: ssh-keygen 이 런타임에 dlopen 하는
# FIDO2 라이브러리, github-cli: HTTPS clone 과 push 자격증명, base-devel: AUR 빌드,
# python-dnspython: README 의 mDNS 직접 질의, libnotify: 인증서 만료 알림(notify-send).
PACMAN_PKGS=(git openssh libfido2 ansible github-cli base-devel python-dnspython libnotify)

CHECK=0
case "${1:-}" in
  --check) CHECK=1 ;;
  "") ;;
  *) sed -n 2,11p "$0"; exit 64 ;;
esac
[ "$(id -u)" -ne 0 ] || { echo "root 가 아니라 평소 사용자로 돌리세요" >&2; exit 1; }

manual=()
step() { printf '\n== %s\n' "$*"; }
ok() { printf '   됨    %s\n' "$*"; }
todo() { printf '   필요  %s\n' "$*"; }
did() { printf '   바꿈  %s\n' "$*"; }
doing() { [ "$CHECK" -eq 0 ]; }

# --- 1. 패키지 ----------------------------------------------------------------
step "pacman 패키지"
missing=$(pacman -T "${PACMAN_PKGS[@]}" || true)
if [ -z "$missing" ]; then
  ok "${PACMAN_PKGS[*]}"
elif doing; then
  sudo pacman -S --needed $missing
  did "설치: $missing"
else
  todo "설치할 것: $missing"
fi

# --- 2. AUR (claude-code) -------------------------------------------------------
# 노드는 role 이 pnpm 판과 자동 업데이트 판을 맞추지만, 이 기기는 다른 앱처럼 AUR 판 하나만 둡니다.
# 판은 이 스크립트를 돌릴 때 올라갑니다.
step "AUR 패키지"
srcinfo_version() {  # .SRCINFO 내용에서 [epoch:]pkgver-pkgrel
  awk -F' = ' '/^\tepoch/{e=$2":"} /^\tpkgver/{v=$2} /^\tpkgrel/{r=$2} END{print e v "-" r}'
}
for pkg in "${AUR_PKGS[@]}"; do
  dir="$AUR_DIR/$pkg"
  have=$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}' || true)
  if [ ! -d "$dir/.git" ]; then
    if doing; then
      mkdir -p "$AUR_DIR"
      git clone -q "https://aur.archlinux.org/$pkg.git" "$dir"
    else
      todo "$pkg: $dir 가 없음(설치된 판 ${have:-없음})"
      continue
    fi
  fi
  git -C "$dir" fetch -q origin
  want=$(git -C "$dir" show origin/master:.SRCINFO | srcinfo_version)
  if [ "$have" = "$want" ]; then
    ok "$pkg $have"
  elif doing; then
    git -C "$dir" merge -q --ff-only origin/master
    (cd "$dir" && makepkg -sic)
    did "$pkg ${have:-없음} -> $want"
  else
    todo "$pkg ${have:-없음} -> $want"
  fi
done

# --- 3. 저장소 ----------------------------------------------------------------
# server-automation 과 worklog 는 HTTPS + gh 자격증명으로 받습니다(SSH 원격은 push 마다 터치가
# 필요합니다). gh 로그인은 브라우저가 필요해 손으로 합니다.
step "저장소 (~/gitRepos)"
if ! gh auth status >/dev/null 2>&1; then
  todo "gh 로그인 안 됨"
  manual+=("gh auth login 으로 GitHub 에 로그인한 뒤 이 스크립트를 다시 돌리세요(저장소 clone 과 push 자격증명).")
else
  if doing; then gh auth setup-git; fi
  for repo in server-automation worklog; do
    dir="$REPOS/$repo"
    if [ -d "$dir/.git" ]; then
      branch=$(git -C "$dir" branch --show-current)
      if [ "$branch" = master ] && [ -z "$(git -C "$dir" status --porcelain --untracked-files=no)" ]; then
        if doing; then
          git -C "$dir" pull -q --ff-only && ok "$repo (master, 최신으로 받음)"
        else
          ok "$repo (master, 깨끗함)"
        fi
      else
        todo "$repo 가 master 가 아니거나 커밋 안 된 변경이 있어 받지 않음(지금 ${branch:-detached})"
      fi
    elif doing; then
      mkdir -p "$REPOS"
      git clone -q "https://github.com/LJLee37/$repo.git" "$dir"
      did "$repo clone"
    else
      todo "$repo 없음"
    fi
  done
fi

# --- 4. 커밋 서명 --------------------------------------------------------------
# server-automation 은 서명 필수(pre-push 가 막음). 서명은 FIDO2 키 핸들 파일로 하고, GNOME 의
# gcr-ssh-agent 가 sk 키 서명을 가로채 거절하므로 ssh-keygen 을 에이전트 없이 부르는 래퍼를 겁니다.
step "커밋 서명"
sign_wrapper="$HOME/.local/bin/git-ssh-sign"
want_wrapper='#!/usr/bin/env bash
# git 의 SSH 서명(gpg.ssh.program)용 래퍼. settingfiles install-control-node.sh 가 둡니다.
# GNOME Keyring 의 gcr-ssh-agent 는 FIDO2(sk-*) 키 서명을 구현하지 않는데, ssh-keygen -Y sign 은
# 키가 에이전트에 보이면 파일보다 에이전트를 우선해 "agent refused operation" 으로 죽습니다.
# SSH_AUTH_SOCK 을 지우면 핸들을 직접 열고 자기 tty 에서 PIN 을 묻습니다.
unset SSH_AUTH_SOCK
exec /usr/bin/ssh-keygen "$@"'
# 주석은 비교하지 않습니다(손으로 둔 옛 래퍼도 명령이 같으면 그대로 둠).
code_only() { grep -v -E '^\s*(#|$)' || true; }
if [ "$(cat "$sign_wrapper" 2>/dev/null)" = "$want_wrapper" ]; then
  ok "$sign_wrapper"
elif [ -x "$sign_wrapper" ] && [ "$(code_only < "$sign_wrapper")" = "$(printf '%s\n' "$want_wrapper" | code_only)" ]; then
  ok "$sign_wrapper (주석만 다름)"
elif doing; then
  mkdir -p "$(dirname "$sign_wrapper")"
  printf '%s\n' "$want_wrapper" > "$sign_wrapper"
  chmod 755 "$sign_wrapper"
  did "$sign_wrapper"
else
  todo "$sign_wrapper 없음 또는 다름"
fi

# allowed_signers 는 노드와 같은 목록(server-automation group_vars/all/vars.yml 의 git_allowed_signers)
# 에서 만듭니다. 노드에서는 roles/common 이 같은 목록을 렌더링합니다.
signers="$HOME/.config/git/allowed_signers"
if [ -f "$SA/group_vars/all/vars.yml" ]; then
  want_signers=$(python3 - "$SA" <<'EOF'
import sys, yaml
sa = sys.argv[1]
with open(f"{sa}/group_vars/all/vars.yml") as f:
    signers = yaml.safe_load(f)["git_allowed_signers"]
print("# settingfiles install-control-node.sh 가 server-automation 의 git_allowed_signers 에서 만듭니다.")
print("# 고칠 것이 있으면 그 목록을 고치고 스크립트를 다시 돌리세요(노드는 roles/common 이 같은 목록을 씁니다).")
for s in signers:
    with open(f"{sa}/roles/common/files/keys/{s['file']}") as f:
        key = " ".join(f.read().split()[:2])
    print(f"\n# {s['comment']}\n{s['identity']} namespaces=\"git\" {key}")
EOF
)
  if [ "$(cat "$signers" 2>/dev/null)" = "$want_signers" ]; then
    ok "$signers"
  elif [ -f "$signers" ] && [ "$(code_only < "$signers" | sort)" = "$(printf '%s\n' "$want_signers" | code_only | sort)" ]; then
    ok "$signers (키는 같고 주석만 다름)"
  elif doing; then
    mkdir -p "$(dirname "$signers")"
    printf '%s\n' "$want_signers" > "$signers"
    did "$signers"
  else
    todo "$signers 없음 또는 목록과 다름"
  fi
else
  todo "$signers: server-automation 이 없어 만들지 못함"
fi

repo_config() {  # repo key value
  local dir="$REPOS/$1" cur
  [ -d "$dir/.git" ] || return 0
  cur=$(git -C "$dir" config --local --get "$2" || true)
  if [ "$cur" = "$3" ] || [ "$cur" = "$dir/$3" ]; then   # hooksPath 는 절대 경로로 둬도 같음
    return 0
  elif [ "$2" = user.signingkey ] && [ -f "$cur" ] && cmp -s "$cur" "$3"; then
    ok "$1 $2 = $cur (같은 키 핸들)"
  elif doing; then
    git -C "$dir" config --local "$2" "$3"
    did "$1 $2 = $3${cur:+ (전: $cur)}"
  else
    todo "$1 $2 = $3${cur:+ (지금: $cur)}"
  fi
}
repo_config server-automation core.hooksPath githooks
repo_config server-automation commit.gpgsign true
repo_config server-automation gpg.format ssh
repo_config server-automation user.signingkey "$HOME/.ssh/$FIDO_KEY"
repo_config server-automation gpg.ssh.allowedSignersFile "$signers"
repo_config server-automation gpg.ssh.program "$sign_wrapper"
repo_config worklog core.hooksPath githooks

# --- 5. SSH: FIDO2 핸들, 사용자 인증서, github.com ------------------------------
step "SSH"
if [ -f "$HOME/.ssh/$FIDO_KEY" ]; then
  ok "FIDO2 핸들 ~/.ssh/$FIDO_KEY"
elif doing && [ -x "$SA/scripts/fido2-handle.sh" ]; then
  echo "   토큰을 꽂으세요. PIN 과 터치를 묻습니다."
  (cd "$SA" && scripts/fido2-handle.sh "$FIDO_KEY")
  did "FIDO2 핸들 ~/.ssh/$FIDO_KEY"
else
  todo "FIDO2 핸들 ~/.ssh/$FIDO_KEY 없음(server-automation 의 scripts/fido2-handle.sh $FIDO_KEY)"
fi

# 사용자 인증서용 키, ~/.ssh/config 관리 블록, 만료 알림 타이머, 호스트 인증서 신뢰. 처음에는 첫
# 인증서까지 발급하고(PIN + 터치), 그 뒤에는 --no-issue 로 유닛과 블록만 최신으로 맞춥니다.
if [ -x "$SA/scripts/ssh-cert-setup.sh" ]; then
  if grep -q '^# >>> server-automation: ssh certificate (managed) >>>' "$HOME/.ssh/config" 2>/dev/null; then
    if doing; then
      (cd "$SA" && scripts/ssh-cert-setup.sh --no-issue >/dev/null) && ok "인증서 설정 블록과 타이머(최신으로 맞춤)"
    else
      ok "인증서 설정 블록 있음"
    fi
  elif doing; then
    echo "   첫 인증서를 발급합니다. PIN 과 터치를 묻습니다."
    (cd "$SA" && scripts/ssh-cert-setup.sh)
    did "인증서 설정과 첫 발급"
  else
    todo "인증서 설정 블록 없음(server-automation 의 scripts/ssh-cert-setup.sh)"
  fi
  if (cd "$SA" && scripts/ssh-cert-issue.sh --check >/dev/null 2>&1); then
    ok "사용자 인증서 유효"
  else
    todo "사용자 인증서가 없거나 곧 끝남"
    manual+=("cd $SA && scripts/ssh-cert-issue.sh 로 오늘 인증서를 받으세요(PIN + 터치). 노드 접속과 check, apply 에 필요합니다.")
  fi
else
  todo "server-automation 이 없어 인증서 설정을 건너뜀"
fi

# github.com 은 에이전트를 끊고 FIDO2 키 파일을 직접 쓰게 합니다(gcr-ssh-agent 가 sk 키 서명을
# 거절). ssh-cert-setup.sh 의 관리 블록 밖에 둬야 그 스크립트를 다시 돌려도 남습니다.
if grep -q '^Host github.com' "$HOME/.ssh/config" 2>/dev/null; then
  ok "~/.ssh/config 의 github.com 블록"
elif doing; then
  printf '\n# settingfiles install-control-node.sh: GitHub SSH 는 에이전트 없이 FIDO2 키 파일로(gcr-ssh-agent 가 sk 서명을 거절)\nHost github.com\n    IdentityAgent none\n    IdentitiesOnly yes\n    IdentityFile ~/.ssh/%s\n' "$FIDO_KEY" >> "$HOME/.ssh/config"
  did "~/.ssh/config 에 github.com 블록"
else
  todo "~/.ssh/config 에 github.com 블록 없음"
fi

# --- 6. Ansible -------------------------------------------------------------------
step "Ansible"
if [ -f "$SA/requirements.yml" ]; then
  if doing; then
    ansible-galaxy collection install -r "$SA/requirements.yml" >/dev/null && ok "컬렉션(requirements.yml)"
  else
    ok "컬렉션은 --check 에서 보지 않음(설치 때 ansible-galaxy 가 이미 있는 것은 건너뜀)"
  fi
fi
# 노드별 실제 값과 호스트 인증서는 커밋하지 않아(gitignore) clone 으로 오지 않습니다.
for h in main-server raspi cloud-vpn; do
  if [ -f "$SA/host_vars/$h.yml" ]; then
    ok "host_vars/$h.yml"
  else
    todo "host_vars/$h.yml 없음"
    manual+=("host_vars/$h.yml: 백업에서 되살리거나 $h.yml.example 을 복사해 실제 값을 채우세요.")
  fi
done
if compgen -G "$SA/roles/common/files/host_certs/*-cert.pub" >/dev/null; then
  ok "호스트 인증서(roles/common/files/host_certs)"
else
  todo "호스트 인증서 없음"
  manual+=("cd $SA && scripts/ssh-hostcert-issue.sh 로 호스트 인증서를 다시 발급하세요(노드당 터치 한 번, 급하지 않음).")
fi
if doing; then mkdir -p "$HOME/handoffs/logs"; fi   # land 스크립트가 check, apply 로그를 여기에 남깁니다

# --- 7. 덮개 ------------------------------------------------------------------------
# 노트북이라 덮개를 닫으면 절전해 긴 apply 와 원격 세션이 끊깁니다. 전원이 연결돼 있을 때만 무시합니다.
step "덮개(전원 연결 중에는 절전하지 않음)"
lid_conf=/etc/systemd/logind.conf.d/lid-ac.conf
want_lid='# settingfiles install-control-node.sh: 전원 연결 중에는 덮개를 닫아도 절전하지 않는다(배터리일 때는 그대로 절전).
[Login]
HandleLidSwitchExternalPower=ignore'
if [ "$(cat "$lid_conf" 2>/dev/null)" = "$want_lid" ]; then
  ok "$lid_conf"
elif [ -f "$lid_conf" ] && grep -qx 'HandleLidSwitchExternalPower=ignore' "$lid_conf"; then
  ok "$lid_conf (주석만 다름)"
elif doing; then
  printf '%s\n' "$want_lid" | sudo install -D -m 644 /dev/stdin "$lid_conf"
  sudo systemctl kill -s HUP systemd-logind   # 재시작하지 않고 설정만 다시 읽어 지금 세션을 끊지 않음
  did "$lid_conf"
else
  todo "$lid_conf 없음"
fi

# --- 8. Claude Code mod ------------------------------------------------------------
# 노드와 같은 mod 를 씁니다. 노드는 role 이 폴더를 복사하지만, 여기서는 clone 의 폴더를 바로
# 마켓플레이스로 등록하므로 server-automation 을 pull 하면 mod 도 새 판이 됩니다.
step "Claude Code mod"
mods="$SA/roles/agentic_coding/files/claude-mods"
claude_version=$(claude --version 2>/dev/null | awk '{print $1}' || true)
if [ ! -d "$mods" ]; then
  ok "server-automation 에 mod 가 아직 없음(건너뜀)"
elif [ -z "$claude_version" ] || [ "$(printf '%s\n' 2.1.287 "$claude_version" | sort -V | head -1)" != 2.1.287 ]; then
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
  for mod in usage-meter; do
    if claude plugin list --json | has_name id "$mod@local-mods"; then
      ok "$mod"
    elif doing; then
      claude plugin install "$mod@local-mods" --scope user >/dev/null && did "$mod 설치(새 세션부터)"
    else
      todo "$mod 설치 안 됨"
    fi
  done
fi

# --- 손으로 할 것 -----------------------------------------------------------------
manual+=("Claude Code 로그인(claude 를 한 번 실행)과, 다른 세션과 대화할 때 /remote-control.")
manual+=("vault 비밀번호는 어디에도 저장하지 않습니다. check, apply 때 --ask-vault-pass 로 칩니다.")
manual+=("FIDO2 토큰 A(서명, 로그인)와 B(백업), 오프라인 비상용 마스터 키는 이 스크립트 밖입니다.")
step "손으로 할 것"
for m in "${manual[@]}"; do printf '   - %s\n' "$m"; done
