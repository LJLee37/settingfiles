#!/bin/bash
# install0-disks.sh 로 나눈 디스크에 Arch 를 깝니다: 서브볼륨 마운트, pacstrap(profiles/base.txt),
# fstab 과 crypttab, 이 저장소 복사, chroot 안에서 install2.sh. 다시 돌려도 됩니다.
#
#   sudo ./install1.sh hosts/<기기>.env <디스크>
#
# 끝나면 대상은 /mnt/install-<PART_PREFIX> 에 마운트된 채 남습니다(그 안에서 프로필을 더 깔거나
# luks-fido2.sh 로 토큰을 등록할 수 있게). 마지막에 정리 명령을 알려 줍니다.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
. ./install-lib.sh
[ $# -ge 2 ] || { sed -n 2,9p "$0"; exit 64; }
need_root
load_env "$1"
ENV_REL="hosts/$(basename "$1")"
DISK=$(disk_path "$2")
check_disk_size "$DISK"
command -v pacstrap >/dev/null || die "pacstrap 이 없음(arch-install-scripts)"

esp=$(part_by_label "$DISK" "${PART_PREFIX}-efi")
root=$(part_by_label "$DISK" "${PART_PREFIX}-root")
[ -b "$esp" ] && [ -b "$root" ] || die "$DISK 에 ${PART_PREFIX}-efi, ${PART_PREFIX}-root 파티션이 없음. install0-disks.sh 먼저"

fs_dev=$root
if is_yes "$LUKS"; then
  luks_open "$root" "$MAPPER"
  fs_dev=/dev/mapper/$MAPPER
fi

say "$TARGET 에 마운트"
for sv in "${SUBVOLS[@]}"; do
  name=${sv%%:*} dir=${sv#*:}
  mountpoint -q "$TARGET$dir" || mount --mkdir -o "$MNT_OPTS,subvol=$name" "$fs_dev" "$TARGET$dir"
done
mountpoint -q "$TARGET/boot" || mount --mkdir -o fmask=0077,dmask=0077 "$esp" "$TARGET/boot"
findmnt -R "$TARGET"

say "pacstrap"
# shellcheck disable=SC2046
pacstrap -K "$TARGET" $(read_list profiles/base.txt)

say "fstab"
if ! grep -qE '^[[:space:]]*[^#[:space:]]' "$TARGET/etc/fstab"; then
  # subvolid 는 지웁니다. 스냅숏을 @ 로 되돌리면 번호가 바뀌어 부팅이 멈춥니다(subvol= 이름만 남김).
  genfstab -U "$TARGET" | sed -E 's/,subvolid=[0-9]+//' >> "$TARGET/etc/fstab"
fi
grep -vE '^[[:space:]]*(#|$)' "$TARGET/etc/fstab"

if is_yes "$LUKS"; then
  say "crypttab"
  luks_uuid=$(blkid -s UUID -o value "$root")
  # 부팅 때 initramfs 가 엽니다(x-initrd.attach). 토큰이 등록돼 있으면 꽂힌 FIDO2 토큰을 먼저 쓰고,
  # 30 초 안에 토큰이 없으면 비밀번호를 묻습니다. 토큰 등록은 luks-fido2.sh.
  line="root UUID=$luks_uuid none x-initrd.attach,fido2-device=auto,token-timeout=30"
  grep -q "^root UUID=$luks_uuid " "$TARGET/etc/crypttab" 2>/dev/null \
    || { sed -i '/^root[[:space:]]/d' "$TARGET/etc/crypttab"; echo "$line" >> "$TARGET/etc/crypttab"; }
  grep -vE '^[[:space:]]*(#|$)' "$TARGET/etc/crypttab"
fi

say "이 저장소를 대상에 복사하고 chroot 에서 install2.sh"
rm -rf "$TARGET/root/settingfiles"
cp -a "$PWD" "$TARGET/root/settingfiles"
arch-chroot "$TARGET" /root/settingfiles/install2.sh "$ENV_REL"
rm -rf "$TARGET/root/settingfiles"

cat <<EOF

설치 끝. 대상은 $TARGET 에 마운트돼 있습니다. 필요하면 이어서:
  arch-chroot $TARGET /home/$USERNAME/gitRepos/settingfiles/install-profile.sh <프로필...>
      (root 로 돌면 AUR 패키지는 건너뜁니다. 첫 부팅 뒤 사용자로 다시 돌리면 채워집니다)
  ./luks-fido2.sh $root$(is_yes "$VAULT" && echo " $(part_by_label "$DISK" "${PART_PREFIX}-vault")")
      (토큰 A, B 등록. 이 기기에 토큰을 꽂고)
정리:
  umount -R $TARGET$(is_yes "$LUKS" && echo " && cryptsetup close $MAPPER")
첫 부팅 뒤 $USERNAME 으로: cd ~/gitRepos/settingfiles && ./set.sh && ./install-profile.sh ${PROFILES:-}
EOF
