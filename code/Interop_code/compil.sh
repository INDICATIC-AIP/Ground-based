#!/bin/bash

#Compile all .sh files (if they have been changed on windows, this script convert them so they can be runned on linux)

#Path of .sh file
REPERTOIRE="/home/indicatic-e1/Desktop/code/Interop_code"

if [ -d "$REPERTOIRE" ]; then
    find "$REPERTOIRE" -type f -name "*.sh" -exec dos2unix {} +
    echo "Conversion done"
else
    echo "The repertory : $REPERTOIRE don't exist "
    exit 1
fi

echo "Done to compile"
