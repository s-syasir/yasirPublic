#!/bin/bash
# Goes through every compose folder, pulls the latest images, and recreates any
# container whose image actually changed.
#
# Containers stay UP during the pull; `up -d` then swaps only what changed, so
# downtime is seconds instead of the length of the download.

# Path to the main folder containing Docker Compose folders
BASE_DIR=/home/yasir/compose-docker

# Cap concurrent layer downloads/decompression. Stacks here go up to 53 services,
# and an unbounded pull is the memory/disk spike that has crashed this VM.
export COMPOSE_PARALLEL_LIMIT=3

updated=0
skipped=0
failed=0

echo
echo "Looping through all compose-docker folders to update using docker files"
echo

for dir in "$BASE_DIR"/*/; do
    if [[ ! -f "$dir/docker-compose.yml" && ! -f "$dir/docker-compose.yaml" ]]; then
        echo "SKIPPING $dir. No docker-compose file found in $dir"
        echo
        continue
    fi

    echo "Found docker-compose file in $dir"

    # Subshell so a failed cd can never leak into the next iteration
    (
        cd "$dir" || { echo "Failed to enter directory: $dir"; exit 2; }

        # A stack with no containers here belongs to another server. Checking this
        # with `ps` instead of `down` means foreign stacks are never touched and
        # local ones are never stopped just to find out they're local.
        if [[ -z "$(sudo docker compose ps -q 2>/dev/null)" ]]; then
            echo "SKIPPING $dir. No containers from this stack on this server."
            exit 3
        fi

        echo "PULLING $dir (containers stay up during the download)..."
        if ! sudo docker compose pull; then
            echo "PULL FAILED in $dir, leaving it running on its current images."
            exit 2
        fi

        echo "RECREATING any container whose image changed in $dir..."
        if ! sudo docker compose up -d; then
            echo "UP FAILED in $dir."
            exit 2
        fi
    )

    case $? in
        0) updated=$((updated+1)) ;;
        3) skipped=$((skipped+1)) ;;
        *) failed=$((failed+1)) ;;
    esac

    echo
done

# The images these pulls replaced are now untagged, and nothing else reclaims
# them. Dangling-only: tagged images and volumes are never touched.
echo "Reclaiming images replaced by this run..."
sudo docker image prune -f

echo
echo "Done. updated=$updated skipped=$skipped failed=$failed"
df -h / | tail -1
