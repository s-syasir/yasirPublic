#!/bin/bash
# Script for enabling zerotier VPN.

# Enabling the system service.
sudo systemctl enable zerotier-one.service
# Starting the system service.
sudo systemctl start zerotier-one.service 
# Reloading daemon
sudo systemctl daemon-reload
# Joining the network
sudo zerotier-cli join <ZT_NETWORK_ID>

