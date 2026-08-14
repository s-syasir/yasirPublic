#!/bin/bash
# Point every emulator's save directory at ~/emulator-saves/, which Syncthing shares with
# the NAS. Safe to run on any machine, and safe to re-run.
#
# WHY: saves were split across two trees. ~/emulator-saves (synced) held ryujinx/retroarch/
# yuzu/citra, while ~/Emulation/saves (EmuDeck's tree, NOT synced) held dolphin, primehack
# and azahar -- including a GameCube memory card that existed in exactly one place. EmuDeck's
# backend was deleted by restoreDeck.sh's `rm -rf ~/.config`, so nothing maintains that tree
# any more. This consolidates on the synced one.
#
# SAFETY: every merge uses --ignore-existing, so an existing file in ~/emulator-saves is
# never overwritten by one from elsewhere. A tarball of everything is taken before any
# change. Nothing is deleted until its content has been copied and verified.
set -uo pipefail

QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

SAVES="$HOME/emulator-saves"
EMUDECK="$HOME/Emulation/saves"
STAMP=$(date +%Y%m%d-%H%M)
BACKUP="$HOME/emulator-saves-backup-$STAMP.tgz"
linked=0; merged=0; skipped=0

# The backup is LAZY: taken only when something is actually about to change. This script is
# wired to a systemd timer, and tarballing ~26MB every run would add a quarter of a GB a day
# for nothing. Steady state (everything already linked) writes nothing at all.
backup_taken=0
take_backup() {
    [ "$backup_taken" = 1 ] && return
    tar czf "$BACKUP" -C "$HOME" --ignore-failed-read emulator-saves 2>/dev/null
    [ -d "$EMUDECK" ] && tar rzf "$BACKUP" -C "$HOME" Emulation/saves 2>/dev/null || true
    echo "  BACKUP  $BACKUP ($(du -h "$BACKUP" 2>/dev/null | cut -f1))"
    backup_taken=1
}

# Prune our own old backups, keeping the 5 most recent.
ls -1t "$HOME"/emulator-saves-backup-*.tgz 2>/dev/null | tail -n +6 | xargs -r rm -f


# Only wire up an emulator that is ACTUALLY INSTALLED on this machine. Without this the
# script happily created ~/.local/share/azahar-emu/sdmc and friends on a machine with no
# azahar, leaving symlinks and empty dirs that look like a working setup and would confuse
# a later install. The script is shared between the Deck and the PC via Syncthing, and they
# do not have the same emulators, so the check has to be per-machine.
#   have flatpak:<app-id>     -> is that flatpak installed
#   have appimage:<glob>      -> does an AppImage matching that glob exist
#   have path:<path>          -> does that path already exist
have() {
    case "$1" in
        flatpak:*)  flatpak info "${1#flatpak:}" >/dev/null 2>&1 ;;
        appimage:*) ls $HOME/Applications/${1#appimage:} >/dev/null 2>&1 ;;
        path:*)     [ -e "${1#path:}" ] ;;
        *)          return 0 ;;
    esac
}

# link_dir, but only if the emulator is present. $1 = detection spec, rest as link_dir.
link_if() {
    local spec="$1"; shift
    if have "$spec"; then link_dir "$@"; else
        printf "  ABSENT  %-52s (%s not installed)\n" "${1/#$HOME/\~}" "${spec#*:}"; skipped=$((skipped+1))
    fi
}

# Merge a directory into the shared tree without ever overwriting, then replace it
# with a symlink. $1 = the emulator's own path, $2 = destination under ~/emulator-saves
link_dir() {
    local src="$1" dst="$2"
    if [ -L "$src" ]; then
        printf "  SKIP    %s (already linked)\n" "${src/#$HOME/\~}"; skipped=$((skipped+1)); return
    fi
    take_backup
    mkdir -p "$dst"
    if [ -d "$src" ]; then
        local n; n=$(find "$src" -type f 2>/dev/null | wc -l)
        if [ "$n" -gt 0 ]; then
            rsync -a --ignore-existing "$src/" "$dst/" || { echo "  ERROR   rsync failed for $src"; return; }
            printf "  MERGED  %-52s <- %s files\n" "${dst/#$HOME/\~}" "$n"
            merged=$((merged+1))
        fi
        rm -rf "$src"
    fi
    mkdir -p "$(dirname "$src")"
    ln -s "$dst" "$src"
    printf "  LINKED  %-52s -> %s\n" "${src/#$HOME/\~}" "${dst/#$HOME/\~}"
    linked=$((linked+1))
}

# Pull anything sitting in EmuDeck's orphaned tree into the shared one first, so the
# emulator's own directory is merged on top of it rather than the other way round.
migrate_emudeck() {
    local sub="$1" dst="$2"
    [ -d "$EMUDECK/$sub" ] || return
    local n; n=$(find "$EMUDECK/$sub" -type f 2>/dev/null | wc -l)
    [ "$n" -gt 0 ] || return
    mkdir -p "$dst"
    rsync -a --ignore-existing "$EMUDECK/$sub/" "$dst/"
    printf "  MIGRATE %-52s <- %s files from EmuDeck tree\n" "${dst/#$HOME/\~}" "$n"
    merged=$((merged+1))
}

echo "=== 1. Ryujinx (Ryubing fork) ==="
R="$HOME/.var/app/io.github.ryubing.Ryujinx/config/Ryujinx/bis/user"
link_if flatpak:io.github.ryubing.Ryujinx "$R/save"     "$SAVES/ryujinx-ryubing/save"
link_if flatpak:io.github.ryubing.Ryujinx "$R/saveMeta" "$SAVES/ryujinx-ryubing/saveMeta"
# The save INDEX (slot -> title/user map, imkvdb.arc) lives under bis/system, not bis/user,
# so it was never synced -- a save migrated to another machine showed up as a new game because
# that machine's index didn't know the slot existed. Wire it too.
link_if flatpak:io.github.ryubing.Ryujinx \
    "$HOME/.var/app/io.github.ryubing.Ryujinx/config/Ryujinx/bis/system/save/8000000000000000" \
    "$SAVES/ryujinx-ryubing/index"

echo "=== 2. RetroArch ==="
migrate_emudeck "retroarch/saves"  "$SAVES/retroarch/saves"
migrate_emudeck "retroarch/states" "$SAVES/retroarch/states"
RA="$HOME/.var/app/org.libretro.RetroArch/config/retroarch"
link_if flatpak:org.libretro.RetroArch "$RA/saves"  "$SAVES/retroarch/saves"
link_if flatpak:org.libretro.RetroArch "$RA/states" "$SAVES/retroarch/states"

echo "=== 3. Dolphin ==="
migrate_emudeck "dolphin/GC"  "$SAVES/dolphin/GC"
migrate_emudeck "dolphin/Wii" "$SAVES/dolphin/Wii"
D="$HOME/.var/app/org.DolphinEmu.dolphin-emu/data/dolphin-emu"
link_if flatpak:org.DolphinEmu.dolphin-emu "$D/GC"         "$SAVES/dolphin/GC"
link_if flatpak:org.DolphinEmu.dolphin-emu "$D/Wii"        "$SAVES/dolphin/Wii"
link_if flatpak:org.DolphinEmu.dolphin-emu "$D/StateSaves" "$SAVES/dolphin/StateSaves"

echo "=== 4. Primehack ==="
migrate_emudeck "primehack/GC"  "$SAVES/primehack/GC"
migrate_emudeck "primehack/Wii" "$SAVES/primehack/Wii"
P="$HOME/.var/app/io.github.shiiion.primehack/data/dolphin-emu"
link_if flatpak:io.github.shiiion.primehack "$P/GC"         "$SAVES/primehack/GC"
link_if flatpak:io.github.shiiion.primehack "$P/Wii"        "$SAVES/primehack/Wii"
link_if flatpak:io.github.shiiion.primehack "$P/StateSaves" "$SAVES/primehack/StateSaves"

echo "=== 5. PPSSPP ==="
PP="$HOME/.var/app/org.ppsspp.PPSSPP/config/ppsspp/PSP"
link_if flatpak:org.ppsspp.PPSSPP "$PP/SAVEDATA"     "$SAVES/ppsspp/SAVEDATA"
link_if flatpak:org.ppsspp.PPSSPP "$PP/PPSSPP_STATE" "$SAVES/ppsspp/PPSSPP_STATE"

echo "=== 6. PCSX2 ==="
PC="$HOME/.var/app/net.pcsx2.PCSX2/config/PCSX2"
link_if flatpak:net.pcsx2.PCSX2 "$PC/memcards" "$SAVES/pcsx2/memcards"
link_if flatpak:net.pcsx2.PCSX2 "$PC/sstates"  "$SAVES/pcsx2/sstates"

echo "=== 7. xemu ==="
link_if flatpak:app.xemu.xemu "$HOME/.var/app/app.xemu.xemu/data/xemu/xemu" "$SAVES/xemu/data"

echo "=== 8. azahar (AppImage, not flatpak) ==="
migrate_emudeck "azahar/saves"  "$SAVES/azahar/sdmc"
migrate_emudeck "azahar/states" "$SAVES/azahar/states"
link_if appimage:azahar*.AppImage "$HOME/.local/share/azahar-emu/sdmc" "$SAVES/azahar/sdmc"
# Azahar is also on Flathub; the PC may use that instead of the AppImage. Different path,
# same sdmc format, so both can point at the same synced directory.
link_if flatpak:org.azahar_emu.Azahar "$HOME/.var/app/org.azahar_emu.Azahar/data/azahar-emu/sdmc" "$SAVES/azahar/sdmc"

echo "=== 9. DuckStation (AppImage, not flatpak) ==="
DS="$HOME/.local/share/duckstation"
link_if appimage:DuckStation*.AppImage "$DS/memcards"   "$SAVES/duckstation/memcards"
link_if appimage:DuckStation*.AppImage "$DS/savestates" "$SAVES/duckstation/savestates"

echo "=== 10. emulators configured by EmuDeck to write into ~/Emulation/saves ==="
# melonDS and ScummVM have explicit save paths pointing at ~/Emulation/saves/<emu>, which
# resolves to the SD card and is synced by nothing. Rather than editing each emulator's
# config (which EmuDeck or an update could rewrite), redirect the directory itself into the
# synced tree. Their configs keep working untouched.
redirect_emudeck_dir() {
    local sub="$1" dst="$2"
    local src="$EMUDECK/$sub"
    if [ -L "$src" ]; then
        printf "  SKIP    %s (already a link)\n" "${src/#$HOME/\~}"; skipped=$((skipped+1)); return
    fi
    take_backup
    mkdir -p "$dst"
    if [ -d "$src" ]; then
        local n; n=$(find "$src" -type f 2>/dev/null | wc -l)
        if [ "$n" -gt 0 ]; then
            rsync -a --ignore-existing "$src/" "$dst/" || { echo "  ERROR   rsync failed for $src"; return; }
            printf "  MERGED  %-52s <- %s files\n" "${dst/#$HOME/\~}" "$n"
            merged=$((merged+1))
        fi
        rm -rf "$src"
    fi
    mkdir -p "$(dirname "$src")"
    ln -s "$dst" "$src"
    printf "  LINKED  %-52s -> %s\n" "${src/#$HOME/\~}" "${dst/#$HOME/\~}"
    linked=$((linked+1))
}
redirect_emudeck_dir "melonds" "$SAVES/melonds"
redirect_emudeck_dir "scummvm" "$SAVES/scummvm"

echo "=== 11. Flycast (VMU saves live in its own data dir, not next to the ROM) ==="
link_if flatpak:org.flycast.Flycast "$HOME/.var/app/org.flycast.Flycast/data/flycast" "$SAVES/flycast"

echo "=== 11.5. Citron (AppImage, Switch emulator) ==="
link_if appimage:citron*.AppImage "$HOME/.local/share/citron/nand/user/save" "$SAVES/citron/save"

echo "=== 12. mGBA / RPCS3 - proactive wiring (works before first launch) ==="
# Both write configs whose paths only exist after you launch them once, which is too late --
# whichever machine gets there first would define where saves live. Instead, pre-create the
# config file/directory and set its save path now, so the very first launch on ANY machine
# already writes into the synced pool.

wire_mgba_ini() {
    local qtini="$1"
    mkdir -p "$SAVES/mgba/saves" "$SAVES/mgba/states" "$(dirname "$qtini")"
    python3 - "$qtini" "$SAVES/mgba/saves" "$SAVES/mgba/states" <<'PYEOF'
import sys, re, os
p, saves, states = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p).read() if os.path.exists(p) else "[General]\n"
if "[General]" not in s:
    s = "[General]\n" + s
def setkey(s, k, v):
    if re.search(r'(?m)^%s=' % re.escape(k), s):
        return re.sub(r'(?m)^%s=.*$' % re.escape(k), "%s=%s" % (k, v), s)
    return re.sub(r'(?m)^(\[General\]\n)', r'\1%s=%s\n' % (k, v), s, count=1)
s = setkey(s, "savegamePath", saves)
s = setkey(s, "savestatePath", states)
open(p, "w").write(s)
PYEOF
    printf "  WIRED   %-52s savegamePath/savestatePath\n" "${qtini/#$HOME/\~}"
}
if have flatpak:io.mgba.mGBA; then
    wire_mgba_ini "$HOME/.var/app/io.mgba.mGBA/config/mgba/qt.ini"
    flatpak override --user --filesystem="$SAVES" io.mgba.mGBA >/dev/null 2>&1
fi
if have appimage:mGBA*.AppImage || [ -d "$HOME/.config/mgba" ]; then
    wire_mgba_ini "$HOME/.config/mgba/qt.ini"
fi

wire_rpcs3_dir() {
    local base="$1"
    local d="$base/dev_hdd0/home/00000001"
    mkdir -p "$SAVES/rpcs3/savedata" "$d"
    if [ -L "$d/savedata" ]; then
        printf "  SKIP    %-52s (already a link)\n" "${d/#$HOME/\~}/savedata"
    else
        if [ -d "$d/savedata" ]; then
            rsync -a --ignore-existing "$d/savedata/" "$SAVES/rpcs3/savedata/" 2>/dev/null
            rm -rf "$d/savedata"
        fi
        ln -s "$SAVES/rpcs3/savedata" "$d/savedata"
        printf "  LINKED  %-52s -> %s\n" "${d/#$HOME/\~}/savedata" "${SAVES/#$HOME/\~}/rpcs3/savedata"
    fi
}
if have flatpak:net.rpcs3.RPCS3; then
    wire_rpcs3_dir "$HOME/.var/app/net.rpcs3.RPCS3/config/rpcs3"
    flatpak override --user --filesystem="$SAVES" net.rpcs3.RPCS3 >/dev/null 2>&1
fi
if have appimage:rpcs3*.AppImage || [ -d "$HOME/.config/rpcs3" ]; then
    wire_rpcs3_dir "$HOME/.config/rpcs3"
fi

echo
echo "=== 12b. prune links for emulators that are not installed here ==="
# An earlier version of this script linked unconditionally, leaving symlinks on machines
# that never had the emulator. Remove those, but ONLY when the destination holds no files,
# so a link is never pruned out from under real saves.
prune_if_absent() {
    local spec="$1" src="$2" dst="$3"
    have "$spec" && return
    [ -L "$src" ] || return
    if [ -n "$(find -L "$dst" -type f 2>/dev/null | head -1)" ]; then
        printf "  KEEP    %-52s (emulator absent but %s has saves)\n" "${src/#$HOME/\~}" "${dst/#$HOME/\~}"
        return
    fi
    rm -f "$src"
    printf "  PRUNED  %-52s (%s not installed, no saves)\n" "${src/#$HOME/\~}" "${spec#*:}"
}
prune_if_absent appimage:azahar*.AppImage      "$HOME/.local/share/azahar-emu/sdmc"   "$SAVES/azahar/sdmc"
prune_if_absent appimage:DuckStation*.AppImage "$HOME/.local/share/duckstation/memcards"   "$SAVES/duckstation/memcards"
prune_if_absent appimage:DuckStation*.AppImage "$HOME/.local/share/duckstation/savestates" "$SAVES/duckstation/savestates"
prune_if_absent flatpak:org.flycast.Flycast    "$HOME/.var/app/org.flycast.Flycast/data/flycast" "$SAVES/flycast"

echo
echo "=== 13. flatpak sandbox permissions ==="
# Emulators ship with home:ro. A symlink into ~/emulator-saves needs explicit rw access,
# otherwise the emulator silently fails to write saves.
for app in io.github.ryubing.Ryujinx org.libretro.RetroArch org.DolphinEmu.dolphin-emu \
           io.github.shiiion.primehack org.ppsspp.PPSSPP net.pcsx2.PCSX2 app.xemu.xemu \
           net.kuribo64.melonDS org.scummvm.ScummVM org.flycast.Flycast io.mgba.mGBA net.rpcs3.RPCS3; do
    if flatpak info "$app" >/dev/null 2>&1; then
        flatpak override --user --filesystem="$SAVES" "$app" && printf "  PERMS   %s\n" "$app"
    fi
done

cat <<SUMMARY

=== summary ===
  linked: $linked   merged: $merged   skipped(already linked): $skipped
  backup: $BACKUP

melonDS and ScummVM are handled by redirecting ~/Emulation/saves/<emu> rather than editing
their configs, so an EmuDeck rewrite or app update cannot undo it.
mGBA and RPCS3 are wired proactively (config/qt.ini written before first launch), so a
fresh machine already saves into the pool on its very first play.
Dead emulators (yuzu, citra, org.ryujinx) are no longer linked; their existing saves
remain in ~/emulator-saves and are still synced.
ES-DE gamelists (~/Emulation/saves/es-de) are scraper metadata, not saves -- left alone.
SUMMARY
