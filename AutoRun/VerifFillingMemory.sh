#!/bin/bash

#Monitor the station's memory usage, and if it exceeds 140GB, terminate PID devices to halt image capture. Resume capturing once the memory drops to 40GB, provided it is within the cycle time.

source /home/indicatic-e1/Desktop/AutoRun/variables.sh

while :; do
    sleep 15

    UsedSpace=$(df -BG | awk '$1 == "/dev/mmcblk0p1" {print $3}' | sed 's/G//')

    if [[ $UsedSpace -ge 140 ]]; then
	pkill -SIGUSR1 -f /home/indicatic-e1/Desktop/INDIcode/qhy
	pkill -SIGUSR1 -f /home/indicatic-e1/Desktop/INDIcode/alpy
	pkill -SIGUSR1 -f /home/indicatic-e1/Desktop/code/nikon.sh
        
        while [[ $UsedSpace -ge 40 ]]; do
            sleep 60
            UsedSpace=$(df -BG | awk '$1 == "/dev/mmcblk0p1" {print $3}' | sed 's/G//')
	    StartTime="$BegingDefaultAllHour:$BegingDefaultAllMinute:00"
            EndTime="$EndDefaultAllHour:$EndDefaultAllMinute:00"
            actualTime=$(date +"%H:%M:%S")

            if [[ $UsedSpace -lt 41 && "$actualTime" > "$StartTime" && "$actualTime" < "$EndTime" ]]; then
		nohup /home/indicatic-e1/Desktop/INDIcode/qhy > /tmp/logQHY.txt 2>&1 & echo $! > /tmp/qhy_ccd_test.pid
                nohup /home/indicatic-e1/Desktop/INDIcode/alpy > /tmp/logalpy.txt 2>&1 & echo $! > /tmp/my_client.pid
                nohup /home/indicatic-e1/Desktop/code/nikon.sh > /tmp/lognik.txt 2>&1 & echo $! > /tmp/nikon.pid
                bash "$0"
            fi
        done
    fi
done
