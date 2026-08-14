#!/bin/bash
# Record the firmware-dependent state that the OS CAN see, so a BIOS reset is caught
# immediately instead of being discovered when a VM refuses to start.
#
# WHY: on 2026-08-12 nasir's BIOS reverted to defaults (clear-CMOS button knocked while
# moving it). VT-d went off, /sys/kernel/iommu_groups emptied, and both passthrough VMs
# failed with "cannot prepare PCI pass-through, IOMMU not present". Nothing flagged it --
# it surfaced only when the NAS did not come back. The kernel cmdline still said
# intel_iommu=on, so config-level checks looked fine; only the FIRMWARE had changed.
#
#   bash checkBiosState.sh            # print current state
#   bash checkBiosState.sh --save     # write the baseline to ~/biosBaseline.txt
#   bash checkBiosState.sh --diff     # compare current state against that baseline
#
# Each physical host's backupToStore script runs --save before it copies ~ into Store, so the
# baseline is captured fresh every monthly maintenance run and lands in that host's Store dir.
set -uo pipefail

HOST=$(hostname -s)
# Write to $HOME (so /root on the proxmox hosts), NOT next to the script. The script lives in
# the git clone, which restoreFromStore replaces wholesale -- a baseline written there would be
# clobbered, and would also be committed from whichever host happened to run it last. In $HOME
# it is per-host by construction, and each host's backupToStore copies its own into Store.
BASE="${BIOS_BASELINE:-$HOME/biosBaseline.txt}"

collect() {
    echo "host: $HOST"
    echo "board: $(sudo -n dmidecode -s baseboard-manufacturer 2>/dev/null) $(sudo -n dmidecode -s baseboard-product-name 2>/dev/null)"
    echo "bios: $(sudo -n dmidecode -s bios-version 2>/dev/null) $(sudo -n dmidecode -s bios-release-date 2>/dev/null)"

    # The headline check. Non-zero means VT-d/AMD-Vi is genuinely active in firmware.
    # The kernel cmdline flag is NOT evidence: it stays put across a BIOS reset.
    echo "iommu_groups: $(ls /sys/kernel/iommu_groups 2>/dev/null | wc -l)"
    echo "iommu_class_entries: $(ls /sys/class/iommu 2>/dev/null | wc -l)"

    # Present only when the firmware actually publishes the DMAR/IVRS ACPI table.
    echo "dmar_acpi_table: $(dmesg 2>/dev/null | grep -cE 'DMAR: (DRHD|Host address width)|Virtualization Technology for Directed|AMD-Vi: Found IOMMU')"

    echo "cpu_virt_flag: $(grep -com1 -E 'vmx|svm' /proc/cpuinfo)"
    echo "kernel_iommu_args: $(grep -oE '(intel|amd)_iommu=[a-z]+|iommu=[a-z]+' /proc/cmdline | sort | tr '\n' ' ')"
    echo "boot_mode: $([ -d /sys/firmware/efi ] && echo UEFI || echo BIOS/CSM)"
    echo "secure_boot: $(mokutil --sb-state 2>/dev/null | head -1 || echo unknown)"
    echo "vfio_modules: $(lsmod | grep -c '^vfio')"
    echo "hostpci_vms: $(grep -l hostpci /etc/pve/qemu-server/*.conf 2>/dev/null | wc -l)"
    echo "total_ram_gb: $(awk '/MemTotal/{printf "%.0f", $2/1024/1024}' /proc/meminfo)"
    echo "cpu_cores: $(nproc)"
}

case "${1:-}" in
  --save)
    collect > "$BASE"
    echo "baseline written: $BASE"
    cat "$BASE"
    ;;
  --diff)
    [ -f "$BASE" ] || { echo "no baseline at $BASE -- run --save first" >&2; exit 1; }
    if diff -u "$BASE" <(collect) > /tmp/biosdiff.$$ 2>&1; then
        echo "OK: firmware-visible state matches the baseline"
        rm -f /tmp/biosdiff.$$
    else
        echo "!! CHANGED since baseline:"
        cat /tmp/biosdiff.$$; rm -f /tmp/biosdiff.$$
        exit 1
    fi
    ;;
  *) collect ;;
esac
