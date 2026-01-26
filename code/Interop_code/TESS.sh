#!/bin/bash

#From here the oldest file of TESS is selected and then treated

source /home/indicatic-e1/Desktop/code/Interop_code/TrameArchitecture.sh
source /home/indicatic-e1/Desktop/code/Interop_code/connect.sh
source /home/indicatic-e1/Desktop/code/Interop_code/info_Nass_connect.sh
source /home/indicatic-e1/Desktop/code/Interop_code/file_treatment.sh

Station="" #Path of the station
DESTINATION="" #Path dedicated for the TESS used, W4 or W
directory="/home/indicatic-e1/Desktop/ASTRODEVICES/TESSFILE" #Directory where the files are located
imageInfo="/home/indicatic-e1/Desktop/code/infoIMG" #Directory where the information of the files are located, (this is a temporary file)
File=$(ls -t --reverse "$directory" | head -n 1) #Selectionate the most older file
echo "Extracting TessName from: $File"
TessName=$(echo "$File" | grep -oP '(?<=s)\d+(?=_)')
echo "Extracted TessName: $TessName"


read -r Station < "/home/indicatic-e1/Desktop/code/NBstation.txt"
echo "Path of the station is : $Station"

#Affiliate the ID to the DESTINATION variable (valor of TessName must be changed, depends of the TESS connected to the station)
if [[ "$TessName" == 1315 ]]; then
  DESTINATION="-W4"
elif [[ "$TessName" == 1323 ]]; then
  DESTINATION="-W"
else
  echo "error"
fi

index=7

execution
