 #!/bin/bash

#This script check if the three different devices are connected, Alpy, QHY and Nikon, the drivers are checked.
#When a device is not detected, an email is sent.

indiserver -v indi_sx_ccd indi_qhy_ccd > ~/logINDI.txt 2>&1 &

sleep 5

output=$(cat ~/logINDI.txt)

if [[ -n "$output" ]]; then
    echo "✅ INDI server is now running."
    else
    echo "❌ Indiserver could not be launched."
    sbj="Indi server is not running"
    msg="Indi server seems to have tried to launch itself, but failed."
    pwd=$(pwd)
    "$pwd"/SendMail.sh "$sbj" "$msg"
fi

sleep 1

    if ! echo "$output" | grep -q "indi_qhy_ccd: snooping on Telescope Simulator"; then
        echo "❌ The QHYCCD seems to be not connected."
        sbj="The QHYCCD is not running on server"
        msg="The QHYCCD seems to be not detected on the server side."
        pwd=$(pwd)
        "$pwd"/SendMail.sh "$sbj" "$msg"
    else
        echo "✅ QHYCCD is running on server"
    fi

    if ! echo "$output" | grep -q "indi_sx_ccd: snooping on Telescope Simulator"; then
        echo "❌ The ALPY seems to be not connected."
        sbj="ALPY is not running on server"
        msg="ALPY seems to be not connected on the server side."
        pwd=$(pwd)
        "$pwd"/SendMail.sh "$sbj" "$msg"
    else
        echo "✅ ALPY is running on server"
    fi
    
