#!/bin/bash

#Send Each Tess files into the TESSFILE folder, meant to be sent to the NAS

#Directory where Tess files are uploaded
SOURCE_TESSW4="/home/indicatic-e1/Desktop/ASTRODEVICES/TESS-W4"
SOURCE_TESS="/home/indicatic-e1/Desktop/ASTRODEVICES/TESS-W"

#Directory where the csv files must be sent,(this is from this Directory that the files are sent in the NAS)
DESTINATION="/home/indicatic-e1/Desktop/ASTRODEVICES/TESSFILE"

while true; do
  for fileTESSW4 in "$SOURCE_TESSW4"/*.csv; do
    if [ -f "$fileTESSW4" ]; then
      mv "$fileTESSW4" "$DESTINATION"
      echo "File moved to : $fileTESSW4"
    fi
  done
  sleep 2
  for fileTESS in "$SOURCE_TESS"/*.csv; do
    if [ -f "$fileTESS" ]; then
      mv "$fileTESS" "$DESTINATION"
      echo "File movde to : $fileTESS"
    fi
  done
  sleep 10
done
