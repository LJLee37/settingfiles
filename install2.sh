#!/bin/bash
# 새 시스템 설정. install1.sh 가 chroot 안에서 부릅니다: 시간대, 로캘, 호스트 이름, 사용자,
# initramfs(systemd, LUKS, PORTABLE), GRUB(UEFI, removable), 서비스, zram. 다시 돌려도 됩니다.
#
#   arch-chroot /mnt/install-<PART_PREFIX> /root/settingfiles/install2.sh hosts/<기기>.env
#
# 비밀번호는 사용자와 root 둘을 묻습니다(이미 있으면 그대로 둠).
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
. ./install-lib.sh
[ $# -ge 1 ] || { sed -n 2,7p "$0"; exit 64; }
need_root
load_env "$1"

set_password() {  # set_password <계정> : 이미 비밀번호가 있으면 건너뜀
  [ "$(passwd -S "$1" | awk '{ print $2 }')" = P ] && { echo "   $1: 비밀번호 있음"; return 0; }
  if [ -n "${UNATTENDED_PASSWORD:-}" ]; then
    printf '%s:%s\n' "$1" "$UNATTENDED_PASSWORD" | chpasswd
  else
    echo "   $1 의 비밀번호:"
    until passwd "$1"; do echo "   다시"; done
  fi
}

set_kv() {  # set_kv <파일> <키> <값> : KEY=값 줄을 바꾸거나(주석 처리된 것 포함) 덧붙임
  if grep -qE "^#?[[:space:]]*$2=" "$1" 2>/dev/null; then
    sed -i -E "s|^#?[[:space:]]*$2=.*|$2=$3|" "$1"
  else
    echo "$2=$3" >> "$1"
  fi
}

say "시간대 $TIMEZONE"
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
# hwclock --systohc 대신 adjtime 을 직접 씁니다. chroot 안에서 hwclock 을 부르면 설치를 돌리는 기기
# (main-server 등)의 하드웨어 시계를 건드립니다. 내용은 hwclock 이 처음 만드는 것과 같습니다(RTC = UTC).
[ -e /etc/adjtime ] || printf '0.0 0 0.0\n0\nUTC\n' > /etc/adjtime

say "로캘"
IFS='|' read -ra locs <<< "$LOCALES"
for l in "${locs[@]}"; do
  esc=$(sed 's/[.[\*^$/]/\\&/g' <<< "$l")
  if grep -qE "^#?[[:space:]]*$esc[[:space:]]*$" /etc/locale.gen; then
    sed -i -E "s|^#?[[:space:]]*$esc[[:space:]]*$|$l|" /etc/locale.gen
  else
    echo "$l" >> /etc/locale.gen
  fi
done
locale-gen >/dev/null
echo "LANG=$LANG_DEFAULT" > /etc/locale.conf
[ -s /etc/vconsole.conf ] || echo "KEYMAP=us" > /etc/vconsole.conf   # sd-vconsole 이 읽음(LUKS 비밀번호 칠 때)

say "호스트 이름 $HOST_NAME"
echo "$HOST_NAME" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1	localhost
::1		localhost
127.0.1.1	$HOST_NAME
EOF

say "사용자 $USERNAME"
id -u "$USERNAME" >/dev/null 2>&1 || useradd -m -G wheel -s /bin/zsh "$USERNAME"
set_password "$USERNAME"
set_password root
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel
visudo -cf /etc/sudoers.d/10-wheel >/dev/null

say "initramfs"
# PORTABLE: block, keyboard 를 autodetect 앞에 두어 다른 컴퓨터의 저장장치(USB 리더, 내장 SD 슬롯,
# NVMe), 키보드, FIDO2 토큰 드라이버가 모두 들어가게 합니다(ArchWiki 「Install Arch Linux on a
# removable medium」). 그래도 안 켜지는 기기를 위해 autodetect 없는 fallback 이미지도 만듭니다.
hooks="base systemd"
is_yes "$PORTABLE" && hooks+=" keyboard block"
hooks+=" autodetect microcode modconf kms"
is_yes "$PORTABLE" || hooks+=" keyboard"
hooks+=" sd-vconsole"
is_yes "$PORTABLE" || hooks+=" block"
is_yes "$LUKS" && hooks+=" sd-encrypt"
hooks+=" filesystems fsck"
printf '# settingfiles install2.sh (%s)\nHOOKS=(%s)\n' "$1" "$hooks" > /etc/mkinitcpio.conf.d/10-settingfiles.conf
cat /etc/mkinitcpio.conf.d/10-settingfiles.conf
if is_yes "$PORTABLE"; then
  cat > /etc/mkinitcpio.d/linux.preset <<'EOF'
# settingfiles install2.sh: PORTABLE 이라 fallback(autodetect 없음) 이미지도 만듭니다.
ALL_kver="/boot/vmlinuz-linux"
PRESETS=('default' 'fallback')
default_image="/boot/initramfs-linux.img"
fallback_image="/boot/initramfs-linux-fallback.img"
fallback_options="-S autodetect"
EOF
fi
mkinitcpio -P
if is_yes "$LUKS"; then
  lsinitcpio -l /boot/initramfs-linux.img | grep -q 'etc/crypttab$' || die "initramfs 에 crypttab 이 없습니다"
  lsinitcpio -l /boot/initramfs-linux.img | grep -q 'libfido2' || die "initramfs 에 libfido2 가 없습니다"
fi

say "GRUB (UEFI, removable)"
# --removable: \EFI\BOOT\BOOTX64.EFI 에 둡니다. 어느 컴퓨터든 펌웨어가 이 경로를 찾습니다.
# --no-nvram: 설치를 돌리는 기기(main-server 등)의 EFI 부팅 항목은 건드리지 않습니다.
grub=/etc/default/grub
if is_yes "$PORTABLE"; then set_kv "$grub" GRUB_TIMEOUT 5; else set_kv "$grub" GRUB_TIMEOUT 0; fi
set_kv "$grub" GRUB_TIMEOUT_STYLE menu
set_kv "$grub" GRUB_CMDLINE_LINUX_DEFAULT "\"loglevel=3 quiet${EXTRA_CMDLINE:+ $EXTRA_CMDLINE}\""
set_kv "$grub" GRUB_DISABLE_OS_PROBER true
# 설치를 돌리는 기기의 EFI 부팅 항목(BootNext)을 메뉴에 넣지 않습니다. 다른 컴퓨터에서는 뜻이 없습니다.
set_kv "$grub" GRUB_DISABLE_BOOTNEXT true
grub-install --target=x86_64-efi --efi-directory=/boot --removable --no-nvram
grub-mkconfig -o /boot/grub/grub.cfg
grep -q 'rootflags=subvol=@' /boot/grub/grub.cfg || die "grub.cfg 에 rootflags=subvol=@ 가 없습니다"

say "서비스"
systemctl enable NetworkManager systemd-timesyncd
if is_yes "$PORTABLE"; then
  # 스왑 파티션 대신 압축 RAM. 플래시(SD 카드)에 스왑을 쓰지 않습니다.
  cat > /etc/systemd/zram-generator.conf <<'EOF'
# settingfiles install2.sh
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
EOF
  # 저널은 남기되(다른 컴퓨터에서 왜 안 됐는지 봐야 하므로) 크기를 묶습니다.
  mkdir -p /etc/systemd/journald.conf.d
  printf '# settingfiles install2.sh\n[Journal]\nSystemMaxUse=100M\n' > /etc/systemd/journald.conf.d/10-settingfiles.conf
fi

say "이 저장소를 ~$USERNAME/gitRepos/settingfiles 로"
home=$(getent passwd "$USERNAME" | cut -d: -f6)
if [ ! -e "$home/gitRepos/settingfiles" ]; then
  mkdir -p "$home/gitRepos"
  cp -a "$PWD" "$home/gitRepos/settingfiles"
  git -C "$home/gitRepos/settingfiles" remote set-url origin https://github.com/LJLee37/settingfiles.git 2>/dev/null || true
  chown -R "$USERNAME:$USERNAME" "$home/gitRepos"
fi

echo
echo "install2 끝."
