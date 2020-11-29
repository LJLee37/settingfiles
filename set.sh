#!/bin/zsh
brew install neovim tmux git yarn minecraft google-chrome discord visual-studio-code karabiner-elements iterm2 keka obs steam zoom onedrive twitch google-backup-and-sync vimr virtualbox iina keepingyouawake musescore transmission postman
python3 -m pip install neovim
curl -L https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh | sh
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k
# p10k configure
git clone https://github.com/gpakosz/.tmux.git ~/.tmux
ln -s -f ~/.tmux/.tmux.conf ~/.tmux.conf
cp ~/.tmux/.tmux.conf.local ~/
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
     https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
#curl -sL install-node.now.sh/lts | sudo bash
#curl --compressed -o- -L https://yarnpkg.com/install.sh | bash
mkdir ~/.config
mkdir ~/.config/nvim
cp ~/gitRepos/settingfiles/init.vim ~/.config/nvim/init.vim
mv ~/.zshrc ~/.zshrc.bak
cp ~/gitRepos/settingfiles/.zshrc ~/.zshrc
ln -s ~/.config/nvim/init.vim ~/init.vim
nvim +PlugInstall +qall
cp karabiner.json ~/.config/karabiner/karabiner.json
