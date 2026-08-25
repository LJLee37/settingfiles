#!/bin/zsh
sudo pacman -Syu htop nodejs yarn keychain clang fastfetch
scp -P 3759 ljlee@rpi.ljlee37.com:.ssh/ljlee_id ~/.ssh/ljlee_id
scp -P 3759 ljlee@rpi.ljlee37.com:.ssh/ljlee_id.pub ~/.ssh/ljlee_id.pub
cat ~/.ssh/ljlee_id.pub >> ~/.ssh/authorized_keys
curl -L https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh
python3 -m pip install neovim
mv ~/.zshrc ~/.zshrc.bak
cp ~/gitRepos/Personal/settingfiles/.zshrc ~/.zshrc
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.7/install.sh | bash
source ~/.zshrc
nvm install --lts
nvm alias default 'lts/*'
yarn global add neovim
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k
git clone https://github.com/gpakosz/.tmux.git ~/.tmux
ln -s -f ~/.tmux/.tmux.conf ~/.tmux.conf
cp ~/.tmux/.tmux.conf.local ~/
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
     https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
mkdir ~/.config
mkdir ~/.config/nvim
cp ~/gitRepos/Personal/settingfiles/init.vim ~/.config/nvim/init.vim
ln -s ~/.config/nvim/init.vim ~/init.vim
nvim +PlugInstall +qall
git config --global user.name "LJLee37"
git config --global user.email "ljlee3759@gmail.com"
