#!/bin/bash

#Check if the internet is accessible or no, if it is not accessible, than all scripts are terminated, waiting the internet to come back, if it's come back between cycle time, then execution of the scripts, or wait until the next cycle. 

source /home/indicatic-e1/Desktop/AutoRun/variables.sh

HOST="8.8.8.8"

while :; do
    sleep 5

    if ping -c 5 -W 20 $HOST > /dev/null 2>&1; then
    else 
        
        cat <<EOF > /tmp/new_cron_jobs
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

        pkill -9 -f InteropLogRefresh.sh
        pkill -9 -f my_program
        > /tmp/Interop.pid

        while :; do
            sleep 15
            if ping -c 1 -W 10 $HOST > /dev/null 2>&1; then
                StartTime="$BegingDefaultAllHour:$BegingDefaultAllMinute:00"
                EndTime="$EndDefaultAllHour:$EndDefaultAllMinute:00"
                actualTime=$(date +"%H:%M:%S")

                if [[ "$actualTime" > "$StartTime" && "$actualTime" < "$EndTime" ]]; then

                    nohup /home/indicatic-e1/Desktop/INDIcode/qhy > /tmp/logQHY.txt 2>&1 & echo $! > /tmp/qhy_ccd_test.pid
                    nohup /home/indicatic-e1/Desktop/INDIcode/alpy > /tmp/logalpy.txt 2>&1 & echo $! > /tmp/my_client.pid
                    nohup /home/indicatic-e1/Desktop/code/nikon.sh > /tmp/lognik.txt 2>&1 & echo $! > /tmp/nikon.pid
                    
                    nohup python3 /home/inohup /home/indicatic-e1/Desktop/code/Interop_code/my_program > /dev/null 2>&1 & echo $! > /tmp/Interop.pidndicatic-e1/Desktop/code/converter.py > /tmp/logConverter.txt 2>&1 & echo $! > /tmp/Converter.pid
                    nohup /home/indicatic-e1/Desktop/code/Interop_code/TESS.sh > /tmp/logTESS.txt 2>&1 & echo $! > /tmp/TESS.pid
                    nohup /home/indicatic-e1/Desktop/AutoRun/CheckAlpyLogs.sh > /tmp/logCheckAlpyLogs.txt 2>&1 & echo $! > /tmp/CheckAlpyLogs.pid

                    nohup /home/indicatic-e1/Desktop/code/mainTess.sh > /dev/null 2>&1 &
                    nohup /home/indicatic-e1/Desktop/AutoRun/AlpyLogRefresh.sh > /dev/null 2>&1 &
                    nohup /home/indicatic-e1/Desktop/AutoRun/InteropLogRefresh.sh > /dev/null 2>&1 &
                    nohup /home/indicatic-e1/Desktop/AutoRun/ConverterLogRefresh.sh > /dev/null 2>&1 &
                    nohup /home/indicatic-e1/Desktop/AutoRun/TESSLogRefresh.sh > /dev/null 2>&1 &
                    nohup /home/indicatic-e1/Desktop/AutoRun/NikonLogRefresh.sh > /dev/null 2>&1 &

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
                else
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
                fi
            bash "$0"
            fi
        done
    fi
done
