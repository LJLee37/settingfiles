#!/bin/sh
apk add wget curl git zsh neovim python3 py3-pip yarn ctags g++ clang-extra-tools python3-dev aports-build neofetch tmux
curl -L https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh | sh
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k
python3 -m pip install neovim
yarn global add neovim
# p10k configure
git clone https://github.com/gpakosz/.tmux.git ~/.tmux
ln -s -f ~/.tmux/.tmux.conf ~/.tmux.conf
cp ~/.tmux/.tmux.conf.local ~/
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
mkdir ~/.config
mkdir ~/.config/nvim
cp ~/gitRepos/settingfiles/init.vim ~/.config/nvim/init.vim
mv ~/.zshrc ~/.zshrc.bak
cp ~/gitRepos/settingfiles/.zshrc ~/.zshrc
ln -s ~/.config/nvim/init.vim ~/init.vim
nvim +PlugInstall +qall
nvim +CocInstall coc-clangd coc-python +qall

