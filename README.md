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

## macOS notes

`set.sh` installs GUI apps via Homebrew (including Casks) and copies
`karabiner.json` into place for Karabiner-Elements.
