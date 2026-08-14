# BIOS / firmware settings per server

Written 2026-08-12 after nasir's BIOS reverted to defaults and took both PCI-passthrough VMs
down with it.

## What happened, so the symptom is recognisable next time

nasir came up with motherboard LEDs on but no OS. Once booted, both passthrough VMs failed:

```
Starting VM 100 failed: cannot prepare PCI pass-through, IOMMU not present
Starting VM 101 failed: cannot prepare PCI pass-through, IOMMU not present
```

Cause: **VT-d was off in firmware.** Most likely the clear-CMOS button was knocked while the
machine was being moved.

The trap is that **every OS-side check still looked correct**. `/proc/cmdline` still had
`intel_iommu=on iommu=pt`, and dmesg still printed `DMAR: IOMMU enabled` — that line only means
the kernel parsed your flag, not that the hardware is there. The real evidence:

| Check | Working | Broken |
|---|---|---|
| `ls /sys/kernel/iommu_groups \| wc -l` | non-zero | **0** |
| `ls /sys/class/iommu \| wc -l` | non-zero | **0** |
| dmesg `DMAR: Host address width` / `DRHD base` | present | **absent** |
| dmesg `Intel(R) Virtualization Technology for Directed I/O` | present | **absent** |

Boot-by-boot comparison is what proved it, since kernel and cmdline were unchanged:

```
boot -4  Aug 10 09:24   DMAR-table lines: 4
boot -3  Aug 11 07:29   DMAR-table lines: 4
boot -2  Aug 11 08:56   DMAR-table lines: 4
boot -1  Aug 11 09:22   DMAR-table lines: 4
boot  0  Aug 12 07:00   DMAR-table lines: 0     <- firmware stopped publishing DMAR
```

**Not the CMOS battery.** The RTC read the correct time at boot, before any NTP sync
(`setting system clock to 2026-08-12T14:00:24 UTC` at a 07:00:24 PDT journal stamp, exactly
UTC-7), and the BIOS clock was correct on screen. A dead cell takes the clock with the settings.

## Can BIOS settings be backed up to a file?

Only from inside the BIOS itself, and with caveats:

- **Gigabyte** — *Save & Exit → Save Profiles*. **Export to a USB stick**, not just an internal
  slot: internal profiles live in CMOS, so a clear-CMOS destroys them along with everything else.
- **AMI mini-PC builds (Beelink)** — often expose no profile save at all.
- No BMC on any of these boxes, so there is no out-of-band route.
- Linux cannot dump or restore firmware settings. `dmidecode` reads identity, not configuration.
- Profile blobs are tied to the **BIOS version** and usually refuse to load after a flash.

Which is why the table below exists: written settings survive a flash, a new board, and a
clear-CMOS. Treat the USB profile as a convenience, this file as the real backup.

## Required settings

### nasir — Gigabyte B660I AORUS PRO DDR4, BIOS F28 (12/15/2023)

Runs **truenasir (VM 100)** with an LSI SAS2008 HBA passed through, and **docker1 (VM 101)**
with the iGPU passed through. Both are dead without these.

| Setting | Value | Why |
|---|---|---|
| **Intel VT-d** | **Enabled** | the one that broke. No VT-d, no passthrough, both VMs refuse to start |
| Intel Virtualization Technology (VT-x) | Enabled | KVM itself |
| Boot order | NVMe first | defaults may reorder it |

That is the complete list. **VT-d alone was the fix** — everything else on the board was left at
its post-reset value and passthrough works, which is why the table below exists.

Passed-through devices, for reference:

```
VM 100 truenasir : hostpci0: <PCI_ADDR>   LSI SAS2008 [9211-8i]   (bios: ovmf, machine: q35)
VM 101 docker1   : hostpci0: <PCI_ADDR>     Intel UHD 730 iGPU      (x-vga=1)
```

**Known-good state, captured 2026-08-12 after the repair:**

```
iommu_groups: 16          iommu_class_entries: 2      dmar_acpi_table: 4
vfio_modules: 4           hostpci_vms: 2              boot_mode: UEFI
<PCI_ADDR> -> iommu group 13, driver vfio-pci      (HBA -> truenasir)
<PCI_ADDR> -> iommu group 0,  driver vfio-pci      (iGPU -> docker1, Jellyfin QSV)
```

Settings deliberately LEFT as they are, so a future reset does not get "fixed" wrongly:

| Setting | Value | Why not to change it |
|---|---|---|
| Initial Display Output | **PCIe 1 Slot** | slot 1 holds the HBA, not a GPU. Pointing display at an empty slot keeps the host off the iGPU, which is what leaves it free to pass to docker1. Setting IGD makes the host bind it. |
| Above 4G Decoding | Disabled | passthrough works without it; do not change speculatively |
| Re-Size BAR Support | Disabled | ReBAR frequently breaks passthrough |
| VMD controller | **Enabled** | nasir boots from `root=ZFS=rpool/ROOT/pve-1`. Disabling VMD changes how storage is presented and can leave the host unbootable. It maps the SATA controller only, not the HBA. |
| AC BACK | Always Off | Gigabyte default. `Memory` would be better (a midday outage currently leaves the NAS off until the 07:00 WoL), but this is a preference, not a fault. |
| RST_SW (MULTIKEY) | HW Reset | this board has a configurable multi-function button whose options include **Clear CMOS** — the most likely cause of this whole incident |

**ECC: not possible on this board.** `Error Correction Type: None`, no EDAC memory controller registered.
B660 is a consumer chipset; ECC needs W680 or Xeon. The 2x32GB DDR4-3200 ECC UDIMMs run fine as
plain non-ECC RAM. Nothing to fix.

### lilboi — Beelink AZW SEi, AMI ALDER112 (06/19/2023)

No passthrough VMs, so IOMMU is **not** required — `iommu_groups: 0` is its correct state.
Runs porty, docker0, homie.

| Setting | Value |
|---|---|
| Intel Virtualization Technology (VT-x) | Enabled |
| Secure Boot | Disabled (current state) |
| Boot mode | UEFI |

### bigboi

Not captured yet — powered off in its scheduled window (bigboi and nasir shut down overnight to
save power; lilboi's cron sends the WoL that wakes them). Run `--save` against it when it is up.

## Detecting this automatically

`checkBiosState.sh` records the firmware-dependent state the OS *can* see, so a reset is caught
immediately rather than three VMs later.

```bash
bash checkBiosState.sh            # show current state
bash checkBiosState.sh --save     # write the baseline to ~/biosBaseline.txt
bash checkBiosState.sh --diff     # compare against the baseline, non-zero exit on drift
```

### How the baseline reaches the repo

`--save` writes to **`$HOME/biosBaseline.txt`** (so `/root` on the proxmox hosts), deliberately
NOT next to the script. The script lives in the git clone, which `restoreFromStore` replaces
wholesale — a baseline written there would be clobbered, and would be committed from whichever
host happened to run last.

Each physical host's `backupToStore` runs `--save` immediately before it copies `~` into Store,
so the capture is always fresh:

```
backupProxmoxMain.sh  (nasir)   -> Store/2025_backup/main-servers/proxmox-main/biosBaseline.txt
backupProxmoxMini.sh  (lilboi)  -> Store/2025_backup/main-servers/proxmox-mini/biosBaseline.txt
backupProxmoxLLM.sh   (bigboi)  -> Store/2025_backup/main-servers/proxmox-llm/biosBaseline.txt
```

Which means the monthly maintenance run collects all three automatically, and they arrive on the
laptop with the rest of Store. Nothing to run by hand, and no baseline is ever committed from the
wrong machine.

Only the three physical hosts do this. The VMs have virtual firmware, so a baseline there is
meaningless.

To compare after a suspected reset, on the host: `bash ~/Scripts/biosState/checkBiosState.sh --diff`.
The failure mode is silent — the cost of missing it is the NAS not coming back.
