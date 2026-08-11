#!/bin/bash
# Script that copies over the cron tab to a file in the home folder, successfully backing up settings for servers.

sudo cat /var/spool/cron/crontabs/root > ~/cron
echo "" >> ~/cron
echo "# yasir user crontab" >> ~/cron
crontab -l >> ~/cron
