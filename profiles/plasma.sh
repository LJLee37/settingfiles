# plasma 프로필 설정: 한글 입력(IBus Wayland), 오른쪽 Alt 를 한/영 키로, XWayland 앱(Steam)의 한글 입력.
# 모두 사용자 설정이라 root(설치 중 chroot)에서는 건너뜁니다. 2026-11-18 LJGaming 에서 손으로 한 것을 옮겼습니다.
#
# - IBus: GNOME 은 자기 입력 소스로 IBus 를 관리해서, GNOME 밖에서는 preload-engines 가 비어 있음. Plasma Wayland 는
#   KWin 이 입력기를 띄워야 함(시스템 설정 > 키보드 > 가상 키보드 > IBus Wayland 와 같은 값).
# - 한/영: 오른쪽 Alt 가 XKB 에서는 Alt_R 이라 한/영+스페이스가 Plasma 의 Alt+Space(KRunner)로 감. 그래서 korean:ralt_hangul.
#   KWin 6.8 은 kxkbrc 변경 알림(kwriteconfig6 --notify, 값이 바뀔 때만 감)으로만 다시 읽고, Options 는
#   ResetOldOptions=true 일 때만 적용함. 그래서 Options 를 맨 마지막에 씀.
# - XMODIFIERS: Plasma Wayland 는 XWayland 앱에 넣어 주지 않음(GNOME 은 넣음). GTK_IM_MODULE, QT_IM_MODULE 은 Wayland 앱을
#   위해 넣지 않음. Steam 에만 GTK_IM_MODULE=ibus 를 주는 데스크톱 파일 사본은 아래 appearance_post 가 만듦.
# - 로그인 때 KWallet 을 여는 PAM(pam_kwallet5)은 /etc/pam.d 의 로그인 화면 파일을 고쳐야 해서 여기서 하지 않고 check 만 함.
IBUS_IM=/usr/share/applications/org.freedesktop.IBus.Panel.Wayland.Gtk3.desktop
XIM_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d/60-ibus-xim.conf"
kv() { kreadconfig6 --file "$1" --group "$2" --key "$3" 2>/dev/null; }
im_ok() { [ "$(kv kwinrc Wayland InputMethod)" = "$IBUS_IM" ]; }
engines_ok() { gsettings get org.freedesktop.ibus.general preload-engines 2>/dev/null | grep -q hangul; }
hangul_key_ok() { [ "$(kv kxkbrc Layout Options)" = korean:ralt_hangul ] && [ "$(kv kxkbrc Layout ResetOldOptions)" = true ]; }
xim_ok() { grep -qx 'XMODIFIERS=@im=ibus' "$XIM_CONF" 2>/dev/null; }
# 로그인 화면의 PAM 파일은 /etc/pam.d 에 덮어쓴 것이 있으면 그것, 없으면 패키지 기본값(/usr/lib/pam.d)을 봅니다. plasmalogin 의
# 기본값에는 pam_kwallet5 가 이미 있습니다(plasma-login-manager 6.8.3, 2026-11-19 LJGaming 확인).
pam_file() { local f; for f in "/etc/pam.d/$1" "/usr/lib/pam.d/$1"; do [ -f "$f" ] && { echo "$f"; return 0; }; done; return 1; }
kwallet_pam_ok() { local s f; for s in plasmalogin gdm-password; do f=$(pam_file "$s") && grep -qs pam_kwallet5 "$f" && return 0; done; return 1; }
# --- 모양과 동작(2026-11-18 LJGaming 의 Plasma 를 옮김. 배경과 잠금 화면 이미지, 모니터별 화면 설정은 뺌) ---
# - 테마: Breeze 어두운 테마(룩앤필) 위에 색 구성표 "하늘보라 다크"(profiles/plasma/SkyVioletDark.colors)와 아이콘
#   Tela-circle-purple-dark. 룩앤필을 적용하면 색과 아이콘이 Breeze Dark 것으로 돌아가므로 룩앤필, 색, 아이콘 순서로 씁니다.
# - 패널: 화면마다 하단 패널(profiles/plasma/panels.js). plasmashell 이 떠 있을 때만(Plasma 세션에서 돌릴 때) 합니다.
# - 설정값(PLASMA_SETTINGS): Dolphin 이 원격(NAS) 파일도 50 MiB 까지 미리보기, 전원(AC) 15분 뒤 화면 어둡게 30분 뒤 끄기와
#   자동 절전 안 함, 30분 뒤 화면 잠금(잠근 즉시 비밀번호), 모든 마우스 자연 스크롤. 마우스는 KWin 이 장치를 붙일 때 읽는
#   kcminputrc [Libinput][Defaults][Pointer] 라 새 마우스에도 들어가고, 장치별 값([Libinput][제조사][제품][이름])이 있으면 그것이
#   우선합니다(KWin 6.8 src/backends/libinput/connection.cpp applyDeviceConfig). 지금 꽂힌 마우스는 다시 꽂거나 다음 로그인부터.
# - Steam: XWayland 의 XIM 으로는 빠른 한글 입력이 깨져 Steam 에만 GTK_IM_MODULE=ibus 를 주는 데스크톱 파일 사본을 둡니다
#   (메뉴용 사본, 그리고 Steam 이 자동 시작 파일을 만들어 둔 경우 그 파일). steam 패키지가 원본을 바꾸면 다시 돌려 맞춥니다.
PLASMA_DIR=profiles/plasma
LNF=org.kde.breezedark.desktop
SCHEME=SkyVioletDark
ICONS=Tela-circle-purple-dark
SCHEME_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/color-schemes/$SCHEME.colors"
STEAM_SYS=/usr/share/applications/steam.desktop
STEAM_MENU="${XDG_DATA_HOME:-$HOME/.local/share}/applications/steam.desktop"
STEAM_AUTO="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/steam.desktop"
# 파일|그룹(> 로 겹침)|키|값
PLASMA_SETTINGS='kdeglobals|PreviewSettings|MaximumRemoteSize|52428800
powerdevilrc|AC>Display|DimDisplayIdleTimeoutSec|900
powerdevilrc|AC>Display|TurnOffDisplayIdleTimeoutSec|1800
powerdevilrc|AC>SuspendAndShutdown|AutoSuspendAction|0
kscreenlockerrc|Daemon|Timeout|30
kscreenlockerrc|Daemon|LockGrace|0
kcminputrc|Libinput>Defaults>Pointer|NaturalScroll|true'
setting_args() { local IFS='>' g; for g in $1; do printf -- '--group\n%s\n' "$g"; done; }
setting_get() { local a; mapfile -t a < <(setting_args "$2"); kreadconfig6 --file "$1" "${a[@]}" --key "$3" 2>/dev/null; }
setting_set() { local a; mapfile -t a < <(setting_args "$2"); kwriteconfig6 --notify --file "$1" "${a[@]}" --key "$3" "$4"; }
plasma_running() { qdbus6 org.kde.plasmashell /PlasmaShell >/dev/null 2>&1; }
panels_eval() { qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(printf 'var MODE = "%s";\n' "$1"; cat "$PLASMA_DIR/panels.js")"; }
panels_report() { while IFS= read -r l; do case $l in "ok: "*) ok "${l#ok: }" ;; "did: "*) did "${l#did: }" ;; "todo: "*) todo "${l#todo: }" ;; esac; done; }
lnf_ok() { [ "$(kv kdeglobals KDE LookAndFeelPackage)" = "$LNF" ]; }
scheme_file_ok() { cmp -s "$PLASMA_DIR/$SCHEME.colors" "$SCHEME_FILE"; }
scheme_ok() { scheme_file_ok && [ "$(kv kdeglobals General ColorScheme)" = "$SCHEME" ]; }
icons_ok() { [ "$(kv kdeglobals Icons Theme)" = "$ICONS" ]; }
steam_copy() {  # 원본에 주석 한 줄을 넣고 Exec 마다 env GTK_IM_MODULE=ibus 를 붙인 사본
  sed -e '1a # settingfiles plasma.sh: Steam 에만 GTK_IM_MODULE=ibus(빠른 한글 입력). '"$STEAM_SYS"' 의 사본' \
      -e 's|^Exec=/usr/bin/steam|Exec=env GTK_IM_MODULE=ibus /usr/bin/steam|' "$STEAM_SYS"
}
steam_menu_ok() { [ ! -f "$STEAM_SYS" ] || steam_copy | cmp -s - "$STEAM_MENU"; }
steam_auto_ok() { [ ! -f "$STEAM_AUTO" ] || ! grep -q '^Exec=/usr/bin/steam' "$STEAM_AUTO"; }
appearance_post() {
  if lnf_ok; then ok "전체 테마 Breeze 어두운 테마"; else
    plasma-apply-lookandfeel -a "$LNF" >/dev/null && did "전체 테마 $LNF"
  fi
  if scheme_ok; then ok "색 구성표 하늘보라 다크"; else
    if ! scheme_file_ok; then
      install -Dm644 "$PLASMA_DIR/$SCHEME.colors" "$SCHEME_FILE"
      # 이미 고른 구성표는 파일만 바뀌어도 plasma-apply-colorscheme 이 "이미 설정됨"으로 건너뛰어 잠깐 다른 것을 거칩니다
      [ "$(kv kdeglobals General ColorScheme)" != "$SCHEME" ] || plasma-apply-colorscheme BreezeDark >/dev/null
    fi
    plasma-apply-colorscheme "$SCHEME" >/dev/null && did "색 구성표 하늘보라 다크($SCHEME_FILE)"
  fi
  if icons_ok; then ok "아이콘 $ICONS"; else
    /usr/lib/plasma-changeicons "$ICONS" >/dev/null && did "아이콘 $ICONS"
  fi
  if plasma_running; then panels_eval apply | panels_report
  else todo "패널은 Plasma 세션에서 다시 돌릴 때 맞춤"; fi
  local f g k v power=0
  while IFS='|' read -r f g k v; do
    if [ "$(setting_get "$f" "$g" "$k")" = "$v" ]; then ok "$f [$g] $k=$v"; else
      setting_set "$f" "$g" "$k" "$v"; did "$f [$g] $k=$v"
      [ "$f" != powerdevilrc ] || power=1
    fi
  done <<< "$PLASMA_SETTINGS"
  [ "$power" -eq 0 ] || qdbus6 org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement \
    org.kde.Solid.PowerManagement.reparseConfiguration >/dev/null 2>&1 || true
  if steam_menu_ok; then ok "Steam 메뉴 사본(GTK_IM_MODULE=ibus)"; else
    mkdir -p "$(dirname "$STEAM_MENU")"; steam_copy > "$STEAM_MENU"; did "Steam 메뉴 사본($STEAM_MENU)"
  fi
  if steam_auto_ok; then ok "Steam 자동 시작(있으면 GTK_IM_MODULE=ibus)"; else
    sed -i 's|^Exec=/usr/bin/steam|Exec=env GTK_IM_MODULE=ibus /usr/bin/steam|' "$STEAM_AUTO"; did "Steam 자동 시작($STEAM_AUTO)"
  fi
}
appearance_check() {
  if lnf_ok; then ok "전체 테마 Breeze 어두운 테마"; else todo "전체 테마가 $LNF 이 아님"; fi
  if scheme_ok; then ok "색 구성표 하늘보라 다크"; else todo "색 구성표가 $SCHEME 이 아니거나 파일이 저장소와 다름"; fi
  if icons_ok; then ok "아이콘 $ICONS"; else todo "아이콘이 $ICONS 이 아님"; fi
  if plasma_running; then panels_eval check | panels_report
  else todo "패널은 Plasma 세션에서만 확인함"; fi
  local f g k v
  while IFS='|' read -r f g k v; do
    if [ "$(setting_get "$f" "$g" "$k")" = "$v" ]; then ok "$f [$g] $k=$v"; else todo "$f [$g] $k 가 $v 가 아님"; fi
  done <<< "$PLASMA_SETTINGS"
  if steam_menu_ok; then ok "Steam 메뉴 사본(GTK_IM_MODULE=ibus)"; else todo "Steam 메뉴 사본이 없거나 원본과 맞지 않음"; fi
  if steam_auto_ok; then ok "Steam 자동 시작(있으면 GTK_IM_MODULE=ibus)"; else todo "Steam 자동 시작 파일에 GTK_IM_MODULE 없음"; fi
}
post() {
  if [ "$(id -u)" -eq 0 ]; then todo "한글 입력과 한/영 키는 첫 부팅 뒤 사용자로 다시 돌릴 때 정함"; return 0; fi
  if im_ok; then ok "가상 키보드 IBus Wayland"; else
    kwriteconfig6 --notify --file kwinrc --group Wayland --key InputMethod "$IBUS_IM"
    did "가상 키보드 IBus Wayland(kwinrc, 다음 로그인부터 확실)"
  fi
  if engines_ok; then ok "IBus 엔진 hangul"; else
    gsettings set org.freedesktop.ibus.general preload-engines "['hangul', 'xkb:us::eng']"
    did "IBus 엔진 hangul, xkb:us::eng"
  fi
  if hangul_key_ok; then ok "오른쪽 Alt = 한/영"; else
    local layout model
    layout=$(localectl status 2>/dev/null | sed -n 's/^ *X11 Layout: //p'); model=$(localectl status 2>/dev/null | sed -n 's/^ *X11 Model: //p')
    [ -n "$(kv kxkbrc Layout LayoutList)" ] || kwriteconfig6 --file kxkbrc --group Layout --key LayoutList "${layout:-us}"
    [ -n "$(kv kxkbrc Layout Model)" ] || kwriteconfig6 --file kxkbrc --group Layout --key Model "${model:-pc105}"
    kwriteconfig6 --file kxkbrc --group Layout --key Use true
    kwriteconfig6 --file kxkbrc --group Layout --key ResetOldOptions true
    kwriteconfig6 --notify --file kxkbrc --group Layout --key Options ''
    kwriteconfig6 --notify --file kxkbrc --group Layout --key Options korean:ralt_hangul
    did "오른쪽 Alt = 한/영(kxkbrc korean:ralt_hangul)"
  fi
  if xim_ok; then ok "XMODIFIERS=@im=ibus"; else
    mkdir -p "$(dirname "$XIM_CONF")"
    printf '# settingfiles plasma.sh: XWayland 앱(Steam)이 XIM 으로 IBus 에 붙게 함\nXMODIFIERS=@im=ibus\n' > "$XIM_CONF"
    did "XMODIFIERS=@im=ibus($XIM_CONF, 다음 로그인부터)"
  fi
  appearance_post
}
check() {
  if im_ok; then ok "가상 키보드 IBus Wayland"; else todo "kwinrc InputMethod 가 IBus Wayland 가 아님"; fi
  if engines_ok; then ok "IBus 엔진 hangul"; else todo "IBus preload-engines 에 hangul 없음"; fi
  if hangul_key_ok; then ok "오른쪽 Alt = 한/영"; else todo "kxkbrc Options 가 korean:ralt_hangul 이 아님"; fi
  if xim_ok; then ok "XMODIFIERS=@im=ibus"; else todo "$XIM_CONF 없음"; fi
  if kwallet_pam_ok; then ok "로그인 때 KWallet 열기(pam_kwallet5)"; else todo "로그인 화면 PAM(plasmalogin, gdm-password)에 pam_kwallet5 없음(손으로, ljgaming/CLAUDE.md 참고)"; fi
  appearance_check
}
