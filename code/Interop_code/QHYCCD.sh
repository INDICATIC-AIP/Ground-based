#!/bin/bash

source /home/indicatic-e1/Desktop/code/Interop_code/TrameArchitecture.sh
source /home/indicatic-e1/Desktop/code/Interop_code/connect.sh
source /home/indicatic-e1/Desktop/code/Interop_code/info_Nass_connect.sh
source /home/indicatic-e1/Desktop/code/Interop_code/file_treatment.sh

Station=""
directory="/home/indicatic-e1/Desktop/ASTRODEVICES/QHYCCDFILE"
imageInfo="/home/indicatic-e1/Desktop/code/infoIMG"

# Archivo .fits más antiguo (formato 20260428T162735U.fits)
File=$(ls -t --reverse "$directory"/*.fits 2>/dev/null | head -n 1 | xargs -r basename 2>/dev/null)

# .raw correspondiente
RAW_FILE=""
if [ -n "$File" ]; then
    base="${File%.fits}"
    [ -f "$directory/${base}.raw" ] && RAW_FILE="${base}.raw"
fi

# Rename KStars format (20260430T093957U_002.fits) → clean format (20260430T093957U.fits)
if [ -n "$File" ]; then
    base="${File%.fits}"
    newbase=$(echo "$base" | sed 's/_[0-9]*$//' | sed 's/-//g')
    if [ "$base" != "$newbase" ] && [ -f "$directory/$File" ]; then
        mv "$directory/$File" "$directory/${newbase}.fits"
        if [ -n "$RAW_FILE" ] && [ -f "$directory/$RAW_FILE" ]; then
            mv "$directory/$RAW_FILE" "$directory/${newbase}.raw"
            RAW_FILE="${newbase}.raw"
        fi
        File="${newbase}.fits"
    fi
fi

read -r Station < "/home/indicatic-e1/Desktop/code/NBstation.txt"
echo "File: $File | Raw: $RAW_FILE"

# Filtro = último carácter antes de .fits
filter_letter=$(echo "$File" | sed -n "s/.*\([UBVRI]\)\.fits$/\1/p")

case "$filter_letter" in
    U) index=1 ;;
    B) index=2 ;;
    V) index=3 ;;
    R) index=4 ;;
    I) index=5 ;;
    *) index=0 ;;
esac

echo "Filter: $filter_letter -> index=$index"

execution
