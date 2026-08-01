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
   OS yet at this point, so this step can't run on the Pi itself.
2. Boot the Pi from that media. SSH in as `alarm`/`alarm` (or `root`/`root`),
   copy `install-firstboot.sh` over, and run it as root — pass `5` as the
   first argument on a Raspberry Pi 5 (see the script header). This does
   `pacman-key` init, a full system update, locale/timezone/hostname,
   creates a user account, and enables NetworkManager/bluetooth/sshd.
3. Reboot, log in as that user, then run `set.sh` to pull in dotfiles.
4. `backup.sh` makes a full-system + boot-partition backup and copies it
   to a LAN host — check the destination host/path before running it.

Written against a Raspberry Pi 4 Model B (64-bit) using the generic
`ArchLinuxARM-rpi-aarch64-latest.tar.gz` image (ALARM lists this as also
covering the Pi 3 and 400). The Pi 5 has no dedicated ALARM image as of
this writing; `install-firstboot.sh 5` swaps in the kernel package the
community currently recommends there instead. Re-check
https://archlinuxarm.org for your specific model before a new install —
ALARM's supported devices, image names, and procedure do change over time.
