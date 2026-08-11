#!/bin/bash
# A script to kill syncthng on PC upon logging out. This prevents kernel panic when rebooting

# Include Flatpak environment
export PATH=$PATH:/usr/bin/flatpak

flatpak kill com.github.zocker_160.SyncThingy
