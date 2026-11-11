#!/bin/bash
# Script that updates the installedpackages.txt and the installeddependencies.txt with the pacman packages at the home folder


# Backing up pacman lists in server
sudo pacman -Qe > ~/installedpackages.txt
sudo pacman -Qd > ~/installeddependencies.txt
