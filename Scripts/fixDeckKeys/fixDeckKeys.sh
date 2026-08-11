#!/bin/bash
# NOTE: a script for fixing the keys pacman when launching the steamdeck after a while

# First disable read-only FS
sudo steamos-readonly disable

# Remove the pacman.d/gnupg keys
sudo rm -rf /etc/pacman.d/gnupg/

# init the pacman keys
sudo pacman-key --init

# populate the keys with archlinux and holo (which is the steamdeck stuff?)
sudo pacman-key --populate archlinux holo

# running pacman update equivalent to enable the new keys
sudo pacman -Sy archlinux-keyring

# Lastly, re-enable read-only FS
sudo steamos-readonly enable
