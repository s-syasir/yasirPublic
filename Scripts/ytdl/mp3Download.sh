#!/bin/bash
# PC-Version
#cat ./links.txt | xargs yt-dlp -o "<MOUNT_PATH> Quick_Downloads/mp3/%(title)s.%(ext)s" -x --audio-format mp3 --prefer-ffmpeg

# Server-Version
cat ./links.txt | xargs yt-dlp -o "/home/yasir/temp/mp3/%(title)s.%(ext)s" -x --audio-format mp3 --prefer-ffmpeg

