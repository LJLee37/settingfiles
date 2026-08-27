#!/bin/zsh
# Stage 3 (run as the normal user, after install-firstboot.sh): pull in dotfiles,
# oh-my-zsh, tmux, vim-plug, nvm/yarn. Idempotent and non-interactive so it is
# safe to re-run and matches what the server-automation Ansible roles do.
set -euo pipefail

# oh-my-zsh: git clone instead of the upstream install.sh, which runs chsh,
# overwrites ~/.zshrc, and exec's zsh at the end (all unwanted here).
[ -d ~/.oh-my-zsh ] || git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh

P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
[ -d "$P10K_DIR" ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"

[ -d ~/.tmux ] || git clone https://github.com/gpakosz/.tmux.git ~/.tmux
ln -s -f ~/.tmux/.tmux.conf ~/.tmux.conf
cp ~/.tmux/.tmux.conf.local ~/

curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
     https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.7/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm alias default 'lts/*'
curl --compressed -o- -L https://yarnpkg.com/install.sh | bash

mkdir -p ~/.config/nvim
cp ~/gitRepos/settingfiles/init.vim ~/.config/nvim/init.vim
# Keep the very first ~/.zshrc as the backup; don't clobber it on re-runs, and
# tolerate a fresh box that has no ~/.zshrc yet.
if [ ! -e ~/.zshrc.bak ] && [ -e ~/.zshrc ]; then
  mv ~/.zshrc ~/.zshrc.bak
fi
cp ~/gitRepos/settingfiles/.zshrc ~/.zshrc
ln -s -f ~/.config/nvim/init.vim ~/init.vim
nvim --headless "+PlugInstall --sync" +qall
