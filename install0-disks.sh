#!/bin/bash
# 디스크 하나를 지우고 새로 나눕니다: ESP | (vault) | 루트(LUKS2 선택) -> btrfs 서브볼륨.
# Arch 설치 USB 에서도, 이미 돌고 있는 다른 Arch(예: main-server)에서도 돌 수 있습니다.
#
#   sudo ./install0-disks.sh hosts/<기기>.env <디스크> [vault 이미지]
#
#   디스크       /dev/disk/by-id/... 처럼 바뀌지 않는 경로를 권합니다(/dev/sdX 도 받음).
#   vault 이미지 env 가 VAULT=yes 일 때. 옆에 <이미지>.sha256 이 있어야 하고, 쓰기 전후로 대조합니다.
#
# 지우기 전에 막는 것: env 의 DISK_BYTES 와 크기가 다름, 마운트되었거나 열려 있는 파티션이 있음.
# 루트 LUKS 는 열어 둔 채 끝나므로 이어서 install1.sh 를 돌립니다.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
. ./install-lib.sh
[ $# -ge 2 ] || { sed -n 2,11p "$0"; exit 64; }
need_root
load_env "$1"
DISK=$(disk_path "$2")
VAULT_IMAGE=${3:-}

for t in sfdisk wipefs mkfs.fat mkfs.btrfs cryptsetup sha256sum; do
  command -v "$t" >/dev/null || die "$t 가 없음(필요한 패키지: util-linux dosfstools btrfs-progs cryptsetup)"
done

say "지워도 되는 디스크인지 확인"
check_disk_size "$DISK"
if lsblk -nro MOUNTPOINTS "$DISK" | grep -q .; then
  lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS "$DISK"
  die "$DISK 의 파티션이 마운트되어 있거나 스왑으로 쓰이고 있습니다"
fi
for p in $(lsblk -lnpo NAME "$DISK" | tail -n +2); do
  [ -z "$(ls "/sys/class/block/$(basename "$p")/holders" 2>/dev/null)" ] \
    || die "$p 를 무언가 쥐고 있습니다(열린 LUKS 나 LVM). 예: cryptsetup close $MAPPER"
done

if is_yes "$VAULT"; then
  [ -f "$VAULT_IMAGE" ] || die "env 가 VAULT=yes 인데 vault 이미지를 주지 않았습니다(세 번째 인자)"
  [ -f "$VAULT_IMAGE.sha256" ] || die "$VAULT_IMAGE.sha256 이 없습니다"
  vault_sum=$(awk '{ print $1; exit }' "$VAULT_IMAGE.sha256")
  [ "$(sha256sum < "$VAULT_IMAGE" | awk '{ print $1 }')" = "$vault_sum" ] || die "vault 이미지가 .sha256 과 다릅니다"
  cryptsetup isLuks "$VAULT_IMAGE" || die "vault 이미지가 LUKS 가 아닙니다"
  vault_bytes=$(stat -c %s "$VAULT_IMAGE")
  vault_mib=$(( (vault_bytes + 1048575) / 1048576 ))
  echo "   vault 이미지 $(( vault_bytes / 1048576 ))MiB, sha256 일치, LUKS 헤더 있음"
fi

echo
lsblk -o NAME,SIZE,TYPE,TRAN,MODEL,FSTYPE,LABEL,PARTLABEL "$DISK"
size_text=$(lsblk -dno SIZE "$DISK" | tr -d ' ')
echo
echo "   위 디스크 $DISK ($size_text) 를 통째로 지우고 $HOST_NAME 용으로 나눕니다."
confirm "$size_text"

say "파티션(GPT)"
luks_type=CA7D7CCB-63ED-4C53-861C-1742536059CC   # Linux LUKS
linux_type=0FC63DAF-8483-4772-8E79-3D69D8477DE4  # Linux filesystem
root_type=$linux_type
is_yes "$LUKS" && root_type=$luks_type
{
  echo "label: gpt"
  echo "size=${ESP_MIB}MiB, type=uefi, name=\"${PART_PREFIX}-efi\""
  is_yes "$VAULT" && echo "size=${vault_mib}MiB, type=$luks_type, name=\"${PART_PREFIX}-vault\""
  echo "type=$root_type, name=\"${PART_PREFIX}-root\""
} | sfdisk --quiet --wipe always --wipe-partitions always "$DISK"
udevadm settle
lsblk -o NAME,SIZE,PARTLABEL "$DISK"

esp=$(part_by_label "$DISK" "${PART_PREFIX}-efi")
root=$(part_by_label "$DISK" "${PART_PREFIX}-root")
[ -b "$esp" ] && [ -b "$root" ] || die "새 파티션을 찾지 못했습니다(udev 가 늦으면 다시 돌리세요)"

say "ESP: FAT32"
mkfs.fat -F32 -n "$(printf '%.11s' "${PART_PREFIX^^}-EFI")" "$esp" >/dev/null

if is_yes "$VAULT"; then
  vault=$(part_by_label "$DISK" "${PART_PREFIX}-vault")
  say "vault: 이미지를 그대로 씀"
  dd if="$VAULT_IMAGE" of="$vault" bs=4M conv=fsync status=progress
  [ "$(head -c "$vault_bytes" "$vault" | sha256sum | awk '{ print $1 }')" = "$vault_sum" ] \
    || die "쓴 vault 가 이미지와 다릅니다. 이미지와 디스크를 확인하세요"
  echo "   쓴 내용이 이미지 sha256 과 일치"
fi

fs_dev=$root
if is_yes "$LUKS"; then
  say "루트: LUKS2"
  luks_format "$root" "${PART_PREFIX}-root"
  luks_open "$root" "$MAPPER"
  fs_dev=/dev/mapper/$MAPPER
fi

say "루트: btrfs 와 서브볼륨"
mkfs.btrfs -q -f -L "${PART_PREFIX}-root" "$fs_dev"
tmp=$(mktemp -d)
mount -o "$MNT_OPTS" "$fs_dev" "$tmp"
for sv in "${SUBVOLS[@]}"; do btrfs -q subvolume create "$tmp/${sv%%:*}"; done
btrfs subvolume list "$tmp"
umount "$tmp"
rmdir "$tmp"

echo
echo "디스크 준비 끝. 다음: sudo ./install1.sh $1 $2"
