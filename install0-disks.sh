#!/bin/bash
# install0-disks.sh — main-server disk layout: SSD cache + HDD main.
#
#   HDD (2 TB)  -> 1 partition, pv-slow  -> LVM origin (root data)
#   SSD (128 GB)-> ESP 1 GiB | swap 32 GiB | pv-fast (rest) -> LVM cache volume
#   vg0 = pv-slow + pv-fast ; lv root (100%PVS of pv-slow) cached by lv cache
#         (writethrough, 128k chunk) ; mkfs.btrfs -> subvols @ @home @snapshots @var_log
#
# DESTRUCTIVE. Wipes ONLY the two disks named in main-server.env, by id. The NAS
# btrfs pool is never touched. Run from the Arch live/portable environment.
#
# Rationale + sources: see README.md "Disk layout" and the server-migration notes.
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"
[[ -r main-server.env ]] || { echo "main-server.env not found next to this script" >&2; exit 1; }
. ./main-server.env

HDD="/dev/disk/by-id/${HDD_ID}"
SSD="/dev/disk/by-id/${SSD_ID}"
for d in "$HDD" "$SSD"; do
    [[ -b "$d" ]] || { echo "not a block device: $d  (fix *_ID in main-server.env)" >&2; exit 1; }
done
[[ "$(readlink -f "$HDD")" != "$(readlink -f "$SSD")" ]] || { echo "HDD_ID and SSD_ID resolve to the same disk" >&2; exit 1; }

# Refuse if either target disk holds the NAS pool.
if blkid -o value -s UUID "$HDD"* "$SSD"* 2>/dev/null | grep -qx "$SRV_POOL_UUID"; then
    echo "ABORT: a target disk carries the NAS pool UUID ${SRV_POOL_UUID}" >&2
    exit 1
fi

echo "About to WIPE these two disks:"
lsblk -o NAME,SIZE,TYPE,FSTYPE,SERIAL,MODEL "$HDD" "$SSD"
echo
read -rp 'Type YES to repartition: ' ans
[[ "$ans" == "YES" ]] || { echo "aborted"; exit 1; }

modprobe dm-mod dm-cache dm-cache-smq

# tear down a previous vg0 on these disks so a re-run isn't blocked by "device in use"
swapoff "${SSD}-part2" 2>/dev/null || true
vgchange -an vg0 2>/dev/null || true
vgremove -f -y vg0 2>/dev/null || true

echo "==> SSD: ESP + swap + pv-fast"
sgdisk -Z "$SSD"
sgdisk -n1:0:+1G            -t1:ef00 -c1:EFI     "$SSD"
sgdisk -n2:0:"+${SWAP_GIB}G" -t2:8200 -c2:swap    "$SSD"
sgdisk -n3:0:0             -t3:8e00 -c3:pv-fast "$SSD"

echo "==> HDD: single pv-slow"
sgdisk -Z "$HDD"
sgdisk -n1:0:0 -t1:8e00 -c1:pv-slow "$HDD"

partprobe "$SSD" "$HDD"
udevadm settle
wipefs -a "${HDD}-part1" "${SSD}-part1" "${SSD}-part2" "${SSD}-part3" 2>/dev/null || true

echo "==> filesystems on the raw SSD partitions"
mkfs.fat -F32 -n EFI "${SSD}-part1"
mkswap -L swap "${SSD}-part2"

echo "==> LVM"
pvcreate -y "${HDD}-part1" "${SSD}-part3"
vgcreate vg0 "${HDD}-part1" "${SSD}-part3"
lvcreate -y -n root  -l 100%PVS       vg0 "${HDD}-part1"
lvcreate -y -n cache -L "${CACHE_GIB}G" vg0 "${SSD}-part3"
lvconvert -y --type cache --cachevol cache \
    --chunksize "$CACHE_CHUNK" --cachemode "$CACHE_MODE" vg0/root
lvs -a -o name,lv_size,cache_mode,chunk_size vg0

echo "==> btrfs root + subvolumes"
mkfs.btrfs -L "$BTRFS_LABEL" /dev/vg0/root
mount /dev/vg0/root /mnt
for s in $BTRFS_SUBVOLS; do btrfs subvolume create "/mnt/$s"; done
btrfs subvolume list /mnt
umount /mnt

echo
echo "disks ready. Next: ./install1.sh"
