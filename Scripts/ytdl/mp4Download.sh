#!/bin/bash
# PC-Version
#cat ./links.txt | xargs yt-dlp -o "<MOUNT_PATH> Quick_Downloads/mp4/%(title)s.%(ext)s" -f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/mp4'

# Server-Version
cat ./links.txt | xargs yt-dlp -o "/home/yasir/temp/mp4/%(title)s.%(ext)s" -f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/mp4'
