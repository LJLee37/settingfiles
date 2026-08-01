#!/bin/bash
# First-boot provisioning for Arch Linux ARM (ALARM) on a Raspberry Pi.
# Run as root on the Pi itself, after booting the media prepared by
# install-sdcard.sh.
#
# Unlike x86 Arch (see the `arch` branch's install2.sh), there is:
#  - no GRUB / EFI bootloader step -- the Pi's own firmware
#    (bootcode.bin/start*.elf) loads the kernel directly per
#    /boot/config.txt, so there's nothing here equivalent to
#    grub-install/grub-mkconfig.
#  - no mkinitcpio/initramfs step -- the stock ALARM Pi image boots the
#    kernel image directly without an initramfs. Only add one back if
#    you later need it (e.g. for disk encryption).
#  - no intel-ucode or other x86 microcode package.
#  - an extra ALARM-specific step (pacman-key --populate archlinuxarm)
#    that plain Arch installs don't need, since the base tarball's
#    package signatures are signed by ALARM's own keys.
#
# Written against a Raspberry Pi 4 Model B (64-bit). Pass "5" as $1 on
# a Pi 5 to additionally swap in the RPi-specific kernel package that
# the community currently recommends there in place of the generic
# aarch64 kernel the tarball ships with (Pi 5 has no official ALARM
# image as of this writing -- verify against https://archlinuxarm.org
# before trusting this on a new install).
set -euo pipefail

PI_MODEL="${1:-4}"
USERNAME="${USERNAME:-ljlee}"
HOSTNAME_VALUE="${HOSTNAME_VALUE:-raspi-arch}"

echo "==> Initializing pacman keyring for ALARM"
pacman-key --init
pacman-key --populate archlinuxarm

echo "==> Full system update"
pacman -Syu --noconfirm

if [[ "$PI_MODEL" == "5" ]]; then
  echo "==> Pi 5: installing linux-rpi-16k kernel in place of the generic aarch64 kernel"
  pacman -S --noconfirm linux-rpi-16k
fi

echo "==> Installing base packages"
pacman -S --needed --noconfirm \
  zsh tmux neovim git base-devel htop keychain gdb ctags neofetch \
  python-pip python-neovim \
  networkmanager iwd bluez bluez-utils \
  sudo openssh man-db man-pages

echo "==> Locale"
{
  echo "en_US.UTF-8 UTF-8"
  echo "en_GB.UTF-8 UTF-8"
  echo "ko_KR.UTF-8 UTF-8"
  echo "ja_JP.UTF-8 UTF-8"
  echo "eo.UTF-8 UTF-8"
} >> /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf

echo "==> Timezone"
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime
hwclock --systohc

echo "==> Hostname"
echo "$HOSTNAME_VALUE" > /etc/hostname

echo "==> User account ($USERNAME)"
useradd -m -G wheel -s /bin/zsh "$USERNAME"
passwd "$USERNAME"
echo "Uncomment '%wheel ALL=(ALL:ALL) ALL' in the editor that opens next:"
visudo

echo "==> Neovim symlinks"
ln -sf /usr/bin/nvim /usr/local/bin/vim
ln -sf /usr/bin/nvim /usr/local/bin/vi

echo "==> Enabling services"
# The stock image networks eth0 via systemd-networkd/dhcpcd by default;
# disable those so NetworkManager doesn't fight them for the interface.
systemctl disable systemd-networkd dhcpcd 2>/dev/null || true
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable sshd

cat <<EOF

Done. Reboot, log in as $USERNAME, then run set.sh to pull in dotfiles.
EOF
