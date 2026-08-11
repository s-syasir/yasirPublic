#!/bin/bash
# NOTE: a script for setting the /etc/hosts file based on the ~/hosts file + changed to use the hostname from Linux

# First make a temporary hosts file
sudo \cp ~/hosts ~/hosts_temp

# Replace the 127.0.1.1 line (regardless of position) with the current hostname
sudo sed -i "s/^127\.0\.1\.1.*/127.0.1.1 $(hostname)/" ~/hosts_temp

# Move over and overwrite the current /etc/hosts with the new hosts_temp
sudo \mv -f ~/hosts_temp /etc/hosts

# Then, chmod the /etc/hosts file to be the correct perms (rw r r)
sudo chmod 644 /etc/hosts
