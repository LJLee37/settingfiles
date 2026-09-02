# settingFiles — `main-server` branch

Dotfiles **and** clean-install automation for **`server.ljlee37.com`** — a headless
Arch Linux (x86_64) box: ASUS desktop, Intel i5-6500, 32 GiB RAM. Forked from the
`arch` branch; the GNOME/Steam/Wi-Fi bits are dropped and LVM dm-cache + btrfs,
`sshd`, filesystem tooling, and a fixed-cmdline GRUB are added.

Services (MariaDB, netatalk/AFP, avahi, Docker, no-ip2, ufw, cron jobs) are **not**
set up here — they are owned by the `server-automation` Ansible repo. This branch
only gets the machine to a booting, reachable base system plus the user shell env.

> `.vimrc`, `.zshrc`, `init.vim`, `set.sh` are inherited from `arch` and kept in
> sync by hand. If you touch shared parts, port the change to the other branches.

## Disk layout

Root goes on the **HDD** for capacity; the **SSD** is glued on as an LVM cache so
the box *feels* like an SSD for repeated reads (binaries, libraries, pacman db)
without a small SSD ever filling up and taking the system down (the failure that
prompted this). The NAS btrfs pool is independent and never touched.

| Disk | Partition | Size | Use |
|---|---|---|---|
| SSD 128 GB (`pv-fast`) | `-part1` | 1 GiB | EFI system partition → `/boot` (vfat, raw — outside LVM) |
| | `-part2` | 32 GiB | swap (raw, outside LVM; ≥ RAM → hibernate-capable) |
| | `-part3` | ~86 GiB | LVM PV — holds the cache volume |
| HDD 2 TB (`pv-slow`) | `-part1` | whole | LVM PV — holds the root origin |
| NAS pool 2×8 TB | — | — | btrfs `UUID=5fe2b4ac-…`, mounted `/srv`. **Not repartitioned.** |

```
vg0 ┬ lv root  = 100%PVS of pv-slow, cached by ↓   (writethrough, 128k chunk)
    └ lv cache = 80 GiB on pv-fast  → [cache_cvol]
/dev/vg0/root : btrfs LABEL=archroot, subvols  @  @home  @snapshots  @var_log
```

- **128k cache chunk**: lvm2 caps a cache at 1,000,000 chunks. 80 GiB ÷ 64k (the
  default) ≈ 1.31M → `lvconvert` refuses. 128k → ~655k chunks. `install0-disks.sh`
  passes `--chunksize 128k`; the `server-automation` `main-server` role must too.
- **writethrough**: an SSD failure must never mean root loss. Recover with
  `lvconvert --uncache vg0/root` (or `--splitcache`) and boot straight off the HDD.
- **initramfs**: `MODULES=(dm-cache dm-cache-smq)` + the `lvm2` hook after `block`.
  This lvm2 package has no `sd-lvm2`; the single `lvm2` hook is systemd-aware.

## Install order

Boot the Arch ISO / a portable Arch, get networking up, then from a checkout of
this branch (`git clone -b main-server … && cd settingfiles`):

1. **`./install0-disks.sh`** — *destructive*. Wipes the two disks named in
   `main-server.env` (by id), builds the LVM cache stack, `mkfs.btrfs`, subvols.
   Skip if the disks are already laid out to match `main-server.env`.
2. **`./install1.sh`** — mounts the target at `/mnt`, `pacstrap`, `genfstab`
   (+ the `/srv` line by hand), then `arch-chroot`s and runs `install2.sh` for
   you (timezone, locale, hostname, initramfs, user `ljlee`, root password, GRUB,
   `systemctl enable dhcpcd sshd`).
3. Review `/mnt/etc/fstab` and `/mnt/boot/grub/grub.cfg`, then
   `umount -R /mnt && swapoff -a && reboot`.
4. Boot the new system, log in as `ljlee`, re-clone this branch to
   `~/gitRepos/settingfiles`, run **`./set.sh`** (dotfiles, oh-my-zsh, nvm/yarn,
   tmux, nvim plugins; also restores `~/.ssh` from
   `/srv/server-migration/snapshot/ssh-ljlee.tgz`).
5. Run `server-automation` (Ansible) to bring up the actual services.
6. Optional: **`./set-hibernate.sh`** — adds `resume=UUID=<swap>` to the GRUB
   cmdline (no `resume` hook needed on a systemd initramfs).

`install1.sh` and `install2.sh` are idempotent — safe to re-run if a step fails.

## Files

| File | Runs where | Does |
|---|---|---|
| `main-server.env` | sourced by 0/1/2 | disk ids, sizes, hostname, timezone, locales — **edit before running** |
| `install0-disks.sh` | live env | partition + LVM cache + mkfs.btrfs + subvols (destructive) |
| `install1.sh` | live env | mount `/mnt`, pacstrap, fstab, hand off to chroot |
| `install2.sh` | chroot | timezone, locale, hostname, initramfs, user, GRUB, services |
| `set.sh` | new system, as user | dotfiles + oh-my-zsh + nvm/yarn + nvim plugins + SSH restore |
| `set-hibernate.sh` | new system / chroot | `resume=UUID=<swap>` on the GRUB cmdline |

## Package set (`install1.sh` pacstrap)

`base linux linux-firmware intel-ucode` ·
`lvm2 btrfs-progs dosfstools exfatprogs ntfs-3g smartmontools` ·
`grub efibootmgr` · `dhcpcd openssh` ·
`sudo git base-devel ansible reflector` · `zsh neovim tmux` ·
`man-db man-pages texinfo`

Not Wi-Fi/Bluetooth (`iwd`, `networkmanager`, `bluez`) — the box is on a single
wired NIC via DHCP.

## Divergence from the `arch` branch

- **adds**: `lvm2 btrfs-progs dosfstools exfatprogs ntfs-3g smartmontools`,
  `openssh`, `ansible`, `zsh neovim tmux` in `pacstrap` (were laptop-side or absent);
  `install0-disks.sh`; explicit `ljlee` user + `%wheel` sudo; `/srv` fstab line.
- **changes**: `LANG=en_US.UTF-8` (not `en_GB`); locale set adds `ko_KR.EUC-KR`
  and uses bare `eo` (not `eo.UTF-8`); GRUB `--bootloader-id=Arch --removable` with
  a fixed `/etc/default/grub` (`GRUB_TIMEOUT=0`, `nomodeset text`); timezone symlink
  written in-chroot as `/usr/share/zoneinfo/…` (the `arch` branch's `/mnt/…`-prefixed
  target dangles after reboot); `hwclock` guarded on `/dev/rtc0`.
- **drops**: `install-gnome.sh`, `install-graphical-programs.sh`, `install-steam.sh`.
- **hibernate**: no `resume` mkinitcpio hook (systemd initramfs); swap UUID read at
  run time, not hardcoded.
