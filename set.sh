#!/bin/zsh
curl -L https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k
git clone https://github.com/gpakosz/.tmux.git ~/.tmux
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
mkdir ~/.config
mkdir ~/.config/nvim
cp ~/gitRepos/settingfiles/init.vim ~/.config/nvim/init.vim
mv ~/.zshrc ~/.zshrc.bak
cp ~/gitRepos/settingfiles/.zshrc ~/.zshrc
ln -s ~/.config/nvim/init.vim ~/init.vim
nvim +PlugInstall +qall

