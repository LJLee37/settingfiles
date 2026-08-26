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

# Fingerprint of "Arch Linux ARM Build System <builder@archlinuxarm.org>",
# published at https://archlinuxarm.org/about/downloads ("All releases are
# signed with the same key used for package signing"). Pinned here so a
# malicious/compromised keyserver response can't substitute a different key.
ALARM_KEY_FPR="68B3537F39A313B3E574D06777193F152BDBE6A6"

if [[ ! -b "$DEVICE" ]]; then
  echo "error: $DEVICE is not a block device" >&2
  exit 1
fi

for cmd in parted mkfs.vfat mkfs.ext4 bsdtar curl gpg blkid; do
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
SIG="$TARBALL.sig"
curl -L -o "$TARBALL" "$TARBALL_URL"
curl -L -o "$SIG" "$TARBALL_URL.sig"

# This host has no TLS available for the tarball itself (mirrors serve it
# over plain HTTP, and os.archlinuxarm.org's cert doesn't even cover its
# own hostname), so this GPG check is the only real integrity/authenticity
# guarantee before the tarball becomes the Pi's root filesystem -- it must
# pass before extraction.
echo "==> Verifying rootfs signature"
GNUPGHOME="$(mktemp -d)"
export GNUPGHOME
chmod 700 "$GNUPGHOME"
trap 'rm -rf "$GNUPGHOME"' EXIT

imported=0
for ks in hkps://keyserver.ubuntu.com hkps://keys.openpgp.org hkps://pgp.mit.edu; do
  if gpg --batch --keyserver "$ks" --recv-keys "$ALARM_KEY_FPR" 2>/dev/null; then
    imported=1
    break
  fi
done
[[ "$imported" == 1 ]] || { echo "error: could not fetch ALARM signing key $ALARM_KEY_FPR from any keyserver" >&2; exit 1; }

fetched_fpr="$(gpg --batch --with-colons --fingerprint "$ALARM_KEY_FPR" | awk -F: '/^fpr:/ { print $10; exit }')"
[[ "$fetched_fpr" == "$ALARM_KEY_FPR" ]] || { echo "error: fetched key fingerprint does not match pinned fingerprint" >&2; exit 1; }

gpg --batch --verify "$SIG" "$TARBALL"
echo "==> Signature OK"

# bsdtar (not GNU tar) is required: it preserves the extended
# attributes/ACLs the rootfs relies on, which plain `tar` can silently
# drop or mishandle.
echo "==> Extracting rootfs (bsdtar, preserves xattrs/ACLs)"
bsdtar -xpf "$TARBALL" -C "$MOUNT_ROOT"

# The stock rootfs's /etc/fstab hardcodes /dev/mmcblk0p1 for /boot, but the
# Pi's mmc controller probe order isn't guaranteed -- the same card can come
# up as /dev/mmcblk0 on one boot and /dev/mmcblk1 on the next. When that
# happens, boot.mount waits the full device-timeout for a device that will
# never appear, local-fs.target fails as a dependency, and systemd drops to
# "emergency mode". PARTUUID doesn't depend on enumeration order, and
# nofail/x-systemd.automount means even a genuinely slow/late device just
# gets mounted lazily on first access instead of blocking boot.
echo "==> Rewriting /boot's fstab entry to use PARTUUID (mmcblk0/mmcblk1 numbering isn't stable across boots)"
BOOT_PARTUUID="$(blkid -s PARTUUID -o value "$BOOT_PART")"
[[ -n "$BOOT_PARTUUID" ]] || { echo "error: could not read PARTUUID of $BOOT_PART" >&2; exit 1; }
cat > "$MOUNT_ROOT/etc/fstab" <<EOF
# Static information about the filesystems.
# See fstab(5) for details.
# <file system>              <dir>  <type>  <options>                                              <dump> <pass>
PARTUUID=$BOOT_PARTUUID  /boot  vfat    defaults,nofail,x-systemd.automount,x-systemd.device-timeout=30  0       0
EOF

sync
umount "$MOUNT_ROOT/boot" "$MOUNT_ROOT"
rmdir "$MOUNT_ROOT/boot" "$MOUNT_ROOT" 2>/dev/null || true
rm -f "$TARBALL" "$SIG"

cat <<EOF

Done. Insert $DEVICE into the Pi and boot it.

Default login over SSH (or console) is alarm/alarm or root/root.
Once booted, copy install-firstboot.sh over and run it as root:

    scp install-firstboot.sh alarm@<pi-ip>:~
    ssh alarm@<pi-ip> 'su -c "bash install-firstboot.sh"'
EOF
