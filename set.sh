#!/bin/zsh
sudo pacman -Syu base-devel htop neovim nodejs yarn python-pip tmux keychain clang
scp -P 3759 ljlee@rpi.ljlee37.com:.ssh/ljlee_id ~/.ssh/ljlee_id
scp -P 3759 ljlee@rpi.ljlee37.com:.ssh/ljlee_id.pub ~/.ssh/ljlee_id.pub
cat ~/.ssh/ljlee_id.pub >> ~/.ssh/authorized_keys
chsh
curl -L https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh | sh
python3 -m pip install neovim
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
mv ~/.zshrc ~/.zshrc.bak
cp ~/gitRepos/Personal/settingfiles/.zshrc ~/.zshrc
ln -s ~/.config/nvim/init.vim ~/init.vim
nvim +PlugInstall +qall

