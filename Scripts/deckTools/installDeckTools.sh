#!/bin/bash
# Install CLI tools into ~/.local/bin on the Steam Deck so they SURVIVE SteamOS updates.
#
# WHY THIS EXISTS
# SteamOS has an immutable, A/B-partitioned rootfs: /dev/nvme0n1p4 and p5. An update does
# not patch the running system, it writes a whole new image to the OTHER slot and boots it.
# So everything `pacman -S` put in /usr is gone, and /etc/pacman.d/gnupg reverts with it --
# which is why the keyring needed re-initialising (`fixKeys`) over and over.
#
# /home is a SEPARATE partition (p8) that updates never touch. Anything in ~/.local/bin
# therefore persists forever. These are static musl builds, so they also do not care if
# SteamOS ships a different glibc after an update.
#
# Re-runnable and idempotent. Run it again to upgrade everything.
#   bash installDeckTools.sh          # install/upgrade all
#   bash installDeckTools.sh --list   # just show what is installed
set -uo pipefail

BIN="$HOME/.local/bin"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$BIN"

ok=0; failed=0; skipped=0

have() { command -v "$1" >/dev/null 2>&1; }
say() { printf '  %-10s %s\n' "$1" "$2"; }

# Fetch a GitHub release asset. $1=repo $2=grep pattern for the asset URL
gh_dl() {
    local repo="$1" pat="$2" url
    url=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
          | grep -oE '"browser_download_url": *"[^"]+"' | cut -d'"' -f4 | grep -E "$pat" | head -1)
    [ -n "$url" ] || return 1
    curl -fsSL -o "$TMP/asset" "$url" || return 1
    echo "$url"
}

# $1=name $2=repo $3=asset pattern $4=path inside archive (or "-" for a bare binary)
install_tool() {
    local name="$1" repo="$2" pat="$3" inner="$4" url
    url=$(gh_dl "$repo" "$pat") || { say "$name" "FAILED (no matching release asset)"; failed=$((failed+1)); return; }
    cd "$TMP" || return
    case "$url" in
        *.tar.gz|*.tgz) tar xzf asset 2>/dev/null ;;
        *.tar.xz)       tar xJf asset 2>/dev/null ;;
        *.tar.bz2|*.tbz) tar xjf asset 2>/dev/null ;;
        *.zip)          unzip -qo asset 2>/dev/null ;;
        *)              cp asset "$name" ;;
    esac
    local src
    if [ "$inner" = "-" ]; then src="$TMP/$name"; else src=$(find "$TMP" -type f -name "$inner" | head -1); fi
    if [ -z "$src" ] || [ ! -f "$src" ]; then say "$name" "FAILED (binary not found in archive)"; failed=$((failed+1)); rm -rf "$TMP:?"/*; return; fi
    install -m755 "$src" "$BIN/$name" && say "$name" "OK -> $BIN/$name" && ok=$((ok+1))
    rm -rf "${TMP:?}"/*
}

if [ "${1:-}" = "--list" ]; then
    echo "Tools in $BIN:"
    ls -la "$BIN" 2>/dev/null | tail -n +4 | sed 's/^/  /'
    exit 0
fi

echo "Installing persistent CLI tools into $BIN"
echo

install_tool eza    eza-community/eza   'x86_64-unknown-linux-musl.tar.gz$'  'eza'
install_tool fd     sharkdp/fd          'x86_64-unknown-linux-musl.tar.gz$'  'fd'
install_tool rg     BurntSushi/ripgrep  'x86_64-unknown-linux-musl.tar.gz$'  'rg'
install_tool jq     jqlang/jq           'jq-linux-amd64$'                    '-'
install_tool btop   aristocratos/btop   'x86_64-unknown-linux-musl.tar.gz$'  'btop'
install_tool fzf    junegunn/fzf        'linux_amd64.tar.gz$'                'fzf'

# Neovim is NOT just a binary. It resolves VIMRUNTIME relative to the executable
# ($prefix/share/nvim/runtime, where prefix is bin/..), so installing only ~/.local/bin/nvim
# leaves it hunting for /usr/local/share/nvim and failing with:
#   E484: Can't open file /usr/local/share/nvim/syntax/syntax.vim
# Install the runtime tree into ~/.local/share/nvim/runtime so the prefix resolves.
install_nvim() {
    local url
    url=$(curl -fsSL "https://api.github.com/repos/neovim/neovim/releases/latest" 2>/dev/null \
          | grep -oE '"browser_download_url": *"[^"]+"' | cut -d'"' -f4 \
          | grep -E 'nvim-linux-x86_64\.tar\.gz$' | head -1)
    [ -n "$url" ] || { say nvim "FAILED (no release asset)"; failed=$((failed+1)); return; }
    curl -fsSL -o "$TMP/nvim.tgz" "$url" || { say nvim "FAILED (download)"; failed=$((failed+1)); return; }
    tar xzf "$TMP/nvim.tgz" -C "$TMP" || { say nvim "FAILED (extract)"; failed=$((failed+1)); return; }
    local root
    root=$(find "$TMP" -maxdepth 1 -type d -name 'nvim-linux*' | head -1)
    [ -n "$root" ] || { say nvim "FAILED (unexpected archive layout)"; failed=$((failed+1)); return; }
    install -m755 "$root/bin/nvim" "$BIN/nvim"
    mkdir -p "$HOME/.local/share/nvim"
    rm -rf "$HOME/.local/share/nvim/runtime"
    cp -r "$root/share/nvim/runtime" "$HOME/.local/share/nvim/runtime"
    # lib/nvim holds the bundled parsers/plugins on some builds; harmless when absent
    [ -d "$root/lib/nvim" ] && { mkdir -p "$HOME/.local/lib"; rm -rf "$HOME/.local/lib/nvim"; cp -r "$root/lib/nvim" "$HOME/.local/lib/nvim"; }
    say nvim "OK -> $BIN/nvim (+ runtime in ~/.local/share/nvim)"
    ok=$((ok+1))
    rm -rf "${TMP:?}"/*
}
install_nvim
install_tool bat    sharkdp/bat         'x86_64-unknown-linux-musl.tar.gz$'  'bat'
install_tool delta  dandavison/delta    'x86_64-unknown-linux-musl.tar.gz$'  'delta'
install_tool zoxide ajeetdsouza/zoxide  'x86_64-unknown-linux-musl.tar.gz$'  'zoxide'

# Tools with no upstream static build. SteamOS ships no compiler, but tar here can read
# Arch's .pkg.tar.zst, so lift the binary straight out of the official package. These are
# glibc-linked rather than static, which is fine: SteamOS *is* Arch, and the binary lives
# on /home so it survives the update that would otherwise remove it.
arch_extract() {
    local name="$1" pkg="$2" path="$3" repo
    [ -x "$BIN/$name" ] && { say "$name" "already present"; skipped=$((skipped+1)); return; }
    # archlinux.org/packages/<repo>/<arch>/<pkg>/download/ 302s to a mirror holding the
    # CURRENT version, so there is no version string to guess or keep up to date.
    for repo in extra core; do
        if curl -fsSL -o "$TMP/pkg.tar.zst" "https://archlinux.org/packages/$repo/x86_64/$pkg/download/" 2>/dev/null; then
            if (cd "$TMP" && tar --zstd -xf pkg.tar.zst "$path" 2>/dev/null && install -m755 "$path" "$BIN/$name"); then
                say "$name" "OK (from Arch $repo/$pkg)"; ok=$((ok+1)); rm -rf "${TMP:?}"/*; return
            fi
        fi
    done
    say "$name" "skipped (could not fetch $pkg)"; skipped=$((skipped+1)); rm -rf "${TMP:?}"/*
}

arch_extract tree tree usr/bin/tree
arch_extract ncdu ncdu usr/bin/ncdu

# exa is abandoned upstream and replaced by eza. Keep the old name working for muscle
# memory and for the aliases in .bashrc that still say `exa`.
if [ -x "$BIN/eza" ]; then ln -sf eza "$BIN/exa"; say exa "-> symlink to eza"; fi

# vim: SteamOS ships it, but it lives on the rootfs and disappears on update. nvim is the
# persistent one, so point `vi`/`vim` at it only if the real vim has gone missing.
cat > "$BIN/vim-fallback" <<'VIMEOF'
#!/bin/bash
# If the pacman vim survived, use it. Otherwise fall back to the persistent nvim.
if [ -x /usr/bin/vim ]; then exec /usr/bin/vim "$@"; fi
exec "$HOME/.local/bin/nvim" "$@"
VIMEOF
chmod +x "$BIN/vim-fallback"

echo
echo "installed/updated: $ok    failed: $failed    skipped: $skipped"
echo
echo "These live on /home, which SteamOS updates do not touch."
echo "Re-run this script any time to upgrade them."
