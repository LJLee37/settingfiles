# gnome 프로필 설정.
#
# 기본 텍스트 편집기는 nvim 입니다(2026-11-13 사용자 결정). nvim.desktop 이 받는 MIME 형식마다 이 사용자의
# ~/.config/mimeapps.list 에 기본으로 적습니다. 셸의 $EDITOR 는 .zshrc 가 이미 nvim 입니다.
# nvim 처럼 터미널에서 도는 앱(Terminal=true)은 GLib 이 xdg-terminal-exec 로 띄우고, 그것이
# ~/.config/xdg-terminals.list 의 앱(Ghostty)을 고릅니다. GNOME Terminal 은 OSC 52 를 받지 않아 Ghostty 로
# 둡니다(ghostty-config). 둘 다 사용자 설정이라 설치 중 chroot(root)에서는 건너뛰고, 첫 부팅 뒤 사용자로 다시
# 돌리면 채웁니다.
EDITOR_DESKTOP=nvim.desktop
TERMINAL_DESKTOP=com.mitchellh.ghostty.desktop
TERMINAL_LIST="${XDG_CONFIG_HOME:-$HOME/.config}/xdg-terminals.list"

editor_types() { sed -n 's/^MimeType=//p' "/usr/share/applications/$EDITOR_DESKTOP" | tr ';' ' '; }
editor_ok() { [ "$(xdg-mime query default text/plain 2>/dev/null)" = "$EDITOR_DESKTOP" ]; }
terminal_ok() { [ "$(cat "$TERMINAL_LIST" 2>/dev/null)" = "$TERMINAL_DESKTOP" ]; }

post() {
  enable_unit gdm
  if [ "$(id -u)" -eq 0 ]; then todo "기본 편집기와 터미널은 첫 부팅 뒤 사용자로 다시 돌릴 때 정함"; return 0; fi
  if editor_ok; then ok "기본 편집기 nvim"; else
    # shellcheck disable=SC2046  # MIME 형식을 낱개 인자로
    xdg-mime default "$EDITOR_DESKTOP" $(editor_types)
    did "기본 편집기 nvim(~/.config/mimeapps.list)"
  fi
  if terminal_ok; then ok "터미널 앱은 Ghostty"; else
    mkdir -p "$(dirname "$TERMINAL_LIST")"
    printf '%s\n' "$TERMINAL_DESKTOP" > "$TERMINAL_LIST"
    did "터미널 앱은 Ghostty($TERMINAL_LIST)"
  fi
}

check() {
  if systemctl is-enabled -q gdm 2>/dev/null; then ok gdm; else todo "gdm 꺼져 있음"; fi
  if editor_ok; then ok "기본 편집기 nvim"; else todo "기본 편집기가 nvim 이 아님"; fi
  if terminal_ok; then ok "터미널 앱은 Ghostty"; else todo "터미널 앱 목록($TERMINAL_LIST)이 Ghostty 가 아님"; fi
}
