# gnome 프로필 설정. 기본 편집기(nvim)와 터미널 앱(Ghostty)은 2026-11-18 desktop.sh 로 옮겼습니다(Plasma 와 같이 씀).
post() {
  enable_unit gdm
}
check() {
  if systemctl is-enabled -q gdm 2>/dev/null; then ok gdm; else todo "gdm 꺼져 있음"; fi
}
