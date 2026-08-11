#!/bin/bash
# Script that updates the aptlist.txt, installedpackages.txt and the .tar.gz backup of apt packages at the /home/yasir folder


# Backing up apt lists in server
# Outdated ones that were pain in the ass
#sudo apt list --installed > ~/aptlist.txt &
#sudo apt-clone clone /home/yasir/apt-clone-state.tar.gz &
sudo apt-mark showmanual > ~/installedpackages.txt
