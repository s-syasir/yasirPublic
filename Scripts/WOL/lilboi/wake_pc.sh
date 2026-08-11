#!/bin/bash
echo Waking up PC
sudo etherwake -i vmbr0 <MAC>
sleep 60
echo PC should be awake
