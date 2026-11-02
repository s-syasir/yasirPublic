#!/bin/bash
# Script that copies over the cron tab to a file in the home folder, successfully backing up settings for servers.
# Runs as root (nightly sync jobs, Proxmox hosts) or as yasir (backupToStore). Never prompts, never fails:
# sudo -n because a password prompt on the Pis hangs backup-All instead of erroring.

if [ "$(id -u)" -eq 0 ]; then
    cat /var/spool/cron/crontabs/root
else
    sudo -n cat /var/spool/cron/crontabs/root
fi > ~/cron 2>/dev/null || echo "# (root crontab not readable)" > ~/cron

if id yasir >/dev/null 2>&1; then
    echo "" >> ~/cron
    echo "# yasir user crontab" >> ~/cron
    if [ "$(id -u)" -eq 0 ]; then crontab -l -u yasir; else crontab -l; fi >> ~/cron 2>/dev/null || echo "# (none)" >> ~/cron
fi
exit 0
