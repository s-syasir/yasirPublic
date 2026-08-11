#!/bin/bash
echo Waking up PC
sudo etherwake -i enp7s0 <MAC>
sleep 60
echo PC should be awake
