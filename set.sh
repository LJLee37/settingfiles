#!/bin/zsh
# 보통 사용자로, 첫 부팅 뒤에 돌립니다: 닷파일, oh-my-zsh, powerlevel10k(글꼴 포함), tmux, vim-plug, nvm.
# 닷파일은 이 저장소를 가리키는 심링크라 git pull 하면 바로 최신이 됩니다(노드의 dotfiles role 과 같은 방식).
# 다시 돌려도 됩니다.
set -euo pipefail
REPO=${0:A:h}

sudo pacman -Syu --needed htop nodejs yarn clang fastfetch python-pynvim

# 로그인 셸. install2.sh 로 만든 계정은 이미 zsh 입니다.
case "$(getent passwd "$USER" | cut -d: -f7)" in
  */zsh) ;;
  *) chsh -s /usr/bin/zsh ;;
esac

# oh-my-zsh: 공식 install.sh 대신 git clone(그 스크립트는 chsh, ~/.zshrc 덮어쓰기, exec zsh 를 함).
# 전체 clone 이어야 oh-my-zsh 의 자동 업데이트가 얕은 clone 에서 막히지 않습니다.
[ -d ~/.oh-my-zsh ] || git clone https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
[ -d "$P10K_DIR" ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"

# powerlevel10k 가 권하는 MesloLGS NF 글꼴(터미널 글꼴로 고르면 아이콘이 깨지지 않음)
fontdir=~/.local/share/fonts
for f in "MesloLGS NF Regular.ttf" "MesloLGS NF Bold.ttf" "MesloLGS NF Italic.ttf" "MesloLGS NF Bold Italic.ttf"; do
  [ -e "$fontdir/$f" ] || curl -fsSL --create-dirs -o "$fontdir/$f" \
    "https://github.com/romkatv/powerlevel10k-media/raw/master/${f// /%20}"
done
command -v fc-cache >/dev/null && fc-cache -f "$fontdir"

# 닷파일 심링크. 처음 있던 진짜 파일은 한 번만 .bak 으로 남깁니다.
link() {  # link <저장소 안 파일> <놓을 곳>
  if [ -e "$2" ] && [ ! -L "$2" ] && [ ! -e "$2.bak" ]; then mv "$2" "$2.bak"; fi
  mkdir -p "${2:h}"
  ln -sfn "$1" "$2"
}
link "$REPO/.zshrc" ~/.zshrc
link "$REPO/.tmux.conf" ~/.tmux.conf
link "$REPO/init.vim" ~/.config/nvim/init.vim
ln -sfn ~/.config/nvim/init.vim ~/init.vim

export NVM_DIR="$HOME/.nvm"
# -fsSL: HTTP 오류면 bash 에 흘려 넣지 않고 여기서 멈춤. PROFILE=/dev/null: .zshrc 가 이미 nvm 을 부르므로
# 설치 스크립트가 init 블록을 또 덧붙이지 않게.
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.7/install.sh | PROFILE=/dev/null bash
# nvm.sh 는 set -u 에서 깨집니다.
set +u
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
set -u
nvm install --lts
nvm alias default 'lts/*'
yarn global add neovim

curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
     https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
nvim --headless "+PlugInstall --sync" +qall
git config --global user.name "LJLee37"
git config --global user.email "ljlee3759@gmail.com"
