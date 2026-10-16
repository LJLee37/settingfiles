#!/bin/bash
# 2026-10 컨트롤 카드(LJTF) 재설치 전 백업. 한 번 쓰고 지울 도구입니다(migrate/HANDOFF.md).
# 옛 카드(f2fs 루트)를 다른 Arch(main-server)에 꽂고 root 로 돌립니다. 카드에는 아무것도 쓰지 않습니다.
#
#   sudo ./migrate/backup-old-card.sh <NAS 의 새 폴더>
#
# 하는 일(모두 끝나야 재설치로 넘어갑니다):
#   1. 카드 전체 이미지  card.img.zst  (읽은 그대로의 sha256 을 card.raw.sha256 에, 압축본을 풀어 대조)
#   2. vault 이미지      vault.img     (카드의 vault 파티션과 sha256 대조, LUKS 헤더만 확인. 열지 않음)
#   3. 파일             files.tar.zst (홈의 보존 목록), system.tar.zst (Wi-Fi, 프린터, 블루투스 짝)
#   4. Windows ISO     Downloads 에서 그대로 복사
#   5. USB 사본         USB(SanDisk 14G)의 driftline 폴더 두 개를 지우고 2, 3 의 사본을 둔 뒤 대조
#
# 카드와 USB 는 장치 이름이 아니라 아래 UUID 로 찾습니다. 다른 디스크를 건드릴 일이 없습니다.
set -euo pipefail

CARD_PTUUID=c33836cb-9215-46a4-b97d-bead0e3c121a      # 옛 카드의 GPT
CARD_BYTES=255869321216
VAULT_UUID=0ef9dd80-7de6-45bd-a52b-7ed47fe915fc       # 옛 sda2 (LUKS2, 마스터 SSH 키와 GPG 마스터 키)
ROOT_UUID=a89abb71-b014-4802-b2fc-f36ea32b7b55        # 옛 sda4 (f2fs /)
USB_UUID=490cd184-3bf4-4d70-b10b-2961dcb0fef4         # USB 의 ext4
USB_DIR=ljtf-card-backup
HOME_KEEP=(gitRepos .claude .claude.json handoffs .ssh .gnupg .gitconfig .purple Documents Pictures
           .config/mozilla .local/share/keyrings .config/git .config/gh .config/dconf
           .local/share/applications)
SYSTEM_KEEP=(etc/NetworkManager/system-connections etc/cups/printers.conf etc/cups/ppd var/lib/bluetooth)
WINISO=home/ljlee/Downloads/Win11_25H2_Korean_x64_v2.iso

die() { printf '\n멈춤: %s\n' "$*" >&2; exit 1; }
say() { printf '\n==> %s\n' "$*"; }
[ "$(id -u)" -eq 0 ] || die "root 로 돌리세요"
[ $# -eq 1 ] || { sed -n 2,14p "$0"; exit 64; }
DEST=$1
for t in zstd sha256sum cryptsetup tar dd; do command -v "$t" >/dev/null || die "$t 가 없음"; done

say "옛 카드 찾기"
CARD=$(lsblk -dnpo PATH,PTUUID | awk -v u="$CARD_PTUUID" '$2 == u { print $1 }')
[ -n "$CARD" ] || die "PTUUID $CARD_PTUUID 인 디스크가 없습니다. 카드를 꽂았는지 확인하세요"
[ "$(lsblk -bdno SIZE "$CARD")" = "$CARD_BYTES" ] || die "$CARD 의 크기가 옛 카드와 다릅니다"
VAULT=$(readlink -f "/dev/disk/by-uuid/$VAULT_UUID")
ROOT=$(readlink -f "/dev/disk/by-uuid/$ROOT_UUID")
[ "$(lsblk -dno PKNAME "$VAULT")" = "$(basename "$CARD")" ] || die "vault 가 $CARD 에 있지 않습니다"
[ "$(lsblk -dno PKNAME "$ROOT")" = "$(basename "$CARD")" ] || die "루트가 $CARD 에 있지 않습니다"
if lsblk -nro MOUNTPOINTS "$CARD" | grep -q .; then die "$CARD 의 파티션이 마운트돼 있습니다(자동 마운트면 내리세요)"; fi
lsblk -o NAME,SIZE,TRAN,FSTYPE,UUID "$CARD"

[ ! -e "$DEST" ] || [ -z "$(ls -A "$DEST")" ] || die "$DEST 가 비어 있지 않습니다. 새 폴더를 주세요"
mkdir -p "$DEST"
chmod 700 "$DEST"   # vault 이미지와 ~/.ssh, ~/handoffs/logs(옛 평문 토큰) 가 들어갑니다
cd "$DEST"

say "1. 카드 전체 이미지(오래 걸립니다)"
dd if="$CARD" bs=4M iflag=fullblock status=progress \
  | tee >(sha256sum | awk '{ print $1 "  card.img" }' > card.raw.sha256) \
  | zstd -T0 -3 -q -o card.img.zst
wait $! 2>/dev/null || true
for _ in $(seq 1 60); do [ -s card.raw.sha256 ] && break; sleep 1; done
[ -s card.raw.sha256 ] || die "card.raw.sha256 을 만들지 못했습니다"
echo "   압축본을 풀어 대조하는 중"
[ "$(zstd -dc card.img.zst | sha256sum | awk '{ print $1 }')" = "$(awk '{ print $1 }' card.raw.sha256)" ] \
  || die "card.img.zst 를 푼 내용이 카드와 다릅니다"
echo "   됨    card.img.zst ($(du -h card.img.zst | cut -f1)), 카드와 sha256 일치"

say "2. vault 이미지"
dd if="$VAULT" of=vault.img bs=4M status=none conv=fsync
sha256sum vault.img > vault.img.sha256
[ "$(sha256sum < "$VAULT" | awk '{ print $1 }')" = "$(awk '{ print $1 }' vault.img.sha256)" ] \
  || die "vault.img 가 카드의 vault 와 다릅니다"
cryptsetup isLuks vault.img || die "vault.img 에 LUKS 헤더가 없습니다"
cryptsetup luksDump vault.img | grep -E '^(Version|UUID|Label)'
echo "   됨    vault.img, 카드와 sha256 일치(열지 않음)"

say "3. 파일"
mnt=$(mktemp -d)
trap 'umount "$mnt" 2>/dev/null || true; rmdir "$mnt" 2>/dev/null || true' EXIT
mount -o ro "$ROOT" "$mnt"
keep=() missing=()
for p in "${HOME_KEEP[@]}"; do
  if [ -e "$mnt/home/ljlee/$p" ]; then keep+=("$p"); else missing+=("$p"); fi
done
[ ${#missing[@]} -eq 0 ] || echo "   없음  ${missing[*]}"
tar --numeric-owner --xattrs --acls -C "$mnt/home/ljlee" -cf - "${keep[@]}" | zstd -T0 -q -o files.tar.zst
sys=()
for p in "${SYSTEM_KEEP[@]}"; do [ -e "$mnt/$p" ] && sys+=("$p"); done
tar --numeric-owner --xattrs --acls -C "$mnt" -cf - "${sys[@]}" | zstd -T0 -q -o system.tar.zst
zstd -dc files.tar.zst | tar -t >/dev/null
zstd -dc system.tar.zst | tar -t >/dev/null
sha256sum files.tar.zst system.tar.zst > files.sha256
echo "   됨    files.tar.zst ($(du -h files.tar.zst | cut -f1)): ${keep[*]}"
echo "   됨    system.tar.zst: ${sys[*]}"

say "4. Windows ISO"
if [ -f "$mnt/$WINISO" ]; then
  cp "$mnt/$WINISO" .
  sha256sum "$(basename "$WINISO")" > "$(basename "$WINISO").sha256"
  cmp -s "$mnt/$WINISO" "$(basename "$WINISO")" || die "ISO 복사본이 원본과 다릅니다"
  echo "   됨    $(basename "$WINISO")"
else
  echo "   없음  $WINISO"
fi
umount "$mnt"

say "5. USB 사본"
USB=$(readlink -f "/dev/disk/by-uuid/$USB_UUID" 2>/dev/null || true)
if [ ! -b "$USB" ]; then
  echo "   건너뜀 USB(UUID $USB_UUID)가 꽂혀 있지 않습니다. 꽂고 이 단계만 손으로 하세요(HANDOFF.md)"
else
  umnt=$(mktemp -d)
  mount "$USB" "$umnt"
  # 사용자가 지워도 된다고 한 두 폴더(2026-10-16)
  rm -rf "$umnt/driftline" "$umnt/driftline-프로젝트구조-설명"
  mkdir -p "$umnt/$USB_DIR"
  chmod 700 "$umnt/$USB_DIR"
  cp vault.img vault.img.sha256 files.tar.zst system.tar.zst files.sha256 card.raw.sha256 "$umnt/$USB_DIR/"
  (cd "$umnt/$USB_DIR" && sha256sum -c --quiet vault.img.sha256 files.sha256) || die "USB 사본이 다릅니다"
  sync
  df -h "$umnt" | tail -1
  umount "$umnt"
  rmdir "$umnt"
  echo "   됨    USB:/$USB_DIR (vault.img, files.tar.zst, system.tar.zst), sha256 일치"
fi

say "끝"
ls -la "$DEST"
echo
echo "카드는 아직 그대로입니다. 재설치는 HANDOFF.md 의 다음 단계로."
