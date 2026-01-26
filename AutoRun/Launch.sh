#!/bin/bash

#This the main script to execute to run the whole system of the station, it activate the indi server if it is not running and the crontab can be updated from this script when it is launched.

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

sleep 1    

#========================================Execution of the differents script for the interoperabilty code=====================
if [ ! -f "/tmp/Interop.pid" ]; then
touch /tmp/Interop.pid
echo "Interip.pid file created in /tmp folder"
fi


#nohup /home/indicatic-e1/Desktop/code/Interop_code/my_program > /dev/null 2>&1 & echo \$! > /tmp/Interop.pid


#if [[ $? -eq 0 ]]; then

#    echo "✅ Converter.py script executed successfully!"
#else
#    echo "❌ Converter.py execution failed!"
#    sbj="Problem script Converter.py"
#    msg="The script Converter.py meant to convert RAW images of QHYCCD to FITS format could not be executed."
#    pwd=$(pwd)
#    "$pwd"/SendMail.sh "$sbj" "$msg"
#fi


while true; do
    read -p "Do you want to keep the current configuration of the automation settings, or reset them to default? [ENTER: ACTUAL/DEFAULT], to view the current configuration enter: VIEW. " choice

    if [ "$choice" = "ACTUAL" ]; then
        echo "Cron keeps unchanged."
        crontab -l
        break

    elif [ "$choice" = "DEFAULT" ]; then

        cat <<EOF > /tmp/new_cron_jobs
$BegingCodeQHYMinute $BegingCodeQHYHour * * * /home/indicatic-e1/Desktop/INDIcode/qhy > /tmp/logQHY.txt 2>&1 & echo \$! > /tmp/qhy_ccd_test.pid
$BegingCodeAlpyMinute $BegingCodeAlpyHour * * * /home/indicatic-e1/Desktop/INDIcode/alpy > /tmp/logalpy.txt 2>&1 & echo \$! > /tmp/my_client.pid
$BegingCodeNikonMinute $BegingCodeNikonHour * * * /home/indicatic-e1/Desktop/code/nikon.sh > /tmp/lognik.txt 2>&1 & echo \$! > /tmp/nikon.pid
$BegingCodeInteropMinute $BegingCodeInteropHour * * * [ ! -s /tmp/Interop.pid ] || ! grep -q '[0-9]' /tmp/Interop.pid && /home/indicatic-e1/Desktop/AutoRun/GetInteropCodePID.sh
$BegingConverterPYMinute $BegingConverterPYHour * * * python3 /home/indicatic-e1/Desktop/code/converter.py > /tmp/logConverter.txt 2>&1 & echo \$! > /tmp/Converter.pid
$BegingCodeTESSMinute $BegingCodeTESSHour * * * /home/indicatic-e1/Desktop/code/Interop_code/TESS.sh > /tmp/logTESS.txt 2>&1 & echo \$! > /tmp/TESS.pid
$BegingCheckAlpyLogsMinute $BegingCheckAlpyLogsHour * * * /home/indicatic-e1/Desktop/AutoRun/CheckAlpyLogs.sh & echo \$! > /tmp/CheckAlpyLogs.pid
$BegingmainTESSMinute $BegingmainTESSHour * * * /home/indicatic-e1/Desktop/code/mainTess.sh
$BegingAlpyLogRefreshMinute $BegingAlpyLogRefreshHour * * * /home/indicatic-e1/Desktop/AutoRun/AlpyLogRefresh.sh 
$BegingInteropLogRefreshMinute $BegingInteropLogRefreshHour * * * /home/indicatic-e1/Desktop/AutoRun/InteropLogRefresh.sh
$BegingConverterLogRefreshMinute $BegingConverterLogRefreshHour * * * /home/indicatic-e1/Desktop/AutoRun/ConverterLogRefresh.sh
$BegingTESSLogRefreshMinute $BegingTESSLogRefreshHour * * * /home/indicatic-e1/Desktop/AutoRun/TESSLogRefresh.sh
$BegingNikonLogRefreshMinute $BegingNikonLogRefreshHour * * * /home/indicatic-e1/Desktop/AutoRun/NikonLogRefresh.sh
$BegingVerifInternetMinute $BegingVerifInternetHour * * * /home/indicatic-e1/Desktop/AutoRun/VerifInternet.sh
$BegingVerifMemoryMinute $BegingVerifMemoryHour  * * * /home/indicatic-e1/Desktop/AutoRun/VerifFillingMemory.sh


$KillCodeQHYMinute $KillCodeQHYHour * * * pkill -SIGUSR1 -f /home/indicatic-e1/Desktop/INDIcode/qhy
$KillCodeAlpyMinute $KillCodeAlpyHour * * * pkill -SIGUSR1 -f /home/indicatic-e1/Desktop/INDIcode/alpy
$KillCodeNikonMinute $KillCodeNikonHour * * * pkill -SIGUSR1 -f /home/indicatic-e1/Desktop/code/nikon.sh
$KillConverterPYMinute $KillConverterPYHour * * * pkill -SIGUSR1 -f /home/indicatic-e1/Desktop/code/converter.py
$KillCodeTESSMinute $KillCodeTESSHour * * * pkill -SIGUSR1 -f /home/indicatic-e1/Desktop/code/Interop_code/TESS.sh
$KillCheckAlpyLogsMinute $KillCheckAlpyLogsHour * * * pkill -SIGUSR1 -f /home/indicatic-e1/Desktop/AutoRun/CheckAlpyLogs.sh
$KillmainTESSMinute $KillmainTESSHour * * * /home/indicatic-e1/Desktop/code/mainTess.sh
$KillAlpyLogRefreshMinute $KillAlpyLogRefreshHour * * * pkill -SIGUSR1 -f /home/indicatic-e1/Desktop/AutoRun/AlpyLogRefresh.sh
$KillInteropLogRefreshMinute $KillInteropLogRefreshHour * * * /home/indicatic-e1/Desktop/AutoRun/VerifEndSendingFiles.sh
$KillConverterLogRefreshMinute $KillConverterLogRefreshHour * * * pkill -SIGUSR1 -f /home/indicatic-e1/Desktop/AutoRun/ConverterLogRefresh.sh
$KillTESSLogRefreshMinute $KillTESSLogRefreshHour * * * pkill -SIGUSR1 -f /home/indicatic-e1/Desktop/AutoRun/TESSLogRefresh.sh
$KillNikonLogRefreshMinute $KillNikonLogRefreshHour * * * pkill -SIGUSR1 -f /home/indicatic-e1/Desktop/AutoRun/NikonLogRefresh.sh
$KillVerifMemoryMinute $KillVerifMemoryHour * * * pkill -SIGUSR1 -f /home/indicatic-e1/Desktop/AutoRun/VerifFillingMemory.sh


EOF

        crontab /tmp/new_cron_jobs

        echo "✅ Settings added to cron!"
        crontab -l
        break

    elif [ "$choice" = "VIEW" ]; then
        echo "🔍 Current cron configuration:"
        crontab -l
    else
        echo "❌ Invalid input. Please enter ACTUAL, DEFAULT, or VIEW."
    fi
done
