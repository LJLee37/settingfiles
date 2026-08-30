#!/bin/bash

# run hwclock to generate /etc/adjtime (skip if there is no hardware RTC,
# e.g. in a VM -- hwclock then fails with "Cannot access the Hardware Clock")
if [[ -e /dev/rtc0 ]]; then
  hwclock --systohc
else
  echo "no /dev/rtc0 (no hardware RTC) -- skipping hwclock"
fi

# edit /etc/locale.gen to add needed locales
echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
echo en_GB.UTF-8 UTF-8 >> /etc/locale.gen
echo ko_KR.UTF-8 UTF-8 >> /etc/locale.gen
echo ja_JP.UTF-8 UTF-8 >> /etc/locale.gen
echo eo.UTF-8 UTF-8 >> /etc/locale.gen

# generate locales
locale-gen

# set LANG variable
echo LANG=en_GB.UTF-8 >> /etc/locale.conf

# set hostname
echo LJLeeLT >> /etc/hostname

# make initramfs
mkinitcpio -P

# add user
useradd -m -G wheel -s /bin/zsh ljlee
passwd ljlee

# link neovim to vim, vi
ln -s /bin/nvim /bin/vim
ln -s /bin/nvim /bin/vi

# make wheel sudoer
visudo

# install bootloader and microcodes
pacman -Syu grub efibootmgr intel-ucode
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch --removable
grub-mkconfig -o /boot/grub/grub.cfg

# enable neccessary services
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable dhcpcd
systemctl enable iwd
systemctl enable systemd-networkd
