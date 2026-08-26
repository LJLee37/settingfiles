# settingFiles

Personal dotfiles and OS setup scripts. This repository separates OS/target
environments by **branch** instead of by directory — clone the branch that
matches your target machine, not `master` directly.

## Branches

| Branch | Purpose | Notes |
|---|---|---|
| `master` | Common base | Shared dotfiles only; starting point for new OS branches |
| `arch` | Arch Linux (x86_64) | GNOME desktop, Steam, hibernate support |
| `macOS` | macOS | Homebrew, Karabiner-Elements |
| `ubuntu` | Ubuntu | |
| `alpine` | Alpine Linux | Docker container use |
| `raspi` | Raspberry Pi OS (Debian-based, `apt`) | Headless/CLI |
| `raspi-arch` | Arch Linux ARM on Raspberry Pi | Headless/CLI |

`.vimrc` is identical on every branch, and the bulk of `.zshrc` is shared too —
branches only differ in a small OS-specific tail (PATH entries, keychain/GPG
setup, plugin list, etc.). `master` holds the canonical copies of these
shared files. When editing the shared portions, port the same change to the
other branches by hand; there is no symlink/build step tying the branches
together, so nothing will warn you if they drift.

## Installation

Install `zsh`, `tmux`, `neovim`, `git`, and `curl` with your package manager
first.

Then clone the branch matching your target OS (see the table above):

```
git clone -b <branch> https://github.com/LJLee37/settingfiles.git ~/gitRepos/settingfiles
```

and run `set.sh` from inside the repo.

After running `set.sh`, enter `nvim`, then run `:call coc#util#install()` if
you hit a coc error.

## Arch Linux ARM (raspi-arch) install order

This branch targets a headless Arch Linux ARM (ALARM) install on a
Raspberry Pi, scoped like `raspi` (CLI-only, no desktop/Steam like the
x86_64 `arch` branch has). ALARM's install procedure is fundamentally
different from x86 Arch's `pacstrap`/GRUB flow — see the comments at the
top of each script for details (prebuilt rootfs tarball + `bsdtar`
instead of `pacstrap`, `pacman-key --populate archlinuxarm`, Pi
firmware boot instead of GRUB, no `intel-ucode`).

1. On a **separate** Linux machine with the SD card/USB drive attached,
   clone this branch and run `install-sdcard.sh /dev/sdX` (partitions,
   formats, and extracts the ALARM rootfs onto the media). The Pi has no
   OS yet at this point, so this step can't run on the Pi itself. This
   machine needs `gpg` installed and outbound access to a keyserver: the
   script fetches ALARM's signing key by pinned fingerprint and verifies
   the downloaded tarball's `.sig` before extracting it (the tarball
   itself is only ever served over plain HTTP, so this is the only real
   integrity/authenticity check in the chain).
2. Boot the Pi from that media. SSH in as `alarm`/`alarm` (or `root`/`root`),
   copy `install-firstboot.sh` over, and run it as root — pass `5` as the
   first argument on a Raspberry Pi 5 (see the script header). This does
   `pacman-key` init, a full system update, locale/timezone/hostname,
   creates a user account, and enables NetworkManager/bluetooth/sshd.
3. Reboot, log in as that user, then run `set.sh` to pull in dotfiles.
4. `backup.sh` makes a full-system + boot-partition backup and `scp`s it
   to `ljlee@server.ljlee37.com:/srv/netatalk/PersonalData/RpiBackups/`.

Written against a Raspberry Pi 4 Model B (64-bit) using the generic
`ArchLinuxARM-rpi-aarch64-latest.tar.gz` image (ALARM lists this as also
covering the Pi 3 and 400). The Pi 5 has no dedicated ALARM image as of
this writing; `install-firstboot.sh 5` swaps in the kernel package the
community currently recommends there instead. Re-check
https://archlinuxarm.org for your specific model before a new install —
ALARM's supported devices, image names, and procedure do change over time.

## Troubleshooting history (raspi-arch)

Real problems hit during actual installs, and why the scripts now do what
they do. Both fixes below are already baked into `install-sdcard.sh` /
`install-firstboot.sh` — this is here for when something still goes
wrong, or you're wondering why a step exists.

**"You are in emergency mode" on first boot, with only a `/boot` line in
`/etc/fstab`.** Not having a `/` line in fstab is normal for ALARM (root
is mounted by the kernel/U-Boot boot script via `root=PARTUUID=...`, not
fstab) — that's not the bug. The actual cause: the stock rootfs's fstab
hardcodes `/dev/mmcblk0p1` for `/boot`, but the Pi's mmc controller probe
order isn't guaranteed — the same card can enumerate as `/dev/mmcblk0` on
one boot and `/dev/mmcblk1` on the next (confirmed mid-incident via
`lsblk`: the card was `mmcblk1`, so `/dev/mmcblk0p1` never existed that
boot). `boot.mount` then waits the full device-timeout for a device that
will never appear, `local-fs.target` fails as a dependency, and systemd
drops to emergency mode. (`systemctl --failed` can show 0 units by the
time you look, if the device happens to show up moments later and gets
mounted manually — the shell still stays on `emergency.target` until a
reboot, since nothing exits it automatically.) **Fix:** `install-sdcard.sh`
now rewrites `/boot`'s fstab entry to `PARTUUID=...` (stable regardless of
enumeration order) with `nofail,x-systemd.automount,x-systemd.device-timeout=30`,
so even a genuinely slow-to-appear device just mounts lazily instead of
blocking boot.

**Kernel and `/lib/modules` version mismatch after an interrupted
`pacman -Syu`** (missing `.ko` files for wifi/bluetooth/DRM, `eth0` not
showing up at all). If `/boot` isn't mounted when a kernel package
upgrade runs, pacman still updates its database and drops the new modules
under `/usr/lib/modules/<new-version>/`, but the post-install hook that
copies the new kernel image into `/boot` has nowhere to write it. The Pi
keeps booting the *old* kernel image still sitting on the boot partition —
whose module directory pacman just deleted as part of the "upgrade." The
running kernel then can't find any of its own modules, including network
drivers, so interfaces like `eth0` never appear. This is exactly what
happens if you Ctrl+C an `install-firstboot.sh` run mid-`pacman -Syu`
because you noticed `/boot` wasn't mounted (which is *why* it's worth
checking before, not after). If you're already in this state: mount
`/boot` for real (check the actual device with `lsblk` — don't assume
`mmcblk0`), then force the cached kernel package to reinstall now that
`/boot` exists —
`pacman -U --overwrite '*' /var/cache/pacman/pkg/linux-aarch64-<version>-aarch64.pkg.tar.xz`
— followed by `mkinitcpio -P` and a reboot. **Fix:** `install-firstboot.sh`
now checks `/boot` is actually mounted *before* touching pacman at all,
and fails fast with a clear message instead of silently corrupting the
install.

**`hwclock --systohc` fails with "Cannot access the Hardware Clock via
any known method."** The Pi has no battery-backed RTC out of the box, so
there's nothing for `hwclock` to sync to — this isn't a config problem,
it's expected on stock hardware (only add-on RTC HATs provide
`/dev/rtc0`). **Fix:** `install-firstboot.sh` only runs
`hwclock --systohc` if `/dev/rtc0` exists. The same fix was needed
separately in the `server-automation` Ansible project's `common` role,
which called the same command unconditionally on every host.

**`nmcli`/`iwctl` don't do anything useful even though `iwd` and
`networkmanager` are both installed.** `install-firstboot.sh` installed
both packages but never enabled `iwd.service`, and NetworkManager
defaults to a `wpa_supplicant` backend that isn't installed at all — so
NetworkManager has no working WiFi backend regardless of `iwd` being
present. **Fix:** `install-firstboot.sh` now writes
`/etc/NetworkManager/conf.d/wifi_backend.conf` (`wifi.backend=iwd`) and
enables `iwd`, so `nmcli device wifi connect` works after the first
reboot with no manual backend wiring.
