# desktop 프로필 설정: 블루투스 서비스, 기본 편집기 nvim, 터미널 앱 Ghostty, SSH 에이전트(FIDO2).
#
# 기본 텍스트 편집기는 nvim 입니다(2026-11-13 사용자 결정). nvim.desktop 이 받는 MIME 형식마다 이 사용자의
# ~/.config/mimeapps.list 에 기본으로 적습니다(GNOME, Plasma 둘 다 이 파일을 봄). 셸의 $EDITOR 는 .zshrc 가 이미 nvim 입니다.
# nvim, htop 처럼 터미널에서 도는 앱(Terminal=true)을 띄우는 터미널은 데스크톱마다 따로 정합니다.
#  - GTK(GLib): xdg-terminal-exec 가 ~/.config/xdg-terminals.list 의 앱을 고름
#  - KDE(KIO 6.32): kdeglobals [General] TerminalApplication, 없으면 konsole 이라 Konsole 이 없는 기기에서는
#    "터미널 konsole 을 찾을 수 없음"으로 실패함(2026-11-18 LJGaming). Dolphin 의 "터미널 열기"도 이 값을 봄.
#    TerminalService 는 비워 둡니다. Ghostty 데스크톱 파일의 Exec 에 --gtk-single-instance=true 가 있어 작업 폴더가 안 넘어갈 수 있음.
# GNOME Terminal 과 Konsole 은 OSC 52 를 받지 않아 Ghostty 로 둡니다(ghostty-config). 모두 사용자 설정이라 설치 중
# chroot(root)에서는 건너뛰고, 첫 부팅 뒤 사용자로 다시 돌리면 채웁니다.
#
# SSH 에이전트: GNOME 의 gcr-ssh-agent 는 FIDO2(sk-*) 키 서명을 구현하지 않아 "agent refused operation" 으로 실패합니다.
# 그래서 OpenSSH 자체 에이전트(사용자 유닛 ssh-agent.socket)를 켜고 gcr-ssh-agent 는 mask 합니다. 이 유닛은 켜질 때
# SSH_AUTH_SOCK 을 자기 소켓으로 덮어쓰고, GNOME 세션(gnome-session 51 의 gnome-session-services.target)이 Wants= 로
# 끌어오므로 disable 만으로는 다음 GNOME 로그인에 다시 켜집니다(2026-11-18 LJTF 에서 disabled 인데 active 로 확인).
# environment.d 로 GNOME, Plasma 세션 모두 같은 에이전트와
# ksshaskpass 를 씁니다. SSH_ASKPASS_REQUIRE=prefer 로 터미널에서 돌려도 토큰 PIN 과 키 암호를 ksshaskpass 창으로 묻습니다
# (2026-11-19 사용자 결정, ArchWiki 「KDE Wallet」). 토큰 PIN 은 창의 Remember password 를 켜지 않습니다(지갑이 열린 동안 터치만으로
# 쓰이게 됨). 키 파일 암호(인증서 키 id_ed25519)는 기억시켜도 됩니다.
# environment.d 는 사용자 관리자가 다시 뜰 때 읽으므로(linger 면 재부팅) 지금 관리자에는 set-environment 로도 넣습니다.
EDITOR_DESKTOP=nvim.desktop
TERMINAL_DESKTOP=com.mitchellh.ghostty.desktop
TERMINAL_LIST="${XDG_CONFIG_HOME:-$HOME/.config}/xdg-terminals.list"
editor_types() { sed -n 's/^MimeType=//p' "/usr/share/applications/$EDITOR_DESKTOP" | tr ';' ' '; }
editor_ok() { [ "$(xdg-mime query default text/plain 2>/dev/null)" = "$EDITOR_DESKTOP" ]; }
terminal_ok() { [ "$(cat "$TERMINAL_LIST" 2>/dev/null)" = "$TERMINAL_DESKTOP" ]; }
kde_terminal_ok() { [ "$(kreadconfig6 --file kdeglobals --group General --key TerminalApplication 2>/dev/null)" = ghostty ]; }
AGENT_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d/61-ssh-agent.conf"
AGENT_WANT='SSH_AUTH_SOCK=${XDG_RUNTIME_DIR}/ssh-agent.socket
SSH_ASKPASS=/usr/bin/ksshaskpass
SSH_ASKPASS_REQUIRE=prefer'
agent_conf_ok() { [ "$(grep -v -E '^\s*(#|$)' "$AGENT_CONF" 2>/dev/null)" = "$AGENT_WANT" ]; }
agent_on() { systemctl --user is-enabled -q ssh-agent.socket 2>/dev/null; }
gcr_off() { [ "$(systemctl --user is-enabled gcr-ssh-agent.socket 2>/dev/null)" = masked ] && ! systemctl --user is-active -q gcr-ssh-agent.socket 2>/dev/null; }
post() {
  enable_unit bluetooth.service
  if [ "$(id -u)" -eq 0 ]; then todo "기본 편집기와 터미널은 첫 부팅 뒤 사용자로 다시 돌릴 때 정함"; return 0; fi
  if editor_ok; then ok "기본 편집기 nvim"; else
    # shellcheck disable=SC2046  # MIME 형식을 낱개 인자로
    xdg-mime default "$EDITOR_DESKTOP" $(editor_types)
    did "기본 편집기 nvim(~/.config/mimeapps.list)"
  fi
  if terminal_ok; then ok "터미널 앱은 Ghostty(GTK)"; else
    mkdir -p "$(dirname "$TERMINAL_LIST")"
    printf '%s\n' "$TERMINAL_DESKTOP" > "$TERMINAL_LIST"
    did "터미널 앱은 Ghostty($TERMINAL_LIST)"
  fi
  if agent_on; then ok "ssh-agent.socket(OpenSSH 에이전트)"; else
    systemctl --user enable --now ssh-agent.socket
    did "ssh-agent.socket 켬"
  fi
  if gcr_off; then ok "gcr-ssh-agent 막힘(mask)"; else
    systemctl --user mask --now gcr-ssh-agent.socket gcr-ssh-agent.service
    did "gcr-ssh-agent mask(sk 키 서명을 거절함. GNOME 세션이 다시 켜지 못하게)"
  fi
  if agent_conf_ok; then ok "SSH_AUTH_SOCK, SSH_ASKPASS, SSH_ASKPASS_REQUIRE($AGENT_CONF)"; else
    mkdir -p "$(dirname "$AGENT_CONF")"
    printf '# settingfiles desktop.sh: OpenSSH 에이전트(FIDO2 sk 키)와 PIN, 암호를 묻는 창(터미널에서도)\n%s\n' "$AGENT_WANT" > "$AGENT_CONF"
    systemctl --user set-environment SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket" SSH_ASKPASS=/usr/bin/ksshaskpass SSH_ASKPASS_REQUIRE=prefer
    did "SSH_AUTH_SOCK, SSH_ASKPASS, SSH_ASKPASS_REQUIRE($AGENT_CONF, 새로 여는 앱부터. 이미 뜬 셸과 앱은 다시 열 때)"
  fi
  if command -v kwriteconfig6 >/dev/null; then
    if kde_terminal_ok; then ok "터미널 앱은 Ghostty(KDE)"; else
      kwriteconfig6 --notify --file kdeglobals --group General --key TerminalApplication ghostty
      did "터미널 앱은 Ghostty(kdeglobals TerminalApplication)"
    fi
  fi
}
check() {
  if systemctl is-enabled -q bluetooth.service 2>/dev/null; then ok bluetooth.service; else todo "bluetooth.service 꺼져 있음"; fi
  if editor_ok; then ok "기본 편집기 nvim"; else todo "기본 편집기가 nvim 이 아님"; fi
  if terminal_ok; then ok "터미널 앱은 Ghostty(GTK)"; else todo "터미널 앱 목록($TERMINAL_LIST)이 Ghostty 가 아님"; fi
  if agent_on; then ok "ssh-agent.socket(OpenSSH 에이전트)"; else todo "ssh-agent.socket 꺼져 있음"; fi
  if gcr_off; then ok "gcr-ssh-agent 막힘(mask)"; else todo "gcr-ssh-agent 가 mask 되지 않음(GNOME 세션이 다시 켜고 FIDO2 sk 키 서명을 거절함)"; fi
  if agent_conf_ok; then ok "SSH_AUTH_SOCK, SSH_ASKPASS, SSH_ASKPASS_REQUIRE($AGENT_CONF)"; else todo "$AGENT_CONF 가 다름"; fi
  if command -v kreadconfig6 >/dev/null; then
    if kde_terminal_ok; then ok "터미널 앱은 Ghostty(KDE)"; else todo "kdeglobals TerminalApplication 이 ghostty 가 아님"; fi
  fi
}
