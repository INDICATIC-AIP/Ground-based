#!/bin/bash

#From here the oldest file of Alpy is selected and then treated

source /home/indicatic-e1/Desktop/code/Interop_code/TrameArchitecture.sh
source /home/indicatic-e1/Desktop/code/Interop_code/connect.sh
source /home/indicatic-e1/Desktop/code/Interop_code/info_Nass_connect.sh
source /home/indicatic-e1/Desktop/code/Interop_code/file_treatment.sh

Station=""
directory="/home/indicatic-e1/Desktop/ASTRODEVICES/ALPYFILE"
imageInfo="/home/indicatic-e1/Desktop/code/infoIMG"
File=$(ls -t --reverse "$directory" | head -n 1)

read -r Station < "/home/indicatic-e1/Desktop/code/NBstation.txt" #Put the name of the station into Station variable
echo "Path of the station is : $Station"

index=0

execution
