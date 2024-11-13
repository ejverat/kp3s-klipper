#!/bin/bash

NEWX=$(ls -Art /tmp/resonances_x_*.csv | tail -n 1)
DATE=$(date +'%Y-%m-%d-%H%M%S')
if [ ! -d "/home/pr3d/printer_data/config/input_shaper" ]
then
    mkdir /home/pr3d/printer_data/config/input_shaper
    chown pr3d:pr3d /home/pr3d/printer_data/config/input_shaper
fi

~/klipper/scripts/calibrate_shaper.py $NEWX -o /home/pr3d/printer_data/config/input_shaper/resonances_x_$DATE.png
