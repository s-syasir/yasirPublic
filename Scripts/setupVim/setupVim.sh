#!/bin/bash
# Installs the vim/neovim plugins listed in ~/.vimrc. Run after a git pull on a new machine.
# The settings and keymaps come from ~/.vimrc via git; this script only sets up plugins.
# Steps: get vim-plug if missing, make swap/undo folders, install plugins + remove
# unlisted ones, then report missing optional tools (it never installs those itself).
# Safe to re-run; plugins live in ~/.vim/plugged, which git ignores.
set -euo pipefail

PLUG=~/.vim/autoload/plug.vim

for tool in git curl; do
    command -v "$tool" >/dev/null || { echo "Missing $tool: sudo apt install $tool" >&2; exit 1; }
done

if [ ! -f "$PLUG" ]; then
    echo "Downloading vim-plug..."
    curl -fLo "$PLUG" --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

mkdir -p -m 700 ~/.local/state/vim/swap ~/.local/state/vim/undo

# Vim and Neovim share ~/.vim/plugged, so one editor installs for both
if command -v nvim >/dev/null; then
    EDITOR_CMD=(nvim --headless)
elif vim --version 2>/dev/null | grep -q '+eval'; then
    EDITOR_CMD=(vim -Es -u ~/.vimrc -i NONE)
else
    echo "Neither neovim nor a full vim found (vim-tiny can't run plugins): sudo apt install neovim" >&2
    exit 1
fi

echo "Installing plugins and removing ones no longer in ~/.vimrc..."
"${EDITOR_CMD[@]}" "+PlugInstall --sync" "+PlugClean!" "+qa" || true

echo
echo "Installed plugins:"
ls ~/.vim/plugged

echo
echo "Optional tools:"
command -v rg >/dev/null && echo "  ok   ripgrep (\\f search)" || echo "  MISSING ripgrep for \\f search: sudo apt install ripgrep"
if command -v nvim >/dev/null; then
    { command -v xclip || command -v wl-copy; } >/dev/null && echo "  ok   neovim clipboard" \
        || echo "  none neovim clipboard (fine on a headless server; desktop: sudo apt install xclip)"
fi
if command -v vim >/dev/null && ! vim --version | grep -q '+clipboard'; then
    echo "  none vim clipboard (desktop only: sudo apt install vim-gtk3)"
fi

echo
echo "Format-on-save tools (each is skipped if missing; desktop only, servers can ignore):"
check() { command -v "$1" >/dev/null && echo "  ok   $1" || echo "  MISSING $1: $2"; }
check black "pipx install black"
check isort "pipx install isort"
check prettier "npm install -g prettier"
check shfmt "sudo apt install shfmt"
check clang-format "sudo apt install clang-format"
check dart "comes with Flutter"
check gofmt "sudo apt install golang-go"

echo
echo "Update plugins later with :PlugUpdate inside vim/nvim."
