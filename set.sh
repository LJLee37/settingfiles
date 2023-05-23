#!/bin/bash
sudo apt update && sudo apt upgrade -y
sudo apt install zsh tmux neovim nodejs yarnpkg htop g++ python3-pip keychain -y
curl -L https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh | sh
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k
# p10k configure
git clone https://github.com/gpakosz/.tmux.git ~/.tmux
ln -s -f ~/.tmux/.tmux.conf ~/.tmux.conf
cp ~/.tmux/.tmux.conf.local ~/
python3 -m pip install neovim
yarn global add neovim
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
     https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
mkdir ~/.config
mkdir ~/.config/nvim
cp ~/gitRepos/settingfiles/init.vim ~/.config/nvim/init.vim
mv ~/.zshrc ~/.zshrc.bak
cp ~/gitRepos/settingfiles/.zshrc ~/.zshrc
ln -s ~/.config/nvim/init.vim ~/init.vim
nvim +PlugInstall +qall

