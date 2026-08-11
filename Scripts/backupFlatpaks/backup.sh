#!/bin/bash
# Script that updates the flatpaks.txt at the /home/yasir folder


# Backing up flatpak lists in server
flatpak list --columns=application --app > ~/flatpaks.txt
