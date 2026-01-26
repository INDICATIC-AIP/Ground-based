#!/bin/bash

if [[ ! -d "$1" ]]; then
    echo "Folder '$1' don't exist."
    exit 1
fi

cd "$1"

PayloadFile=$(find . -type f -name "*.NEF" -o -name "*.fits" -o -name "*.csv" | head -n 1)
InfoFile=$(find . -type f -name "*.txt" | head -n 1)

echo "PayloadFile : $PayloadFile"
echo "INfoFile : $InfoFile"

PayloadName=$(basename "$PayloadFile")
InfoName=$(basename "$InfoFile")

echo "payloadname : $PayloadName"
echo "infoname : $InfoName"

echo "argument 1 : $1"
echo "argument 2 : $2"

mv "$PayloadName" "$2"
mv "$InfoName" "$2"

sleep 3

if [[ -d "$1" && -z "$(ls -A "$1" 2>/dev/null)" ]]; then
    rm -r -- "$1"
fi

