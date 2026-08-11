#!/bin/bash
# Script for disabling zerotier VPN.

# Disabling the system service.
sudo systemctl disable zerotier-one.service
# Stopping the system service.
sudo systemctl stop zerotier-one.service 
# Reloading daemon
sudo systemctl daemon-reload

