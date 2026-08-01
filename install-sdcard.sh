#!/bin/bash
# Prepares SD card / USB media with Arch Linux ARM (ALARM) for a Raspberry Pi.
#
# Run this on a SEPARATE Linux machine with the target media attached
# (e.g. via a USB SD card reader) -- the Pi has no OS yet at this point,
# so unlike the `arch` branch's install1.sh (which runs from inside an
# Arch ISO on the target machine itself via pacstrap+genfstab), ALARM is
# installed by extracting a prebuilt rootfs tarball from the outside.
#
# Written against a Raspberry Pi 4 Model B (64-bit) using the generic
# "rpi-aarch64" image, which ALARM also lists as covering the Pi 3 and
# 400. The Pi 5 has no dedicated ALARM image as of this writing; the
# generic aarch64 tarball is reported to work if you swap to the
# linux-rpi/linux-rpi-16k kernel package after first boot (see
# install-firstboot.sh). Re-check https://archlinuxarm.org for the
# current recommended image/procedure for your model before relying on
# this script -- ALARM's supported devices and package names change.
set -euo pipefail

# --- Configuration -----------------------------------------------------
# Target block device for the WHOLE disk, e.g. /dev/sdX (USB reader) or
# /dev/mmcblk0 (built-in SD slot). NOT a partition (no trailing number).
DEVICE="${1:?Usage: $0 /dev/sdX [tarball-url]}"
TARBALL_URL="${2:-http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz}"
BOOT_SIZE_MIB=256
MOUNT_ROOT=/mnt/alarm-root

if [[ ! -b "$DEVICE" ]]; then
  echo "error: $DEVICE is not a block device" >&2
  exit 1
fi

for cmd in parted mkfs.vfat mkfs.ext4 bsdtar curl; do
  command -v "$cmd" >/dev/null || { echo "error: $cmd is required on the host running this script" >&2; exit 1; }
done

# Partition suffix differs between /dev/sdX (sdX1) and /dev/mmcblk0 or
# /dev/nvme0n1 style devices (mmcblk0p1).
case "$DEVICE" in
  *mmcblk*|*nvme*) PART_SUFFIX=p ;;
  *) PART_SUFFIX= ;;
esac
BOOT_PART="${DEVICE}${PART_SUFFIX}1"
ROOT_PART="${DEVICE}${PART_SUFFIX}2"

echo "This will ERASE ALL DATA on $DEVICE ($BOOT_PART, $ROOT_PART)."
read -r -p "Type 'yes' to continue: " confirm
[[ "$confirm" == "yes" ]] || { echo "Aborted."; exit 1; }

echo "==> Partitioning $DEVICE"
parted --script "$DEVICE" \
  mklabel msdos \
  mkpart primary fat32 1MiB "${BOOT_SIZE_MIB}MiB" \
  mkpart primary ext4 "${BOOT_SIZE_MIB}MiB" 100% \
  set 1 boot on

echo "==> Formatting partitions"
mkfs.vfat -F 32 -n BOOT "$BOOT_PART"
mkfs.ext4 -F -L root "$ROOT_PART"

echo "==> Mounting"
mkdir -p "$MOUNT_ROOT"
mount "$ROOT_PART" "$MOUNT_ROOT"
mkdir -p "$MOUNT_ROOT/boot"
mount "$BOOT_PART" "$MOUNT_ROOT/boot"

echo "==> Downloading $TARBALL_URL"
TARBALL="/tmp/$(basename "$TARBALL_URL")"
curl -L -o "$TARBALL" "$TARBALL_URL"

# bsdtar (not GNU tar) is required: it preserves the extended
# attributes/ACLs the rootfs relies on, which plain `tar` can silently
# drop or mishandle.
echo "==> Extracting rootfs (bsdtar, preserves xattrs/ACLs)"
bsdtar -xpf "$TARBALL" -C "$MOUNT_ROOT"

sync
umount "$MOUNT_ROOT/boot" "$MOUNT_ROOT"
rmdir "$MOUNT_ROOT/boot" "$MOUNT_ROOT" 2>/dev/null || true
rm -f "$TARBALL"

cat <<EOF

Done. Insert $DEVICE into the Pi and boot it.

Default login over SSH (or console) is alarm/alarm or root/root.
Once booted, copy install-firstboot.sh over and run it as root:

    scp install-firstboot.sh alarm@<pi-ip>:~
    ssh alarm@<pi-ip> 'su -c "bash install-firstboot.sh"'
EOF
