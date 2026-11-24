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
HERE="$(dirname "$(readlink -f "$0")")"
# 이 기기의 hosts/*.env(HOST_NAME 이 /etc/hostname 과 같은 것). env 는 source 하지 않고 sed 로 한 줄씩 읽습니다.
host_env=""
for env in "$HERE"/hosts/*.env; do
  [ "$(sed -n 's/^HOST_NAME=//p' "$env")" = "$(cat /etc/hostname 2>/dev/null)" ] || continue
  host_env="$env"
done
env_value() { [ -z "$host_env" ] || sed -n "s/^$1=//p" "$host_env"; }
# 서명과 로그인에 쓰는 FIDO2 키(핸들 파일 이름). 기기마다 손에 있는 토큰이 다릅니다 - 컨트롤 카드(LJTF)는
# 토큰 A 와, 예비 컨트롤 노드(LJUSB)는 B 와 같은 키링에 달려 있습니다. 환경변수 FIDO_KEY, 아니면 이
# 기기 env 의 CONTROL_FIDO_KEY, 아니면 ljlee_sk_a.
FIDO_KEY="${FIDO_KEY:-$(env_value CONTROL_FIDO_KEY)}"
FIDO_KEY="${FIDO_KEY:-ljlee_sk_a}"
# Claude Code 작업 시간을 헤르메스 노드에 보낼지(9절). 환경변수 CC_TIMELOG_PUSH, 아니면 이 기기 env 의
# CONTROL_CC_TIMELOG_PUSH. yes 가 아니면 보내지 않습니다.
CC_TIMELOG_PUSH="${CC_TIMELOG_PUSH:-$(env_value CONTROL_CC_TIMELOG_PUSH)}"
AUR_DIR="$HOME/aur"
AUR_PKGS=(claude-code)
# 컨트롤 노드에서 쓰는 도구. ansible: 플레이북, libfido2: ssh-keygen 이 런타임에 dlopen 하는
# FIDO2 라이브러리, github-cli: HTTPS clone 과 push 자격증명, base-devel: AUR 빌드,
# python-dnspython: README 의 mDNS 직접 질의, libnotify: 인증서 만료 알림(notify-send).
# networkmanager-strongswan: 노드의 IKEv2 VPN 에 붙는 클라이언트(main-server 의 NAS 는 VPN 안에서만
# 열림, 2026-10-27). nm-connection-editor: 그 VPN 프로필을 만드는 GTK3 편집기 - 이 플러그인은 GTK3
# 편집기만 싣고 있어 GNOME 설정(51, GTK4)에서는 입력 칸이 동작하지 않습니다.
PACMAN_PKGS=(git openssh libfido2 ansible github-cli base-devel python-dnspython libnotify
  networkmanager-strongswan nm-connection-editor)

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
# 다른 패키지의 의존성으로만 깔린 것은 직접 설치로 표시합니다. 데스크톱 프로필을 바꿔 지울 때 같이 빠지지 않게(2026-11-19).
asdeps=$({ pacman -Qdq "${PACMAN_PKGS[@]}" 2>/dev/null || true; } | tr '\n' ' ')
if [ -z "${asdeps// }" ]; then
  ok "모두 직접 설치로 표시됨"
elif doing; then
  # shellcheck disable=SC2086
  sudo pacman -D --asexplicit $asdeps >/dev/null
  did "직접 설치로 표시: $asdeps"
else
  todo "의존성으로만 깔림(직접 설치로 표시 필요): $asdeps"
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
# server-automation, worklog, llm-wiki 는 HTTPS + gh 자격증명으로 받습니다(SSH 원격은 push 마다 터치가
# 필요합니다). gh 로그인은 브라우저가 필요해 손으로 합니다. llm-wiki 는 작업에서 알게 된 것을 쌓는 비공개
# 위키입니다(10절의 전역 CLAUDE.md, 2026-10-28 사용자 결정).
step "저장소 (~/gitRepos)"
if ! gh auth status >/dev/null 2>&1; then
  todo "gh 로그인 안 됨"
  manual+=("gh auth login 으로 GitHub 에 로그인한 뒤 이 스크립트를 다시 돌리세요(저장소 clone 과 push 자격증명).")
else
  if doing; then gh auth setup-git; fi
  for repo in server-automation worklog llm-wiki; do
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
# server-automation 은 서명 필수(pre-push 가 막음). 서명은 FIDO2 키로 하고, git 은 아래 래퍼로 ssh-keygen 을 부릅니다.
# GNOME 의 gcr-ssh-agent 를 쓰던 때는 래퍼가 에이전트를 끊었지만, 2026-11-19 부터는 desktop 프로필이 gcr 를 막고 OpenSSH
# 에이전트를 쓰므로 그대로 넘깁니다(LJTF 에서 에이전트로 서명되는 것을 시험함).
step "커밋 서명"
sign_wrapper="$HOME/.local/bin/git-ssh-sign"
want_wrapper='#!/usr/bin/env bash
# git 의 SSH 서명(gpg.ssh.program)용 래퍼. settingfiles install-control-node.sh 가 둡니다.
# 토큰 키가 OpenSSH 에이전트에 있으면 에이전트로, 없으면 핸들 파일로 서명하고, PIN 은 ksshaskpass 창으로 묻습니다
# (desktop 프로필의 SSH_ASKPASS_REQUIRE=prefer). GNOME 의 gcr-ssh-agent 는 sk 키 서명을 거절해서 예전에는 여기서
# SSH_AUTH_SOCK 을 지웠습니다(2026-11-19 까지).
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
# settingfiles 도 같은 목록으로 서명을 확인합니다(git log %G?). LJGaming 은 ljgaming/install.sh 가 git-allowed-signers 로 합니다.
repo_config settingfiles gpg.ssh.allowedSignersFile "$signers"
repo_config worklog core.hooksPath githooks
# llm-wiki 는 서명하지 않습니다(main-server 의 clone 과 헤르메스의 커밋도 서명하지 않음).
repo_config llm-wiki commit.gpgsign false

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
      (cd "$SA" && scripts/ssh-cert-setup.sh --ca "$HOME/.ssh/$FIDO_KEY" --no-issue >/dev/null) && ok "인증서 설정 블록과 타이머(최신으로 맞춤)"
    else
      ok "인증서 설정 블록 있음"
    fi
  elif doing; then
    echo "   첫 인증서를 발급합니다. PIN 과 터치를 묻습니다."
    (cd "$SA" && scripts/ssh-cert-setup.sh --ca "$HOME/.ssh/$FIDO_KEY")
    did "인증서 설정과 첫 발급"
  else
    todo "인증서 설정 블록 없음(server-automation 의 scripts/ssh-cert-setup.sh)"
  fi
  if (cd "$SA" && scripts/ssh-cert-issue.sh --check >/dev/null 2>&1); then
    ok "사용자 인증서 유효"
  else
    todo "사용자 인증서가 없거나 곧 끝남"
    manual+=("cd $SA && scripts/ssh-cert-issue.sh --ca ~/.ssh/$FIDO_KEY 로 오늘 인증서를 받으세요(PIN + 터치). 노드 접속과 check, apply 에 필요합니다.")
  fi
else
  todo "server-automation 이 없어 인증서 설정을 건너뜀"
fi

# github.com 은 FIDO2 키로 붙고, 처음 쓸 때 그 키를 OpenSSH 에이전트에 올립니다(AddKeysToAgent, LJGaming 과 같음). 그 뒤로는
# 에이전트가 서명하고 PIN 은 ksshaskpass 창으로 묻습니다. ssh-cert-setup.sh 의 관리 블록 밖에 둬야 그 스크립트를 다시 돌려도
# 남습니다. GNOME 의 gcr-ssh-agent 를 쓰던 때는 IdentityAgent none 으로 에이전트를 끊었는데(sk 서명을 거절), 그 옛 블록이
# 있으면 ~/.ssh/config.bak-github-<날짜> 를 남기고 그 줄만 바꿉니다(2026-11-19).
github_old() { awk '/^Host /{g=($2=="github.com")} g && /^[[:space:]]+IdentityAgent[[:space:]]+none/{f=1} END{exit !f}' "$HOME/.ssh/config" 2>/dev/null; }
if ! grep -q '^Host github.com' "$HOME/.ssh/config" 2>/dev/null; then
  if doing; then
    printf '\n# settingfiles install-control-node.sh: GitHub SSH 는 FIDO2 키로, OpenSSH 에이전트를 거쳐(처음 쓸 때 올림)\nHost github.com\n    AddKeysToAgent yes\n    IdentitiesOnly yes\n    IdentityFile ~/.ssh/%s\n' "$FIDO_KEY" >> "$HOME/.ssh/config"
    did "~/.ssh/config 에 github.com 블록"
  else
    todo "~/.ssh/config 에 github.com 블록 없음"
  fi
elif github_old; then
  if doing; then
    cp -p "$HOME/.ssh/config" "$HOME/.ssh/config.bak-github-$(date +%Y%m%d)"
    awk '/^Host /{g=($2=="github.com")}
         g && /^[[:space:]]+IdentityAgent[[:space:]]+none/{print "    AddKeysToAgent yes"; next}
         /^# settingfiles install-control-node.sh: GitHub SSH 는 에이전트 없이/{print "# settingfiles install-control-node.sh: GitHub SSH 는 FIDO2 키로, OpenSSH 에이전트를 거쳐(처음 쓸 때 올림)"; next}
         {print}' "$HOME/.ssh/config.bak-github-$(date +%Y%m%d)" > "$HOME/.ssh/config"
    did "~/.ssh/config 의 github.com 블록: IdentityAgent none 을 AddKeysToAgent yes 로(백업 config.bak-github-$(date +%Y%m%d))"
  else
    todo "~/.ssh/config 의 github.com 블록이 옛 모양(IdentityAgent none)"
  fi
else
  ok "~/.ssh/config 의 github.com 블록"
fi

# 로그인할 때 인증서 키(id_ed25519, 같은 이름의 -cert.pub 도 같이)를 OpenSSH 에이전트에 올립니다(2026-11-19, Plasma 로 바꾼 뒤).
# GNOME 때는 gcr-ssh-agent 가 이 키를 키링으로 조용히 내줬지만 OpenSSH 에이전트는 비어서 시작하므로, herdr 의 저장된 머신이
# 끊긴 뒤 다시 붙을 때 ssh 가 토큰 키로 넘어가 30초마다 PIN 창을 띄웠습니다. 암호는 ksshaskpass 가 처음 한 번 묻고, 그때
# "Remember password" 를 켜면 KWallet 에 두고 다음 로그인부터 조용히 읽습니다(ArchWiki 「KDE Wallet」, arch-wiki-docs 20261101).
# 인증서가 끝나면 다시 토큰 키로 넘어가므로 그날 인증서를 받습니다(ssh-cert-issue.sh, ~/.ssh/config 의 CertificateFile).
ssh_add_autostart="$HOME/.config/autostart/ssh-add-id_ed25519.desktop"
want_ssh_add=$(printf '%s\n' '[Desktop Entry]' 'Type=Application' 'Name=ssh-add id_ed25519' \
  'Comment=settingfiles install-control-node.sh: 로그인할 때 인증서 키를 OpenSSH 에이전트에 올림(암호는 KWallet)' \
  "Exec=env SSH_ASKPASS_REQUIRE=prefer ssh-add -q $HOME/.ssh/id_ed25519" 'NoDisplay=true' 'X-KDE-autostart-phase=2')
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  todo "~/.ssh/id_ed25519 없음(인증서 설정 뒤 다시 돌리세요)"
elif [ "$(cat "$ssh_add_autostart" 2>/dev/null)" = "$want_ssh_add" ]; then
  ok "$ssh_add_autostart"
elif doing; then
  mkdir -p "$(dirname "$ssh_add_autostart")"
  printf '%s\n' "$want_ssh_add" > "$ssh_add_autostart"
  did "$ssh_add_autostart (다음 로그인부터. 처음 암호를 물으면 Remember password 를 켬)"
else
  todo "$ssh_add_autostart 없음 또는 다름"
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
# 노드별 실제 값은 평문으로는 커밋하지 않고(gitignore), 2026-10-21 부터 ansible-vault 봉인본
# (host_vars/<노드>.yml.vault)이 clone 으로 옵니다. 봉인본에서 평문을 되살리는 것은 vault 비밀번호가
# 필요해 손으로 합니다. 평문과 봉인본이 같은지는 site.yml 의 첫 play 가 실행 때마다 봅니다.
for h in main-server raspi cloud-vpn; do
  if [ -f "$SA/host_vars/$h.yml" ]; then
    ok "host_vars/$h.yml"
  elif [ -f "$SA/host_vars/$h.yml.vault" ]; then
    todo "host_vars/$h.yml 없음(봉인본은 있음)"
    manual+=("cd $SA && scripts/host-vars.sh unseal 로 host_vars 를 봉인본에서 되살리세요(vault 비밀번호).")
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
# server-automation 을 받을 수 없는 LJGaming 은 이 저장소의 claude-mods/ 사본을 씁니다(ljgaming/install.sh,
# 2026-11-17). 사본이 원본과 다르면 알립니다. 맞추는 것은 control-node/sync-claude-mods.sh 와 커밋입니다.
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
if [ -d "$mods" ]; then
  if "$HERE/control-node/sync-claude-mods.sh" --check >/dev/null 2>&1; then
    ok "claude-mods 사본(LJGaming 용)이 원본과 같음"
  else
    todo "claude-mods 사본이 server-automation 과 다름(control-node/sync-claude-mods.sh 를 돌리고 커밋)"
  fi
fi

# --- 9. Claude Code 작업 시간 보내기 ------------------------------------------------
# 이 기기에서 한 Claude Code 작업도 헤르메스 노드의 장부 시간 기록에 넣습니다(2026-10-26 사용자 결정). user 타이머가
# 30분마다 server-automation clone 의 cc-activity 로 turn 목록(프롬프트 내용 없음)을 뽑아 main-server 와 raspi 의
# inbox 에 ssh 로 씁니다(control-node/cc-timelog-push.sh). 받는 쪽은 server-automation 의 timelog-context.sh 입니다.
# CONTROL_CC_TIMELOG_PUSH=yes 인 기기만 켜고, 아니면 깔려 있던 것을 끕니다.
step "Claude Code 작업 시간 보내기 (cc-timelog-push)"
push_bin="$HOME/.local/bin/cc-timelog-push"
unit_dir="$HOME/.config/systemd/user"
want_push_service='[Unit]
Description=Claude Code 작업 turn 목록을 헤르메스 노드의 cc-timelog inbox 로 보내기 (settingfiles)

[Service]
Type=oneshot
# settingfiles install-control-node.sh 가 씁니다(control-node/cc-timelog-push.sh). 네트워크와 인증서 실패는
# 로그만 남기고 0 으로 끝나므로 유닛이 failed 가 되지 않습니다.
# 보낼 노드(CC_TIMELOG_NODES)는 저장소 밖의 이 파일에 둡니다. 없으면 server-automation host_vars 의 ansible_host.
EnvironmentFile=-%h/.config/cc-timelog-push.env
ExecStart=%h/.local/bin/cc-timelog-push
TimeoutStartSec=5min
Nice=10'
want_push_timer='[Unit]
Description=Claude Code 작업 turn 목록 보내기 타이머 (settingfiles)

[Timer]
# 30분마다. 노드의 하루 마무리(22:30)보다 먼저 들어가게 정각과 반이 아니라 10분과 40분에 돕니다. 꺼져 있는
# 동안 놓친 차례는 켠 뒤 한 번 돕니다(Persistent).
OnCalendar=*:10/30
Persistent=true
AccuracySec=1min

[Install]
WantedBy=timers.target'
user_file() {  # user_file <경로> <내용> : 다르면 씁니다. 썼으면 0.
  if [ "$(cat "$1" 2>/dev/null)" = "$2" ]; then
    ok "$1"; return 1
  elif doing; then
    mkdir -p "$(dirname "$1")"
    printf '%s\n' "$2" > "$1"
    did "$1"; return 0
  else
    todo "$1 없음 또는 다름"; return 1
  fi
}
if [ "$CC_TIMELOG_PUSH" = yes ]; then
  if cmp -s "$HERE/control-node/cc-timelog-push.sh" "$push_bin"; then
    ok "$push_bin"
  elif doing; then
    install -D -m 755 "$HERE/control-node/cc-timelog-push.sh" "$push_bin"
    did "$push_bin"
  else
    todo "$push_bin 없음 또는 다름"
  fi
  reload=0
  user_file "$unit_dir/cc-timelog-push.service" "$want_push_service" && reload=1
  user_file "$unit_dir/cc-timelog-push.timer" "$want_push_timer" && reload=1
  if [ "$reload" -eq 1 ]; then systemctl --user daemon-reload; fi
  if systemctl --user is-enabled -q cc-timelog-push.timer 2>/dev/null; then
    if [ "$reload" -eq 1 ]; then systemctl --user restart cc-timelog-push.timer; fi
    ok "cc-timelog-push.timer 켜짐"
  elif doing; then
    systemctl --user enable --now cc-timelog-push.timer
    did "cc-timelog-push.timer 켬(결과는 journalctl --user -u cc-timelog-push)"
  else
    todo "cc-timelog-push.timer 꺼짐"
  fi
  cc="$SA/roles/hermes_agent/files/scripts/cc-activity"
  if [ -x "$cc" ] && "$cc" turns --help >/dev/null 2>&1; then
    ok "cc-activity turns ($cc)"
  else
    todo "server-automation 의 cc-activity 에 turns 가 없음(pull 하기 전까지 타이머는 아무것도 보내지 않음)"
  fi
elif [ -e "$unit_dir/cc-timelog-push.timer" ] || [ -e "$push_bin" ]; then
  if doing; then
    systemctl --user disable --now cc-timelog-push.timer 2>/dev/null || true
    rm -f "$unit_dir/cc-timelog-push.timer" "$unit_dir/cc-timelog-push.service" "$push_bin"
    systemctl --user daemon-reload
    did "cc-timelog-push 지움(CONTROL_CC_TIMELOG_PUSH 가 yes 가 아님)"
  else
    todo "cc-timelog-push 가 깔려 있음(CONTROL_CC_TIMELOG_PUSH 가 yes 가 아니어서 지울 것)"
  fi
else
  ok "이 기기는 보내지 않음(CONTROL_CC_TIMELOG_PUSH 가 yes 가 아님)"
fi

# --- 10. 전역 CLAUDE.md ------------------------------------------------------------
# 이 기기의 Claude Code 세션이 모두 읽는 안내(~/.claude/CLAUDE.md)를 control-node/CLAUDE.md 에서 깝니다. 지금은
# 작업에서 알게 된 것을 llm-wiki 에 쌓는 절 하나입니다(2026-10-28 사용자 결정). 노드에는 server-automation 의
# agentic_coding role 이 같은 절을 깝니다. 손으로 둔 다른 파일이 있으면 덮어쓰지 않고 알립니다.
step "전역 CLAUDE.md (~/.claude/CLAUDE.md)"
claude_md="$HOME/.claude/CLAUDE.md"
if cmp -s "$HERE/control-node/CLAUDE.md" "$claude_md"; then
  ok "$claude_md"
elif [ -e "$claude_md" ] && ! grep -q 'install-control-node.sh' "$claude_md"; then
  todo "$claude_md 가 손으로 둔 파일이라 덮어쓰지 않음(control-node/CLAUDE.md 와 합쳐 주세요)"
elif doing; then
  install -D -m 644 "$HERE/control-node/CLAUDE.md" "$claude_md"
  did "$claude_md (새 세션부터)"
else
  todo "$claude_md 없음 또는 다름"
fi

# --- 11. herdr --------------------------------------------------------------------
# 노드의 herdr 를 이 기기에서 원격으로 엽니다(herdr --remote <ssh 대상>, 저장해 두려면 herdr machine add). 그러면
# 화면이 이 기기에서 돌아 복사가 로컬 클립보드(wl-copy, desktop 프로필의 wl-clipboard)로 갑니다. ssh 안에서 띄운
# herdr 는 OSC 52 로 복사하는데 GNOME Terminal 은 그것을 받지 않습니다(2026-11-13, Ghostty 는 받음). 노드처럼
# 공식 설치 스크립트로 ~/.local/bin/herdr 에 깔고(server-automation roles/agentic_coding/tasks/herdr.yml), 공개
# 최신판보다 낮으면 올립니다. 스크립트는 latest.json 의 SHA-256 으로 바이너리를 대조합니다.
step "herdr (~/.local/bin/herdr)"
herdr_bin="$HOME/.local/bin/herdr"
herdr_have=$("$herdr_bin" --version 2>/dev/null | awk '{print $NF}' || true)
herdr_latest=$(curl -fsSL --max-time 20 https://herdr.dev/latest.json 2>/dev/null \
  | python3 -c 'import json,sys; print(json.load(sys.stdin).get("version", ""))' 2>/dev/null || true)
if [ -n "$herdr_have" ] && { [ -z "$herdr_latest" ] \
    || [ "$(printf '%s\n' "$herdr_latest" "$herdr_have" | sort -V | sed -n 1p)" = "$herdr_latest" ]; }; then
  ok "herdr $herdr_have${herdr_latest:+ (공개 최신 $herdr_latest)}"
elif doing; then
  herdr_sh=$(mktemp)
  curl -fsSL --max-time 60 -o "$herdr_sh" https://herdr.dev/install.sh
  HERDR_INSTALL_DIR="$HOME/.local/bin" sh "$herdr_sh"
  rm -f "$herdr_sh"
  did "herdr $("$herdr_bin" --version 2>/dev/null | awk '{print $NF}')"
else
  todo "herdr ${herdr_have:-없음}${herdr_latest:+, 공개 최신 $herdr_latest}"
fi
# herdr 를 주 작업 환경으로 쓰므로(2026-11-13 사용자 결정) 이 기기의 Claude 에도 herdr 의 Claude 통합을 깝니다
# (~/.claude/hooks/herdr-agent-state.sh 와 settings.json 의 SessionStart 훅 한 줄. 노드는 server-automation 의
# agentic_coding role 이 깝니다). herdr 를 올려 통합의 판이 오르면 다시 깝니다. grep -q 는 쓰지 않습니다(pipefail 에서
# 앞 명령이 SIGPIPE 로 끝나 "없음"으로 읽힘).
if [ -x "$herdr_bin" ]; then
  if "$herdr_bin" integration status 2>/dev/null | grep '^claude: current' >/dev/null; then
    ok "herdr Claude 통합"
  elif doing; then
    "$herdr_bin" integration install claude >/dev/null
    did "herdr Claude 통합(새 Claude 세션부터)"
  else
    todo "herdr Claude 통합 없음 또는 낡음"
  fi
fi
manual+=("herdr 원격: herdr machine add <노드의 ssh 주소> 로 저장하거나 herdr --remote <노드의 ssh 주소>(주소는 server-automation 의 host_vars). 백그라운드 재접속은 인증서 키가 ssh-agent 에 있을 때만 조용히 됩니다(5절의 자동 시작이 로그인 때 올림).")

# --- 12. SSH 로 들어오기 ----------------------------------------------------------------
# 다른 기기(주로 데스크탑)에서 이 컨트롤 노드로 SSH 로 들어와 herdr 로 Claude 를 쓰게 합니다(2026-11-24 사용자 결정).
# 컨트롤 노드는 플레이북과 서명 키를 쥐고 있어 노드보다 강하게 둡니다(사용자: "인증서 사용하지 않고 토큰만").
#  - 받는 키는 토큰(FIDO2) A, B 뿐이고 접속마다 터치합니다. 사용자 인증서(CA)는 믿지 않고, sshd 가 sk 알고리즘만
#    받으므로 authorized_keys 에 다른 키가 잘못 들어가도 쓰이지 않습니다. 공개키는 server-automation 의 파일에서
#    가져옵니다(이 공개 저장소에 키를 두지 않음).
#  - sshd 는 늘 켜 두지 않습니다. outside 프로필처럼 밖(카페 등)에서는 꺼 두고, 아래 목록의 집 연결(NetworkManager
#    연결 UUID)에 붙어 있을 때만 NetworkManager 디스패처가 켭니다. 목록은 이 기기에만 둡니다(저장소에 넣지 않음).
#  - 방화벽은 ssh 를 사설(IPv4), 링크 로컬과 ULA(IPv6) 출발지에서만 받습니다. IPv6 는 공인 주소라 공유기 밖에서
#    닿을 수 있습니다.
step "SSH 로 들어오기(토큰 키만, 집 네트워크에서만)"
ak="$HOME/.ssh/authorized_keys"
ak_begin='# >>> settingfiles install-control-node.sh: token keys (managed) >>>'
ak_end='# <<< settingfiles install-control-node.sh: token keys (managed) <<<'
lan_from='10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,fe80::/10,fc00::/7'
want_ak=""
for k in ljlee_sk_a ljlee_sk_b; do
  pub="$SA/roles/common/files/keys/$k.pub"
  [ -f "$pub" ] || continue
  want_ak+="from=\"$lan_from\" $(awk '{print $1, $2}' "$pub") $k"$'\n'
done
want_ak="${want_ak%$'\n'}"
ak_block() { awk -v b="$ak_begin" -v e="$ak_end" '$0==e{f=0} f{print} $0==b{f=1}' "$ak" 2>/dev/null || true; }
if [ -z "$want_ak" ]; then
  todo "토큰 공개키가 없음($SA/roles/common/files/keys/ljlee_sk_a.pub, ljlee_sk_b.pub)"
elif [ "$(ak_block)" = "$want_ak" ]; then
  ok "$ak 의 토큰 키 A, B"
elif doing; then
  mkdir -p -m 700 "$HOME/.ssh"
  ak_tmp=$(mktemp)
  if [ -f "$ak" ]; then awk -v b="$ak_begin" -v e="$ak_end" '$0==b{s=1} !s{print} $0==e{s=0}' "$ak" > "$ak_tmp"; fi
  printf '%s\n%s\n%s\n' "$ak_begin" "$want_ak" "$ak_end" >> "$ak_tmp"
  install -m 600 "$ak_tmp" "$ak"
  rm -f "$ak_tmp"
  did "$ak 의 토큰 키 A, B(LAN 출발지만)"
else
  todo "$ak 에 토큰 키 블록이 없거나 다름"
fi

sshd_conf=/etc/ssh/sshd_config.d/20-control-node.conf
want_sshd="# settingfiles install-control-node.sh 12절: 컨트롤 노드로 들어오는 SSH 는 토큰(FIDO2) 키만, 접속마다 터치.
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
PermitRootLogin no
AuthenticationMethods publickey
PubkeyAcceptedAlgorithms sk-ecdsa-sha2-nistp256@openssh.com,sk-ssh-ed25519@openssh.com
PubkeyAuthOptions touch-required
AllowUsers $USER"
if [ "$(cat "$sshd_conf" 2>/dev/null)" = "$want_sshd" ]; then
  ok "$sshd_conf"
elif doing; then
  printf '%s\n' "$want_sshd" | sudo install -D -m 644 /dev/stdin "$sshd_conf"
  if sudo sshd -t; then
    if systemctl is-active -q sshd.service; then sudo systemctl reload sshd.service; fi
    did "$sshd_conf"
  else
    sudo rm -f "$sshd_conf"
    todo "$sshd_conf 가 sshd -t 를 통과하지 못해 지움"
  fi
else
  todo "$sshd_conf 없음 또는 다름"
fi

# 디스패처가 켜고 끄므로 부팅 때 저절로 켜지지 않게 합니다.
if ! systemctl is-enabled -q sshd.service 2>/dev/null; then
  ok "sshd.service 는 부팅 때 켜지지 않음(디스패처가 켬)"
elif doing; then
  sudo systemctl disable -q sshd.service
  did "sshd.service 부팅 때 켜기를 끔(디스패처가 켬)"
else
  todo "sshd.service 가 부팅 때 켜짐(밖에서도 켜짐)"
fi
if systemctl is-enabled -q NetworkManager-dispatcher.service 2>/dev/null; then
  ok "NetworkManager-dispatcher.service"
elif doing; then
  sudo systemctl enable -q --now NetworkManager-dispatcher.service
  did "NetworkManager-dispatcher.service 켬"
else
  todo "NetworkManager-dispatcher.service 꺼져 있음"
fi
disp=/etc/NetworkManager/dispatcher.d/50-control-node-sshd
nets=/etc/control-node-sshd-networks
want_disp='#!/bin/sh
# settingfiles install-control-node.sh 12절: 이 기기가 /etc/control-node-sshd-networks 에 적힌 연결(NetworkManager
# 연결 UUID, 한 줄에 하나)에 붙어 있을 때만 sshd 를 켜고, 아니면 끕니다. 목록이 없거나 비면 늘 끕니다.
case "$2" in up|down|vpn-up|vpn-down) ;; *) exit 0 ;; esac
nets=/etc/control-node-sshd-networks
for uuid in $(nmcli -t -f UUID connection show --active 2>/dev/null); do
  if [ -r "$nets" ] && grep -qxF "$uuid" "$nets"; then exec systemctl start sshd.service; fi
done
exec systemctl stop sshd.service'
if [ "$(cat "$disp" 2>/dev/null)" = "$want_disp" ] && [ -x "$disp" ]; then
  ok "$disp"
elif doing; then
  printf '%s\n' "$want_disp" | sudo install -D -m 755 /dev/stdin "$disp"
  did "$disp"
else
  todo "$disp 없음 또는 다름"
fi
# 집 연결 목록. 사람이 있는 터미널에서 돌릴 때 지금 붙은 연결을 집으로 넣을지 묻습니다.
if [ -s "$nets" ]; then
  ok "$nets(집 연결 $(grep -c . "$nets")개)"
elif doing && [ -t 0 ]; then
  # UUID 를 앞에 둡니다(이름에 : 가 있으면 nmcli -t 가 \: 로 바꿔 뒤 칸이 밀림).
  net_now=$(nmcli -t -f UUID,TYPE,NAME connection show --active 2>/dev/null | awk -F: '$2!="loopback"{print; exit}')
  if [ -n "$net_now" ]; then
    net_uuid=${net_now%%:*}
    net_name=${net_now#*:*:}
    yn=""
    read -r -p "   지금 붙은 연결 '$net_name' 을 집 네트워크로 넣을까요(그 연결에서만 sshd 를 켬)? [y/N] " yn || true
    if [ "$yn" = y ]; then
      printf '%s\n' "$net_uuid" | sudo install -m 644 /dev/stdin "$nets"
      sudo "$disp" none up   # 디스패처를 한 번 돌려 지금 상태에 맞춤
      did "$nets($net_name)"
    else
      todo "$nets 없음(sshd 는 늘 꺼짐)"
    fi
  else
    todo "$nets 없음, 지금 붙은 연결도 없음"
  fi
else
  todo "$nets 없음(sshd 는 늘 꺼짐)"
fi

nft_conf=/etc/nftables.conf
nft_old='tcp dport ssh accept comment "allow sshd"'
nft_new4='ip saddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 } tcp dport ssh accept comment "allow sshd from private LAN (settingfiles control node)"'
nft_new6='ip6 saddr { fe80::/10, fc00::/7 } tcp dport ssh accept comment "allow sshd from link-local and ULA (settingfiles control node)"'
if grep -qF "$nft_new4" "$nft_conf" 2>/dev/null && grep -qF "$nft_new6" "$nft_conf" && ! grep -qF "$nft_old" "$nft_conf"; then
  ok "$nft_conf ssh 는 LAN 출발지만"
elif grep -qF "$nft_old" "$nft_conf" 2>/dev/null && ! doing; then
  todo "$nft_conf 가 ssh 를 어느 출발지에서나 받음(LAN 출발지로 좁힐 것)"
elif grep -qF "$nft_old" "$nft_conf" 2>/dev/null; then
  nft_tmp=$(mktemp)
  awk -v old="$nft_old" -v n4="$nft_new4" -v n6="$nft_new6" '{
    s = $0; sub(/^[ \t]+/, "", s)
    if (s == old) { ind = substr($0, 1, length($0) - length(s)); print ind n4; print ind n6 } else print
  }' "$nft_conf" > "$nft_tmp"
  if sudo nft -c -f "$nft_tmp"; then
    sudo install -m 644 "$nft_tmp" "$nft_conf"
    # print.sh 와 같은 까닭으로 파일을 직접 다시 읽음(Arch nftables.service 는 reload 가 없음)
    if systemctl is-enabled -q nftables 2>/dev/null; then sudo nft -f "$nft_conf"; fi
    did "$nft_conf ssh 를 LAN 출발지로 좁힘"
  else
    todo "$nft_conf 바꾼 규칙이 nft -c 를 통과하지 못해 그대로 둠"
  fi
  rm -f "$nft_tmp"
else
  todo "$nft_conf 에서 ssh 규칙('$nft_old')을 찾지 못함, 손으로 LAN 출발지만 받게 고치세요"
fi
manual+=("다른 기기에서 이 컨트롤 노드로 들어올 때는 토큰 A 나 B 를 그 기기에 꽂고 핸들 파일로 접속합니다(접속마다 터치). 그 기기의 ~/.ssh/config 에는 AddressFamily inet 을 둡니다(mDNS 가 IPv6 공인 주소를 먼저 주면 방화벽에 막힘). 집 연결을 더하거나 빼려면 /etc/control-node-sshd-networks(연결 UUID 한 줄에 하나, nmcli -t -f NAME,UUID connection show)를 고친 뒤 그 연결에 다시 붙습니다.")

# --- 손으로 할 것 -----------------------------------------------------------------
manual+=("Claude Code 로그인(claude 를 한 번 실행)과, 다른 세션과 대화할 때 /remote-control.")
manual+=("vault 비밀번호는 어디에도 저장하지 않습니다. check, apply 때 --ask-vault-pass 로 칩니다.")
manual+=("FIDO2 토큰 A(서명, 로그인)와 B(백업), 오프라인 비상용 마스터 키는 이 스크립트 밖입니다.")
step "손으로 할 것"
for m in "${manual[@]}"; do printf '   - %s\n' "$m"; done
