# emulator-saves-symlinks timer

Runs `~/emulator-saves/setup-symlinks.sh --quiet` at boot+2min and hourly, so the save
symlinks self-heal. Needed because running EmuDeck replaces them with real directories,
after which saves silently stop syncing with no error to notice.

These unit files are NOT in the Syncthing-shared folder (that only carries the script), so
each machine needs them installed by hand:

    mkdir -p ~/.config/systemd/user
    cp emulator-saves-symlinks.{service,timer} ~/.config/systemd/user/
    systemctl --user daemon-reload
    systemctl --user enable --now emulator-saves-symlinks.timer
    systemctl --user list-timers emulator-saves-symlinks.timer

Installed on: steamy, spectre-pop (2026-08-13). Not yet verified on poppy.
