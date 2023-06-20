#!/bin/bash
sudo pacman -Syu firefox discord noto-fonts-cjk ibus-hangul
mkdir ~/aur
cd ~/aur
git clone https://aur.archlinux.org/visual-studio-code-bin
cd visual-studio-code-bin
makepkg -sic
cd ..
git clone https://aur.archlinux.org/minecraft-launcher
cd minecraft-launcher
makepkg -sic

