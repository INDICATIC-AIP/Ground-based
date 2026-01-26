#!/bin/bash

#From here the oldest file of QHY is selected and then treated

source /home/indicatic-e1/Desktop/code/Interop_code/TrameArchitecture.sh
source /home/indicatic-e1/Desktop/code/Interop_code/connect.sh
source /home/indicatic-e1/Desktop/code/Interop_code/info_Nass_connect.sh
source /home/indicatic-e1/Desktop/code/Interop_code/file_treatment.sh

Station=""
directory="/home/indicatic-e1/Desktop/ASTRODEVICES/QHYCCDFILE"
imageInfo="/home/indicatic-e1/Desktop/code/infoIMG"

# Select only .fits files (oldest first), not .raw files
File=$(ls -t --reverse "$directory"/*.fits 2>/dev/null | head -n 1 | xargs -r basename)

# Check if a corresponding .raw file exists with the same base name
if [ -n "$File" ]; then
    base_name="${File%.*}"
    RAW_FILE=""
    if [ -f "$directory/${base_name}.raw" ]; then
        RAW_FILE="${base_name}.raw"
        echo "Found corresponding raw file: $RAW_FILE"
    fi
fi

read -r Station < "/home/indicatic-e1/Desktop/code/NBstation.txt"
echo "Path of the station is : $Station"

#Select the number after the W letter wich indicate the filter used
index=$(echo "$File" | sed -n 's/.*W\([0-9]\+\).*/\1/p')

execution
