#!/bin/zsh
# Run as the normal user after install2.sh: pull in dotfiles, oh-my-zsh, tmux,
# vim-plug, nvm/yarn. set -e + existence guards so it is safe to re-run.
set -euo pipefail
sudo pacman -Syu htop nodejs yarn keychain clang fastfetch python-pynvim
# Restore the SSH identity (ljlee_id, authorized_keys, known_hosts, ...) from the
# clean-reinstall migration archive on the surviving /srv pool -- a freshly
# reinstalled box has no key and no known_hosts entry to scp it off rpi.
# Build the archive on the OLD box first:  tar czpf "$SSH_ARCHIVE" -C ~ .ssh
SSH_ARCHIVE="${SSH_ARCHIVE:-/srv/server-migration/snapshot/ssh-ljlee.tgz}"
if [ ! -e ~/.ssh/ljlee_id ]; then
  test -e "$SSH_ARCHIVE" || { echo "missing $SSH_ARCHIVE -- create it on the old box first" >&2; exit 1; }
  tar xzpf "$SSH_ARCHIVE" -C ~
fi
chmod 700 ~/.ssh
[ -e ~/.ssh/authorized_keys ] && chmod 600 ~/.ssh/authorized_keys
# Make sure our pubkey is authorized (no-op if the restored archive already has it).
grep -qxF "$(cat ~/.ssh/ljlee_id.pub)" ~/.ssh/authorized_keys 2>/dev/null \
  || cat ~/.ssh/ljlee_id.pub >> ~/.ssh/authorized_keys
# oh-my-zsh: git clone instead of the upstream install.sh, which runs chsh,
# overwrites ~/.zshrc, and exec's zsh at the end (all unwanted here).
# Full clone (no --depth=1) so oh-my-zsh's own auto-update does not choke on a
# shallow checkout later.
[ -d ~/.oh-my-zsh ] || git clone https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh
# Keep the very first ~/.zshrc as the backup; don't clobber it on re-runs, and
# tolerate a fresh box that has no ~/.zshrc yet.
if [ ! -e ~/.zshrc.bak ] && [ -e ~/.zshrc ]; then
  mv ~/.zshrc ~/.zshrc.bak
fi
cp ~/gitRepos/settingfiles/.zshrc ~/.zshrc
export NVM_DIR="$HOME/.nvm"
# -fsSL so an HTTP error aborts here instead of being piped into bash.
# PROFILE=/dev/null: the deployed .zshrc already sources nvm, so stop the
# installer from appending a duplicate init block to it.
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.7/install.sh | PROFILE=/dev/null bash
# nvm.sh is not `set -u` clean; load it with the option off.
set +u
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
set -u
nvm install --lts
nvm alias default 'lts/*'
yarn global add neovim
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
[ -d "$P10K_DIR" ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
[ -d ~/.tmux ] || git clone https://github.com/gpakosz/.tmux.git ~/.tmux
ln -s -f ~/.tmux/.tmux.conf ~/.tmux.conf
# Don't overwrite local tmux tweaks on a re-run.
[ -e ~/.tmux.conf.local ] || cp ~/.tmux/.tmux.conf.local ~/
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
     https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
mkdir -p ~/.config/nvim
cp ~/gitRepos/settingfiles/init.vim ~/.config/nvim/init.vim
ln -s -f ~/.config/nvim/init.vim ~/init.vim
nvim --headless "+PlugInstall --sync" +qall
git config --global user.name "LJLee37"
git config --global user.email "ljlee3759@gmail.com"
