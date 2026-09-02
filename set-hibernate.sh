#!/bin/bash
# set-hibernate.sh — enable resume-from-hibernate on main-server.
# Run on the installed system (as a user with sudo), or inside the chroot as root.
#
# The initramfs here is systemd-based (HOOKS has 'systemd', not 'udev'): systemd
# reads the resume device from the kernel cmdline itself, so NO 'resume' mkinitcpio
# hook is needed — only 'resume=UUID=<swap>' on GRUB_CMDLINE_LINUX_DEFAULT.
# Swap is a raw partition on the SSD (outside LVM/cache), sized >= RAM.
set -euo pipefail

SUDO=""; [[ $EUID -ne 0 ]] && SUDO="sudo"

here="$(dirname "$(readlink -f "$0")")"
[[ -r "$here/main-server.env" ]] && . "$here/main-server.env"
: "${SSD_ID:=ata-SanDisk_Z400s_2.5_7MM_128GB_162905405855}"

SWAP_DEV="/dev/disk/by-id/${SSD_ID}-part2"
[[ -b "$SWAP_DEV" ]] || { echo "swap device not found: $SWAP_DEV" >&2; exit 1; }
SWAP_UUID="$($SUDO blkid -s UUID -o value "$SWAP_DEV")"
[[ -n "$SWAP_UUID" ]] || { echo "could not read UUID of $SWAP_DEV" >&2; exit 1; }

ram_kib=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
swap_kib=$(( $($SUDO blockdev --getsize64 "$SWAP_DEV") / 1024 ))
(( swap_kib >= ram_kib )) || echo "WARNING: swap ${swap_kib} KiB < RAM ${ram_kib} KiB — hibernate may fail" >&2

if $SUDO grep -q "resume=UUID=${SWAP_UUID}" /etc/default/grub; then
    echo "resume=UUID=${SWAP_UUID} already in /etc/default/grub"
else
    $SUDO sed -i -E \
        "s|^(GRUB_CMDLINE_LINUX_DEFAULT=\")([^\"]*)(\")|\1\2 resume=UUID=${SWAP_UUID}\3|" \
        /etc/default/grub
    # tidy a leading/double space if the value was empty
    $SUDO sed -i -E 's|(GRUB_CMDLINE_LINUX_DEFAULT=")[[:space:]]+|\1|; s|[[:space:]]{2,}| |g' /etc/default/grub
    echo "added resume=UUID=${SWAP_UUID}"
fi

$SUDO grep '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub
$SUDO grub-mkconfig -o /boot/grub/grub.cfg
echo "done. Test with:  systemctl hibernate"
