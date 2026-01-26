#!/bin/bash

#From here the oldest file of Nikon is selected and then treated

source /home/indicatic-e1/Desktop/code/Interop_code/TrameArchitecture.sh
source /home/indicatic-e1/Desktop/code/Interop_code/connect.sh
source /home/indicatic-e1/Desktop/code/Interop_code/info_Nass_connect.sh
source /home/indicatic-e1/Desktop/code/Interop_code/file_treatment.sh

Station=""
directory="/home/indicatic-e1/Desktop/ASTRODEVICES/NIKONFILE"
imageInfo="/home/indicatic-e1/Desktop/code/infoIMG"
File=$(ls -t --reverse "$directory" | head -n 1)


read -r Station < "/home/indicatic-e1/Desktop/code/NBstation.txt"
echo "Path of the station is : $Station"

index=6

execution
