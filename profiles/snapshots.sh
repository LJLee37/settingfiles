# snapshots 프로필 설정. 서브볼륨 @snapshots 를 /.snapshots 로 그대로 쓰도록 snapper 가 만드는
# .snapshots 서브볼륨을 지우고 갈음합니다(ArchWiki 「Snapper」의 권장 배치).
post() {
  if [ -f /etc/snapper/configs/root ]; then ok "snapper root 설정"; return 0; fi
  if [ "$(findmnt -no FSTYPE /)" != btrfs ] || ! mountpoint -q /.snapshots; then
    todo "/ 가 btrfs 가 아니거나 /.snapshots 가 따로 마운트돼 있지 않아 건너뜀"; return 0
  fi
  as_root umount /.snapshots
  as_root rmdir /.snapshots
  as_root snapper --no-dbus -c root create-config /
  as_root btrfs -q subvolume delete /.snapshots
  as_root mkdir /.snapshots
  as_root mount /.snapshots
  as_root chmod 750 /.snapshots
  # SD 카드라 시간마다 찍지 않고, pacman 전후 스냅숏만 10 개까지 둡니다.
  as_root snapper --no-dbus -c root set-config TIMELINE_CREATE=no NUMBER_LIMIT=10 NUMBER_LIMIT_IMPORTANT=5
  enable_unit snapper-cleanup.timer
  did "snapper root 설정(/.snapshots = @snapshots)"
}

check() {
  if [ -f /etc/snapper/configs/root ]; then ok "snapper root 설정"; else todo "snapper root 설정 없음"; fi
}
