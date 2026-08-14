# linkRoms.sh

Points `~/Emulation/roms/<system>` at the matching folder in the Store archive
(`~/Desktop/Store/Games/Consoles/1. ROMS/<NAME>`) using symlinks, so ES-DE reads the
existing library instead of a second copy of it.

Dry run by default; pass `--go` to apply. Creates the Store folder if missing, so a system
you don't own yet still shows up in ES-DE once you drop ROMs into Store.

Refuses to replace any system directory that already holds real files. EmuDeck's
`metadata.txt` / `systeminfo.txt` / `readme.txt` stubs don't count as real files.

Four systems stay as real directories because emulators keep their own data inside them:
`xbox360` (Xenia + `content/` saves), `wiiu` (Cemu `mlc01`), `psvita` (Vita3K
`InstalledGames`), `ps4` (ShadPS4 `shortcuts`). For xbox360 and wiiu, link the inner
`roms/` subdirectory instead — see the notes in the emulation-consolidation memory.

Not applicable to the Steam Deck, whose ROM library lives on the SD card rather than in
the Store archive.

Companion script: `../emulatorSaves/setup-symlinks.sh` (save directories).
