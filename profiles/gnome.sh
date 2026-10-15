# gnome 프로필 설정.
post() { enable_unit gdm; }
check() { if systemctl is-enabled -q gdm 2>/dev/null; then ok gdm; else todo "gdm 꺼져 있음"; fi; }
