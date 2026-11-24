#!/bin/bash
# One-time Waydroid setup for a Pop!_OS machine (spectre / poppy). Run with sudo.
# Installs Waydroid + Weston, applies the three fixes this fleet needs, adds the
# startWaydroid alias and copies the updated .bashrc into Store. Safe to re-run.
set -uo pipefail

[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }
USER_NAME="${SUDO_USER:-yasir}"
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
[ -d "$USER_HOME" ] || { echo "no home for $USER_NAME" >&2; exit 1; }
HOST=$(cat /etc/hostname)
note() { printf '  %s\n' "$*"; }
asuser() { sudo -u "$USER_NAME" "$@"; }

case "$HOST" in
    poppy)       STORE="$USER_HOME/Store/2025_backup/pc/pop" ;;
    spectre-pop) STORE="$USER_HOME/Store/2025_backup/laptop/pop" ;;
    *) echo "unknown host $HOST; add it to the STORE case" >&2; exit 1 ;;
esac

echo "=== preflight ==="
[ "$(uname -m)" = x86_64 ] || { echo "x86_64 only" >&2; exit 1; }
# Pop's 7.x kernels ship binder as the Rust driver; /dev/binderfs appears only once Waydroid mounts it
grep -q "CONFIG_ANDROID_BINDER_IPC_RUST=y" "/boot/config-$(uname -r)" \
    && note "binder: built into $(uname -r)" \
    || { echo "no binder support in this kernel" >&2; exit 1; }

echo
echo "=== packages ==="
# re-running the vendor script is how the signing key gets (re)installed, the .list alone is not enough
curl -s https://repo.waydro.id | bash >/dev/null && note "waydroid apt repo + key installed"
DEBIAN_FRONTEND=noninteractive apt-get install -y waydroid weston >/dev/null \
    && note "waydroid $(dpkg-query -Wf '${Version}' waydroid), weston $(dpkg-query -Wf '${Version}' weston)"

echo
echo "=== android image ==="
# vanilla LineageOS on purpose: F-Droid -> Aurora Store covers Play apps without Google
if [ -f /var/lib/waydroid/images/system.img ]; then
    note "image already present, leaving it alone"
else
    waydroid init && note "vanilla LineageOS image downloaded"
fi

echo
echo "=== fix: waydroid-net must use nftables ==="
# it hardcodes LXC_USE_NFT=false and prefers iptables-legacy, whose tables are empty when ufw runs on nft
NET=/usr/lib/waydroid/data/scripts/waydroid-net.sh
if grep -q '^LXC_USE_NFT="false"' "$NET"; then
    sed -i 's/^LXC_USE_NFT="false"/LXC_USE_NFT="true"/' "$NET" && note "LXC_USE_NFT -> true"
else
    note "already set ($(grep -m1 '^LXC_USE_NFT' "$NET"))"
fi

echo
echo "=== fix: nft modules blocked by the Pop BTF bug ==="
# masquerade needs nft_masq; on affected kernels modprobe fails with "Invalid argument" + BTF: -22
if modprobe -q -a nft_masq nft_nat nft_ct 2>/dev/null; then
    note "nft modules load fine, no BTF fix needed"
else
    if [ ! -x /usr/local/sbin/strip-btf-modules ]; then
        INST="$USER_HOME/Scripts/Z.Esoteric_Tools/stripBTF/installStripBTF.sh"
        [ -x "$INST" ] || { echo "missing $INST (pull the home repo first)" >&2; exit 1; }
        "$INST" >/dev/null && note "installed the strip-btf worker + kernel hook"
    fi
    /usr/local/sbin/strip-btf-modules
    modprobe -a nft_masq nft_nat nft_ct && note "nft modules load after stripping BTF" \
        || { echo "nft modules still refuse to load" >&2; exit 1; }
fi

echo
echo "=== fix: ufw must pass Android's DHCP, DNS and forwarded traffic ==="
# scoped to waydroid0 only, the rest of the firewall is untouched
if ufw status 2>/dev/null | grep -q "^Status: active"; then
    ufw allow in on waydroid0 to any port 67 proto udp >/dev/null
    ufw allow in on waydroid0 to any port 53 >/dev/null
    ufw route allow in on waydroid0 >/dev/null
    ufw route allow out on waydroid0 >/dev/null
    note "4 waydroid0 rules present"
else
    note "ufw inactive, skipped"
fi

echo
echo "=== container service ==="
systemctl restart waydroid-container
# started on demand by startWaydroid instead, so it is not running when Android is not in use
systemctl disable waydroid-container >/dev/null 2>&1
note "running now, disabled at boot"

echo
echo "=== startWaydroid alias ==="
BASHRC="$USER_HOME/.bashrc"
LAUNCHER="$USER_HOME/Scripts/startWaydroid/startWaydroid.sh"
[ -f "$LAUNCHER" ] || note "WARNING: $LAUNCHER is missing, pull the home repo"
chmod +x "$LAUNCHER" 2>/dev/null
if grep -q "alias startWaydroid=" "$BASHRC"; then
    note "alias already in .bashrc"
else
    BLOCK="\n# Android in a nested Weston window (Waydroid needs Wayland, this desktop is X11)\nalias startWaydroid='~/Scripts/startWaydroid/startWaydroid.sh'"
    # keep it next to fixBTF where both machines have it, else fall back to the end of the file
    if grep -q "^alias fixBTF=" "$BASHRC"; then
        asuser sed -i "/^alias fixBTF=/a\\${BLOCK}" "$BASHRC"
    else
        asuser bash -c "printf '%b\n' \"${BLOCK}\" >> '$BASHRC'"
    fi
    note "alias added at line $(grep -n 'alias startWaydroid=' "$BASHRC" | cut -d: -f1)"
fi

echo
echo "=== back up .bashrc into Store ==="
if [ -d "$STORE" ]; then
    asuser cp "$BASHRC" "$STORE/.bashrc" && note "copied to ${STORE#$USER_HOME/}/.bashrc"
else
    note "WARNING: $STORE missing, skipped"
fi

echo
echo "done. Open a new terminal (or source ~/.bashrc), then run: startWaydroid"
echo "Commit the Store/.bashrc change from this machine."
