#!/bin/bash
sudo apt update && sudo apt upgrade -y
sudo apt install zsh tmux neovim ctags python3-neovim python3-pip htop keychain git g++ gdb neofetch -y
git config --global user.name "LJLee37"
git config --global user.email "ljlee3759@gmail.com"
git config --global user.signingkey 8090E75C56E49652
git config --global commit.gpgsign true
git config --global gpg.program gpg
