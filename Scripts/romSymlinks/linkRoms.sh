#!/usr/bin/env bash
# Point ES-DE's system directories at the existing ROM library instead of
# copying it. ~/Emulation/roms/<es-de name> becomes a symlink to the matching
# folder under the Store archive, so nothing is duplicated and Windows keeps
# seeing the same files.
#
# Dry run by default. Pass --go to actually create the links.
set -uo pipefail

SRC="$HOME/Desktop/Store/Games/Consoles/1. ROMS"
DST="$HOME/Emulation/roms"
GO=false
[ "${1:-}" = "--go" ] && GO=true

# es-de system name : Store folder name
MAP="
snes:SNES
nes:NES
gb:GB
gbc:GBC
gba:GBA
nds:NDS
n3ds:3DS
switch:NINTENDO SWITCH
gc:GAMECUBE
n64:N64
wii:NINTENDO WII
wiiu:NINTENDO WII U
psx:PS1
ps2:PS2
ps3:PS3
psp:PSP
psvita:PS VITA
dreamcast:SEGA DREAMCAST
gamegear:SEGA GAME GEAR
saturn:SEGA SATURN
xbox:XBOX
xbox360:XBOX 360
ps4:PS4
"

[ -d "$SRC" ] || { echo "source library not found: $SRC" >&2; exit 1; }
$GO || echo "DRY RUN - nothing will change. Re-run with --go to apply."
echo

printf "%-10s %-22s %s\n" SYSTEM FILES ACTION
while IFS=: read -r es store; do
    [ -z "$es" ] && continue
    src="$SRC/$store"
    dst="$DST/$es"

    # Link empty systems too, so anything downloaded into Store later shows up
    # in ES-DE without further setup. Create the Store folder if it's missing.
    if [ ! -d "$src" ]; then
        if $GO; then mkdir -p "$src" && created=" (created in Store)"; else created=" (would create in Store)"; fi
    else
        created=""
    fi
    n=$(find "$src" -maxdepth 1 -type f 2>/dev/null | wc -l)

    if [ -L "$dst" ]; then
        cur=$(readlink "$dst")
        [ "$cur" = "$src" ] && act="ok (already linked)" || act="EXISTS as link -> $cur (leaving alone)"
    elif [ -d "$dst" ]; then
        # EmuDeck seeds every system dir with metadata.txt / systeminfo.txt;
        # those are regenerated stubs, not your games, so they don't count.
        have=$(find "$dst" -maxdepth 1 -type f \
                 ! -name metadata.txt ! -name systeminfo.txt 2>/dev/null | wc -l)
        if [ "$have" -gt 0 ]; then
            act="SKIP - real dir with $have files, would not clobber"
        else
            stubs=$(find "$dst" -maxdepth 1 -type f 2>/dev/null | wc -l)
            act="link (replacing dir, discarding $stubs EmuDeck stub(s))"
            $GO && {
                rm -f "$dst/metadata.txt" "$dst/systeminfo.txt"
                rmdir "$dst" 2>/dev/null && ln -s "$src" "$dst" && act="linked"
            }
        fi
    else
        act="link (new)"
        $GO && { mkdir -p "$DST" && ln -s "$src" "$dst" && act="linked"; }
    fi
    printf "%-10s %-22s %s\n" "$es" "$n" "$act$created"
done <<< "$MAP"

echo
$GO && echo "done. ES-DE will pick these up on next start." \
     || echo "re-run with --go to apply."
