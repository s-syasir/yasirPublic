#!/bin/bash
# Installs the format-on-save tools vim/neovim use (same ones VS Code bundles):
# isort, prettier, clang-format, gofmt. Black, shfmt and dart are assumed present.
# Desktop only (laptop + PC); servers skip formatting when these are missing.
set -euo pipefail

# clang-format for C/C++, golang-go provides gofmt, pipx for isort
sudo apt-get install -y clang-format golang-go pipx

# apt's isort is 5.6 (2020); pipx gets the current release VS Code's isort extension uses
pipx install isort || pipx upgrade isort

# npm's global prefix is /usr, so this needs sudo
sudo npm install -g prettier

echo
for t in isort prettier clang-format gofmt; do
    printf '%-13s ' "$t"
    command -v "$t" || echo "NOT FOUND (open a new terminal if ~/.local/bin was just added to PATH)"
done
