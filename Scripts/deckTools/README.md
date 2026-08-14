# Steam Deck (steamy) — how it is set up and why

Written 2026-08-11 while fixing the "I have to reinstall everything constantly" problem.
Two separate root causes, both now fixed.

---

## 1. Why pacman packages kept vanishing (and why `fixKeys` was needed)

SteamOS uses an **immutable, A/B-partitioned rootfs**:

```
/dev/nvme0n1p4   5G  btrfs  /      <- one slot
/dev/nvme0n1p5   5G  btrfs         <- the other
/dev/nvme0n1p8 466G  ext4   /home  <- never touched by updates
```

A SteamOS update does not patch the running system. It writes a **whole new image** to the
inactive slot and boots into it. So:

- everything `pacman -S` put in `/usr` is gone
- `/etc/pacman.d/gnupg` reverts, which is why the keyring needed re-initialising every time

Nothing done inside pacman can survive this. It is not a misconfiguration.

### The fix: `installDeckTools.sh`

CLI tools now install into `~/.local/bin`, which is on `/home` and therefore permanent.
They are **static musl builds**, so they also do not care if SteamOS ships a different
glibc after an update.

```bash
deckTools          # alias for: bash ~/Scripts/deckTools/installDeckTools.sh
```

Re-runnable and idempotent — run it again to upgrade everything.

Installed: `eza` (+ `exa` symlink), `fd`, `rg`, `jq`, `btop`, `nvim`, `fzf`, `bat`,
`delta`, `zoxide`, `tree`, `ncdu`, `syncthing`. About 47 MB total.

`tree` and `ncdu` have no upstream static build, so they are lifted out of the official
Arch package via `archlinux.org/packages/<repo>/x86_64/<pkg>/download/`, which 302s to a
mirror holding the current version — no version string to guess.

### Alias changes

| Alias | What it does now |
|---|---|
| `update` | flatpak user + system, then `deckTools`. **No pacman.** |
| `deckTools` | reinstall/upgrade the persistent CLI tools |
| `updatePacman` | the old behaviour, if you genuinely need an Arch package |
| `fixKeys` | unchanged, but only needed before `updatePacman` |

`update` splits flatpak into `--user` then `sudo ... --system` on purpose. Running
`flatpak update` as your user against a **system** install over SSH has no polkit agent to
authorise it, which produced:

```
Failed to get revokefs-fuse socket from system-helper:
Flatpak system operation GetRevokefsFd not allowed for user
```

Doing the system half under sudo avoids it entirely.

---

## 2. Why the emulators kept needing reinstallation

**`restoreDeck.sh` was deleting them.** It contained:

```bash
sudo rm -rf ~/Store/ ~/Scripts/ ~/vsCodeConfigStore ~/.config ~/.vim/ ~/.git
```

`~/.config/EmuDeck` holds the entire EmuDeck backend — every emulator launcher sources
`~/.config/EmuDeck/backend/functions/all.sh`. And `backupDeck.sh` never captured `.config`
(it saves only `.ssh`, two package lists and `.bashrc`), while the repo's `.gitignore`
ignores `.config/*`.

So every monthly maintenance run destroyed the emulator setup and nothing put it back.
It was deleting **everything** in `.config` to restore the grand total of **3 tracked
files** (`htoprc`, `neofetch/config.conf`, `nvim/init.vim`). Syncthing's identity and
folder list died the same way.

### The fix

`restoreDeck.sh` (and the three proxmox restore scripts, which had the same line) no
longer delete `~/.config`. They use `rsync -a ~/yasir/ ~/` instead of `cp -r ~/yasir/.* ~`.

The `cp` is why the delete seemed necessary: **`cp -r` into an existing directory nests it**
(`~/.config/.config`) rather than merging. rsync merges correctly and deletes nothing.

---

## 3. Emulation layout

There were **two complete EmuDeck installs**:

| Tree | Installed | ROMs | Status |
|---|---|---|---|
| `/run/media/deck/SN512/Emulation` | May 2025 | **149 GB** | the real one |
| `/home/deck/Emulation` | Jul 2026 | 22 MB of empty dirs | a re-install that orphaned the above |

ES-DE pointed `ROMDirectory` at the **internal, empty** one while the Steam shortcut
launched the **SD** one. That is why nothing appeared.

Now `~/Emulation` is a **symlink** to the SD tree, so every path in every config resolves
to the real data without editing any of them. The old internal tree is archived at
`~/Emulation.internal-archived-<date>` (306 MB, delete when happy).

### Launchers

All 22 launchers under `Emulation/tools/launchers/` were rebuilt to be **self-contained**.
They no longer source the EmuDeck backend — each just runs its emulator, preferring an
AppImage in `~/Applications` and falling back to the flatpak. The originals are backed up
next to them as `launchers.backup-<date>`.

`model-2-emulator.sh` and `xenia.sh` are wine-based and were left alone.

### ES-DE fixes

- **n3ds** default launcher was `%CORE_RETROARCH%\citra_libretro.dll` — a Windows path,
  which cannot work on Linux. Azahar is now the default, and the RetroArch entries were
  corrected to `.so`.
- **Ryujinx find-rule added.** ES-DE's built-in rule looks for `org.ryujinx.Ryujinx`, the
  discontinued upstream. The maintained fork is `io.github.ryubing.Ryujinx`, a different
  flatpak id, so ES-DE found no Switch emulator at all — with 82 GB of Switch ROMs present.

---

## 4. Syncthing

Was installed as a flatpak (SyncThingy) but had **no configuration at all** — it died with
`~/.config`.

Now: the `syncthing` binary lives in `~/.local/bin` and runs as a **systemd user service**
with linger enabled, so it starts at boot without anyone logging in.

**Config lives in `~/.local/state/syncthing`, deliberately NOT `~/.config`**, so a restore
script can never wipe the device identity again.

```
Device ID: <SYNCTHING_DEVICE_ID>
```

Folders configured (all with simple versioning, keeping 5 old copies):

| ID | Path |
|---|---|
| `emu-saves` | `/run/media/deck/SN512/Emulation/saves` |
| `emu-storage` | `/run/media/deck/SN512/Emulation/storage` |
| `esde-gamelists` | `~/ES-DE/gamelists` |

GUI listens on `127.0.0.1:8384` only. To reach it:
`ssh -L 8384:127.0.0.1:8384 deck@steamy` then open `http://localhost:8384`.

> ⚠ **Do not launch the SyncThingy flatpak.** It bundles its own syncthing with its own
> config, so it would fight the service for ports 8384/22000. Uninstall it or leave it be.

There is **no Syncthing anywhere else on the fleet yet**, so nothing is actually syncing —
the Deck side is ready and waiting for a peer. An always-on peer (docker0 or the NAS) is a
better target than a PC that is usually off.

---

## Commands

```bash
deckTools                                  # refresh persistent CLI tools
update                                     # flatpak (user+system) + deckTools
systemctl --user status syncthing          # sync service
journalctl --user -u syncthing -f          # sync logs
bash ~/Scripts/deckTools/installDeckTools.sh --list
```
