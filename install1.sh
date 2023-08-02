#!/bin/bash
pacstrap -K /mnt base linux linux-firmware neovim tmux iwd networkmanager python-pip base-devel git zsh sudo btrfs-progs exfatprogs ntfs-3g dhcpcd man-db man-pages texinfo bluez
genfstab -U /mnt >> /mnt/etc/fstab
ln -sf /mnt/usr/share/zoneifno/Asia/Seoul /mnt/etc/localtime
