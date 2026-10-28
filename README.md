# settingFiles

Personal dotfiles and OS setup scripts. This repository separates OS/target
environments by **branch** instead of by directory — clone the branch that
matches your target machine, not `master` directly.

## Branches

| Branch | Purpose | Notes |
|---|---|---|
| `master` | Common base | Shared dotfiles only; starting point for new OS branches |
| `arch` | Arch Linux (x86_64) | Generic install (btrfs subvolumes, optional LUKS) + per-purpose profiles; also rebuilds the portable `LJTF` control card |
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

## Arch Linux (x86_64) install order

The `arch` branch does two jobs with one set of scripts: a generic Arch install
for any machine, and rebuilding the `server-automation` control node, which is
a portable SD card (`hosts/ljtf.env`) meant to boot on any computer. The card
is simply the generic install with more profiles plus `install-control-node.sh`.
`hosts/ljusb.env` is the spare control node LJUSB, a 32GB USB stick built the
same way: the card hangs on one keyring with FIDO2 token A, the spare on another
with token B, so losing either keyring leaves a working control node and token.

Per-machine values live in `hosts/<machine>.env` (copy `hosts/example.env`).
Switches: `PORTABLE` (initramfs with every storage/keyboard driver plus a
fallback image, GRUB menu delay, zram instead of swap), `LUKS` (LUKS2 root),
`VAULT` (restore an existing LUKS partition image bit-for-bit), and
`DISK_BYTES` (refuse to wipe any disk of a different size).

1. `sudo ./install0-disks.sh hosts/X.env <disk> [vault.img]` wipes the disk
   and lays out ESP | (vault) | root, with root as (LUKS2 →) btrfs and the
   subvolumes `@ @home @snapshots @var_log @pkg`. It runs from the Arch ISO
   or from any running Arch box (e.g. main-server, via the card in a USB
   reader). It refuses a mounted or open disk.
2. `sudo ./install1.sh hosts/X.env <disk>` mounts the target at
   `/mnt/install-<prefix>`, pacstraps `profiles/base.txt`, writes fstab and
   crypttab, copies this repo in, and runs `install2.sh` in the chroot (locale,
   hostname, user, initramfs, GRUB on the removable path with `--no-nvram`,
   NetworkManager). Safe to re-run.
3. Optional, still in the chroot:
   `sudo arch-chroot /mnt/install-<prefix> /home/<user>/gitRepos/settingfiles/install-profile.sh <profiles>`.
4. After the first boot, as the user: `./set.sh` (zsh, oh-my-zsh, p10k with
   its fonts, dotfiles as symlinks into this repo, nvm), then
   `./install-profile.sh <profiles>` (re-runs fill in anything missing,
   including AUR packages that cannot be built as root).
5. LUKS machines: `sudo ./luks-fido2.sh` enrolls FIDO2 tokens A and B on every
   LUKS partition of the root disk and test-opens each one with each token,
   so each partition opens with its own passphrase, token A, or token B.
6. Control node only: `install-control-node.sh` turns this machine into the
   `server-automation` control node and keeps it current on re-runs (pacman
   tools, AUR `claude-code`, `server-automation`, `worklog` and `llm-wiki`
   clones, commit signing, SSH certificate setup, the `github.com` SSH block,
   Ansible collections, lid-on-AC, the Claude Code mods, the `cc-timelog-push`
   user timer, and the global `~/.claude/CLAUDE.md` from
   `control-node/CLAUDE.md`). `--check` only reports.
   It needs a terminal for sudo and the FIDO2 PIN and touch, and prints what
   it cannot do by hand at the end (gh login, `host_vars/*.yml`, vault password).
   The token it signs and logs in with is `CONTROL_FIDO_KEY` from the env whose
   `HOST_NAME` matches this machine (`ljlee_sk_a` on the card, `ljlee_sk_b` on
   the spare); `FIDO_KEY=... ./install-control-node.sh` overrides it.
   `CONTROL_CC_TIMELOG_PUSH=yes` (set on both) turns on `cc-timelog-push.timer`:
   every 30 minutes it runs `server-automation`'s `cc-activity turns` over the
   last 7 days of Claude Code transcripts (times, cwd, session id and title,
   never prompt text) and writes the JSON over ssh to
   `~/.local/state/hermes-cc-timelog/inbox/<HOST_NAME>.json` on main-server
   and raspi, where the 22:30 Hermes wrap-up merges it into the time log. A
   node that is down or an expired certificate only skips that node until the
   next run; `journalctl --user -u cc-timelog-push` shows what happened.
   It also installs `networkmanager-strongswan` and `nm-connection-editor` so the
   control node can join a node's IKEv2 VPN (main-server's SMB shares are only
   reachable inside it). Create the profile with `nm-connection-editor`
   (IPsec/IKEv2 (strongswan), server = the node's VPN domain, certificate empty
   so the system CAs check the server, EAP user and password, "Request an inner
   IP address" on): the plugin ships only a GTK3 editor, so GNOME Settings (GTK4)
   shows its fields but they do not work. The profile is per machine and is not
   created by the script, since the EAP password must not live in this repo.

Profiles are `profiles/<name>.txt` (one package per line, `aur:<name>` for AUR)
plus an optional `profiles/<name>.sh` with `pre`/`post`/`check` hooks:
`./install-profile.sh --list` shows them, `--check` only reports.

`set-hibernate.sh` predates this layout (swap partition, udev-based initramfs)
and is not for portable machines: resuming a card on a different computer than
the one it hibernated on corrupts its filesystem.
