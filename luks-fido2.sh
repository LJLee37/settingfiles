#!/bin/bash
# LUKS 파티션마다 FIDO2 토큰 A, B 를 등록해 "그 파티션의 비밀번호, 토큰 A, 토큰 B" 세 가지로 열리게 하고,
# 토큰마다 실제로 열리는지 시험합니다. 비밀번호 슬롯은 건드리지 않습니다.
#
#   sudo ./luks-fido2.sh                   이 기기의 루트와 같은 디스크에 있는 LUKS 파티션 전부(루트, vault)
#   sudo ./luks-fido2.sh /dev/sdX3 ...     지정한 파티션(다른 기기에 카드를 꽂고 다룰 때)
#   sudo ./luks-fido2.sh --check [...]     바꾸지 않고 파티션마다 토큰 슬롯 수만 봄
#
# 등록할 때 그 파티션의 비밀번호, 토큰 PIN, 터치를 묻습니다. 어느 토큰을 등록했는지는 LUKS 헤더에 남지
# 않으므로, 마지막의 "토큰마다 열어 보기" 가 A, B 가 모두 들어갔다는 확인입니다.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
. ./install-lib.sh

CHECK=0
[ "${1:-}" = --check ] && { CHECK=1; shift; }
case "${1:-}" in -h|--help) sed -n 2,11p "$0"; exit 64 ;; esac
need_root
command -v systemd-cryptenroll >/dev/null || die "systemd-cryptenroll 이 없음"

devs=("$@")
if [ ${#devs[@]} -eq 0 ]; then
  # / 를 담은 디스크를 찾아(btrfs <- dm-crypt <- 파티션 <- 디스크) 그 안의 LUKS 파티션을 모두 고릅니다.
  disk=$(lsblk -lsno NAME,TYPE "$(findmnt -no SOURCE / | sed 's/\[.*//')" 2>/dev/null | awk '$2 == "disk" { print $1; exit }') || true
  [ -n "$disk" ] || die "루트 디스크를 찾지 못했습니다. 파티션을 직접 주세요"
  mapfile -t devs < <(lsblk -lnpo NAME,FSTYPE "/dev/$disk" | awk '$2 == "crypto_LUKS" { print $1 }')
fi
[ ${#devs[@]} -gt 0 ] || die "LUKS 파티션이 없습니다"

fido2_slots() {  # 그 LUKS2 헤더의 systemd-fido2 토큰 수
  # Count from the JSON metadata, not the text dump: once luksDump loads systemd's fido2 token plugin
  # for the first token, the rest of the dump goes to stderr (systemd 262, cryptsetup 2.8.8), so a
  # stdout parse never sees a second token and the enroll loop below kept asking for token B.
  cryptsetup luksDump --dump-json-metadata "$1" | awk '/"type": *"systemd-fido2"/ { n++ } END { print n + 0 }'
}
label() { lsblk -dno PARTLABEL "$1"; }

for d in "${devs[@]}"; do
  cryptsetup isLuks "$d" || die "$d 는 LUKS 가 아닙니다"
  # Not a luksDump parse: the text dump spills the token details to stderr (see fido2_slots).
  cryptsetup isLuks --type luks2 "$d" || die "$d 는 LUKS2 가 아닙니다(FIDO2 는 LUKS2 만)"
  printf '   %-24s %-12s 토큰 %s/2\n' "$d" "$(label "$d")" "$(fido2_slots "$d")"
done
[ "$CHECK" -eq 1 ] && exit 0

for d in "${devs[@]}"; do
  while [ "$(fido2_slots "$d")" -lt 2 ]; do
    n=$(fido2_slots "$d")
    say "$d ($(label "$d")): 토큰 $([ "$n" -eq 0 ] && echo A || echo B) 등록"
    echo "   그 토큰 하나만 꽂고(다른 토큰은 뽑고) Enter. 이 파티션의 비밀번호, 토큰 PIN, 터치를 차례로 묻습니다."
    read -r _
    systemd-cryptenroll --fido2-device=auto "$d"
  done
done

say "토큰마다 열어 보기(실제로 열지 않고 키만 확인)"
for t in A B; do
  echo "   토큰 $t 하나만 꽂고 Enter"
  read -r _
  for d in "${devs[@]}"; do
    echo "   $d ($(label "$d")): PIN 과 터치"
    if cryptsetup open --test-passphrase --token-only --token-type systemd-fido2 "$d"; then
      echo "   됨    토큰 $t 로 $d 가 열림"
    else
      echo "   실패  토큰 $t 로 $d 가 열리지 않음. 같은 토큰을 두 번 등록했을 수 있습니다:" >&2
      echo "         systemd-cryptenroll $d 로 슬롯을 보고, --wipe-slot=<번호> 로 지운 뒤 다시 돌리세요" >&2
      exit 1
    fi
  done
done
echo
echo "끝. 각 LUKS 파티션이 비밀번호, 토큰 A, 토큰 B 로 열립니다."
