#!/bin/bash

# echo [multilib] >> /etc/pacman.conf
# echo Include = /etc/pacman.d/mirrorlist >> /etc/pacman.conf

pacman -Syu steam vulkan-mesa-layers lib32-libva-mesa-driver lib32-mesa-vdpau lib32-dbus lib32-jack lib32-libavtp lib32-libsamplerate lib32-libpulse lib32-speexdsp lib32-vulkan-mesa-layers steam-native-runtime
