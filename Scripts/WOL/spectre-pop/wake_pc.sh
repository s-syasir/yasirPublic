#!/bin/bash
echo Waking up PC
sudo etherwake -i wlp1s0 <MAC>
sleep 60
echo PC should be awake
