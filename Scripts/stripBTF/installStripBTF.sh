#!/bin/bash
# Self-maintaining workaround for Pop!_OS kernels that ship modules with invalid
# BTF. Run with sudo (alias: fixBTF). Idempotent, safe to re-run.
#
# SYMPTOM
#   sudo modprobe xpad
#     modprobe: ERROR: could not insert 'xpad': Invalid argument
#   dmesg:
#     BPF: Invalid name
#     failed to validate module [xpad] BTF: -22
#
# CAUSE
#   The kernel validates each module's BTF (type metadata used by BPF). Pop's
#   7.0.11-76070011-generic ships modules whose BTF is malformed, so the kernel
#   refuses to load them at all. It is a packaging bug, unrelated to the hardware.
#   The USB device still enumerates (lsusb shows it) but no driver binds, so no
#   /dev/input/js* appears and SDL apps -- yuzu, Ryujinx, anything not Steam --
#   see no gamepad. Steam still works because it talks over hidraw and does not
#   need the kernel driver. Confirmed affected: xpad, cdc_acm, tls.
#
# FIX
#   BTF is only used for BPF introspection; the driver does not need it. Strip
#   that section and install the result into /lib/modules/<ver>/updates/, which
#   takes precedence over the packaged module, then depmod so udev auto-loads it.
#
# WHY THIS INSTALLER RATHER THAN A ONE-SHOT SCRIPT
#   A new kernel gets a new (still broken) module and its own modules tree, so a
#   manual fix does not carry over. This installs three pieces so it never needs
#   re-running: a worker, a kernel-install hook, and a boot-time service. See the
#   summary printed at the end.
set -euo pipefail

[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

for t in objcopy depmod journalctl; do
    command -v "$t" >/dev/null || { echo "missing required tool: $t" >&2; exit 1; }
done

# ---------------------------------------------------------------- main script
install -d /usr/local/sbin
cat >/usr/local/sbin/strip-btf-modules <<'SCRIPT'
#!/bin/bash
# Strip the invalid .BTF section from kernel modules that fail BTF validation,
# writing the fixed copy into /lib/modules/<ver>/updates (which outranks the
# in-tree module). Offenders are discovered from the kernel log and remembered
# in /etc/strip-btf-modules.list so later kernels get fixed pre-emptively.
#
# Usage: strip-btf-modules [KERNEL_VERSION]   (defaults to the running kernel)

LIST=/etc/strip-btf-modules.list
KVER="${1:-$(uname -r)}"
MODDIR="/lib/modules/$KVER"

[ -d "$MODDIR/kernel" ] || exit 0

# names the kernel has actually complained about, union with what we remember
discover() {
    journalctl -k --no-pager 2>/dev/null |
        sed -n 's/.*failed to validate module \[\([^]]*\)\].*BTF.*/\1/p'
    [ -f "$LIST" ] && sed 's/#.*//' "$LIST"
}

mods=$(discover | tr -d '[:blank:]' | grep -v '^$' | sort -u)
[ -n "$mods" ] || exit 0

# module names in the log use underscores; filenames may use either
find_module() {
    local n=$1 alt1 alt2 f
    alt1=${n//_/-}
    alt2=${n//-/_}
    for f in "$n" "$alt1" "$alt2"; do
        find "$MODDIR/kernel" \( -name "$f.ko" -o -name "$f.ko.zst" -o -name "$f.ko.xz" \) \
            -print -quit 2>/dev/null | grep . && return 0
    done
    return 1
}

changed=0
fixed=()
for m in $mods; do
    src=$(find_module "$m") || continue

    tmp=$(mktemp)
    case "$src" in
        *.zst) zstd -dcq  "$src" >"$tmp" 2>/dev/null ;;
        *.xz)  xz -dc     "$src" >"$tmp" 2>/dev/null ;;
        *)     cat        "$src" >"$tmp" ;;
    esac
    [ -s "$tmp" ] || { rm -f "$tmp"; echo "strip-btf: could not decompress $src" >&2; continue; }

    # nothing to do if this kernel's copy is already clean
    if ! readelf -S "$tmp" 2>/dev/null | grep -q '\.BTF'; then
        rm -f "$tmp"
        fixed+=("$m")
        continue
    fi

    mkdir -p "$MODDIR/updates"
    if objcopy --remove-section=.BTF "$tmp" "$MODDIR/updates/$(basename "${src%%.ko*}").ko"; then
        echo "strip-btf: $m -> $MODDIR/updates/"
        fixed+=("$m")
        changed=1
    else
        echo "strip-btf: FAILED on $m" >&2
    fi
    rm -f "$tmp"
done

# remember offenders so the next kernel is fixed before it ever fails
if [ ${#fixed[@]} -gt 0 ]; then
    { echo "# modules with broken .BTF on Pop!_OS kernels; auto-maintained"
      printf '%s\n' "${fixed[@]}"; } | sort -u -k1 >"$LIST.tmp"
    mv "$LIST.tmp" "$LIST"
fi

[ "$changed" -eq 1 ] && depmod -a "$KVER"

# if we fixed the running kernel, load anything that is not up yet
if [ "$KVER" = "$(uname -r)" ]; then
    for m in "${fixed[@]}"; do
        lsmod | grep -q "^${m//-/_} " || modprobe "$m" 2>/dev/null || true
    done
fi
exit 0
SCRIPT
chmod 755 /usr/local/sbin/strip-btf-modules

# ------------------------------------------------- run on every kernel install
cat >/etc/kernel/postinst.d/zz-strip-btf <<'HOOK'
#!/bin/sh
exec /usr/local/sbin/strip-btf-modules "$1"
HOOK
chmod 755 /etc/kernel/postinst.d/zz-strip-btf

# --------------------------------------- catch newly-surfaced offenders at boot
cat >/etc/systemd/system/strip-btf-modules.service <<'UNIT'
[Unit]
Description=Strip invalid .BTF from kernel modules that fail to load
After=systemd-modules-load.service
Wants=systemd-modules-load.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/strip-btf-modules
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now strip-btf-modules.service >/dev/null

echo
echo "installed:"
echo "  /usr/local/sbin/strip-btf-modules       (the worker)"
echo "  /etc/kernel/postinst.d/zz-strip-btf     (runs on every kernel install)"
echo "  /etc/systemd/system/strip-btf-modules.service  (runs at every boot)"
echo "  /etc/strip-btf-modules.list             (remembered offenders)"
echo
echo "current offenders:"
sed 's/^/  /' /etc/strip-btf-modules.list 2>/dev/null || echo "  (none seen on this machine yet)"
