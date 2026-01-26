#!/bin/bash

# Script para verificar conexiones de cámaras y encenderlas si es necesario
# Este script se ejecuta periódicamente para asegurar que las cámaras estén conectadas y encendidas

source /home/indicatic-e1/Desktop/AutoRun/variables.sh

#========================Check drivers=====================================

echo "Checking the drivers ..."

lsusb > /tmp/drivers.txt

sleep 1

drivs=$(cat /tmp/drivers.txt)


if ! echo "$drivs" | grep -q "Nikon Corp. D5600"; then
        echo "❌ The NIKON seems to be not connected to the Jetson, drivers not found."
        sbj="Nikon not connected"
        msg="The NIKON seems to be not connected to the Jetson, drivers not found."
        pwd=$(pwd)
        "$pwd"/SendMail.sh "$sbj" "$msg" 
    else
        echo "✅ NIKON is connected to the Jetson"
fi

sleep 1

if ! echo "$drivs" | grep -E -q "Starlight Xpress|Cypress Semiconductor Corp. Unprogrammed CY7C65642 hub"; then
        echo "❌ The ALPY seems to be not connected to the Jetson, drivers not found."
        sbj="ALPY not connected"
        msg="ALPY seems to be not connected to the Jetson, drivers not found."
        pwd=$(pwd)
        "$pwd"/SendMail.sh "$sbj" "$msg"
    else
        echo "✅ ALPY is connected to the Jetson"
fi

sleep 1

if ! echo "$drivs" | grep -E -q "Terminus Technology Inc. FE 2.1 7-port Hub|Future Technology Devices International, Ltd FT2232C/D/H"; then
        echo "❌ The QHYCCD seems to be not connected to the Jetson, drivers not found."
        sbj="QHYCCD not connected"
        msg="The QHYCCD seems to be not connected to the Jetson, drivers not found."
        pwd=$(pwd)
        "$pwd"/SendMail.sh "$sbj" "$msg"
    else
        echo "✅ QHYCCD is connected to the Jetson"
fi

sleep 1


#========================Check camera power status=====================================

echo "Checking camera power status..."

# Función para verificar y encender cámara si es necesario
check_and_power_camera() {
    local camera_name="$1"
    local driver_check="$2"
    
    if echo "$drivs" | grep -E -q "$driver_check"; then
        echo "✅ $camera_name drivers found, checking power status..."
        
        # Verificar estado de la cámara
        camera_status=$(/home/indicatic-e1/Desktop/app/strip_status.sh "$camera_name")
        
        if [[ "$camera_status" == "off" ]]; then
            echo "⚠️ $camera_name is connected but powered off. Turning it on..."
            /home/indicatic-e1/Desktop/app/camera_on_off.sh on "$camera_name"
            sleep 3
        elif [[ "$camera_status" == "on" ]]; then
            echo "✅ $camera_name is powered on"
        else
            echo "❌ Error checking $camera_name power status"
            # sbj="$camera_name power status error"
            # msg="Could not verify power status for $camera_name"
            # pwd=$(pwd)
            # "$pwd"/SendMail.sh "$sbj" "$msg"
        fi
    else
        echo "❌ $camera_name drivers not found, skipping power check"
    fi
}

# Verificar cada cámara
check_and_power_camera "nikon" "Nikon Corp. D5600"
check_and_power_camera "alpy" "Starlight Xpress|Cypress Semiconductor Corp. Unprogrammed CY7C65642 hub"
check_and_power_camera "qhy" "Terminus Technology Inc. FE 2.1 7-port Hub|Future Technology Devices International, Ltd FT2232C/D/H"

echo "--------------------------------------------------------------------------------------"
sleep 1


#=================================================================================== 

if pgrep -f "indiserver -v indi_sx_ccd indi_qhy_ccd" > /dev/null; then
    echo "✅ INDI server is already running."
else
    echo "⚠️ INDI server is not running, starting now ..."
    sleep 1
    /home/indicatic-e1/Desktop/AutoRun/IndiServ.sh
fi

echo "--------------------------------------------------------------------------------------"
sleep 5

#========================Check indi_getprop part===========================

indi_getprop > /tmp/indi_getprop_output.txt

sleep 2

INDGET=$(cat /tmp/indi_getprop_output.txt)

if ! echo "$INDGET" | grep -q "QHY CCD 16200A-M-00f7e4.POLLING_PERIOD.PERIOD_MS"; then
        echo "❌ The QHYCCD seems to be not connected."
        sbj="QHYCCD not connected"
        msg="The QHYCCD seems to be not connected, it do not appear on indi property."
        pwd=$(pwd)
        "$pwd"/SendMail.sh "$sbj" "$msg"
    else
        echo "✅ QHYCCD is in indi_getprop"
fi

sleep 1

if ! echo "$INDGET" | grep -q "SX CCD SX-825.ACTIVE_DEVICES.ACTIVE_SKYQUALITY"; then
        echo "❌ The ALPY seems to be not connected."
        sbj="ALPY not connected"
        msg="ALPY seems to be not connected, it do not appear on indi property."
        pwd=$(pwd)
        "$pwd"/SendMail.sh "$sbj" "$msg"
    else
        echo "✅ ALPY is in indi_getprop"
fi

#===================================================================================    




# Verificación de conexiones
BegingCheckConnectionsHour="$BegingDefaultAllHour"
BegingCheckConnectionsMinute="$((BegingDefaultAllMinute - 5))"  # 5 minutos antes que las cámaras

KillCheckConnectionsHour="$EndDefaultAllHour"
KillCheckConnectionsMinute="$EndDefaultAllMinute"


$BegingCheckConnectionsMinute $BegingCheckConnectionsHour * * * /home/indicatic-e1/Desktop/AutoRun/CheckConnections.sh > /tmp/logCheckConnections.txt 2>&1