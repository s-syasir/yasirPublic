#!/bin/bash
# A script designed to go through specific docker volume data and rysnc it over
# to the appropriate /home/yasir/docker/ location. This is designed to be run via a cronjob
# and then /home/yasir/docker/ is backed up by backupToStore to appropriate locations or
# via rsync scripts.

# Path to the main folder containing Docker volumes
BASE_DIR=/var/lib/docker/volumes

# Path to main docker storage folder
DEST_DIR=/home/yasir/docker/

# Journald logging so a failed hourly volume backup is visible in Grafana/Loki.
. "$(dirname "$(readlink -f "$0")")/../lib/joblog.sh"
job_start



# Loop through each subdirectory in the base directory
echo
echo "Looping through all docker volumes"
echo
for dir in "$BASE_DIR"/*/; do
     # Get the directory name without the path
    dir_name=$(basename "$dir")
    
    # Print the current directory for debugging
    echo "Current directory: $dir"

    # Check if the volume directory name starts with "wger"
    if [[ $dir_name == wger* ]]; then
      echo "Copying volume: $dir_name"
      # Rsync to the destination directory
      sudo rsync -au "$dir" "$DEST_DIR/wger/$dir_name"

    else
      # Print the directory name if it does not start with "wger"
      echo "Skipping volume: $dir_name"
    fi
    # FUTURE TODO: add checks for the other docker images that require volumes to function...

    echo
done

job_end
