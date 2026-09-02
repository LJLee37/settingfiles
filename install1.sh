#!/bin/bash
# install1.sh — main-server base install. Run from the Arch live/portable env,
# after install0-disks.sh (or after the disks are otherwise laid out to match
# main-server.env). Mounts the target, pacstraps, writes fstab, then runs
# install2.sh inside the chroot. Safe to re-run.
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"
[[ -r main-server.env ]] || { echo "main-server.env not found next to this script" >&2; exit 1; }
. ./main-server.env

SSD="/dev/disk/by-id/${SSD_ID}"

echo "==> activate LVM"
modprobe dm-mod dm-cache dm-cache-smq
vgchange -ay vg0
[[ -b /dev/vg0/root ]] || { echo "no /dev/vg0/root — run ./install0-disks.sh first" >&2; exit 1; }

echo "==> mount target at /mnt"
mountpoint -q /mnt || mount -o "${MNT_OPTS},subvol=@" /dev/vg0/root /mnt
mountpoint -q /mnt/home       || mount --mkdir -o "${MNT_OPTS},subvol=@home"      /dev/vg0/root /mnt/home
mountpoint -q /mnt/var/log    || mount --mkdir -o "${MNT_OPTS},subvol=@var_log"   /dev/vg0/root /mnt/var/log
mountpoint -q /mnt/.snapshots || mount --mkdir -o "${MNT_OPTS},subvol=@snapshots" /dev/vg0/root /mnt/.snapshots
mountpoint -q /mnt/boot       || mount --mkdir "${SSD}-part1" /mnt/boot
swapon "${SSD}-part2" 2>/dev/null || true
mkdir -p /mnt/srv

echo "==> pacstrap"
# base + kernel + microcode
#   fs tools : lvm2 btrfs-progs (root) ; dosfstools (fsck.fat for the ESP) ;
#              exfatprogs ntfs-3g (external media) ; smartmontools (HDD health)
#   boot     : grub efibootmgr
#   net      : dhcpcd (single wired NIC, DHCP) ; openssh (sshd)
#   tooling  : sudo git base-devel ansible (server-automation) ; reflector
#   shell    : zsh neovim tmux  (login shell + set.sh) ; man pages
pacstrap -K /mnt \
    base linux linux-firmware intel-ucode \
    lvm2 btrfs-progs dosfstools exfatprogs ntfs-3g smartmontools \
    grub efibootmgr \
    dhcpcd openssh \
    sudo git base-devel ansible reflector \
    zsh neovim tmux \
    man-db man-pages texinfo

echo "==> fstab"
# run genfstab only if the file has no real entries yet (stock fstab is all comments) —
# genfstab writes UUID= lines, so keying off 'vg0' would double-append on a re-run.
if ! grep -qE '^[[:space:]]*[^#[:space:]]' /mnt/etc/fstab 2>/dev/null; then
    genfstab -U /mnt >> /mnt/etc/fstab
fi
# NAS pool -> /srv : genfstab cannot see it (not mounted under /mnt). Add once.
if ! grep -q "$SRV_POOL_UUID" /mnt/etc/fstab; then
    printf 'UUID=%s\t/srv\tbtrfs\trw,relatime,space_cache\t0 0\n' "$SRV_POOL_UUID" >> /mnt/etc/fstab
fi
echo "----- /mnt/etc/fstab -----"; grep -vE '^[[:space:]]*(#|$)' /mnt/etc/fstab || true; echo "--------------------------"

echo "==> configure system (chroot -> install2.sh)"
install -Dm755 install2.sh    /mnt/root/install2.sh
install -Dm644 main-server.env /mnt/root/main-server.env
arch-chroot /mnt /root/install2.sh
rm -f /mnt/root/install2.sh /mnt/root/main-server.env

cat <<EOF

base install + configuration done.
Review  /mnt/etc/fstab  and  /mnt/boot/grub/grub.cfg  (must have root=/dev/mapper/vg0-root
rootflags=subvol=@), then:

    umount -R /mnt && swapoff -a && reboot

After first boot: log in as ${USERNAME}, then
    git clone -b main-server https://github.com/LJLee37/settingfiles.git ~/gitRepos/settingfiles
    cd ~/gitRepos/settingfiles && ./set.sh
    # then run server-automation (Ansible) for services
EOF
