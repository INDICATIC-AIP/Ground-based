#!/bin/bash

#This script clear TESS logs each x seconds to free memory

while :; do
sleep 90
    echo "" > /tmp/logTESS.txt
    echo "clear"
done
