#!/bin/bash

#Here are declared the variables used in crontab, to begin and end different scripts.

#Default time to begin a cycle
BegingDefaultAllHour="14"
BegingDefaultAllMinute="35"

#Default time to terminate a cycle
EndDefaultAllHour="16"
EndDefaultAllMinute="0"



#==================================================Time setting configuration Default

#Devices Alpy, QHY, Nikon

BegingCodeAlpyHour="$BegingDefaultAllHour"
BegingCodeAlpyMinute="$BegingDefaultAllMinute"

BegingCodeQHYHour="$BegingDefaultAllHour"
BegingCodeQHYMinute="$BegingDefaultAllMinute"

BegingCodeNikonHour="$BegingDefaultAllHour"
BegingCodeNikonMinute="$BegingDefaultAllMinute"


KillCodeAlpyHour="$EndDefaultAllHour"
KillCodeAlpyMinute="$EndDefaultAllMinute"

KillCodeQHYHour="$EndDefaultAllHour"
KillCodeQHYMinute="$EndDefaultAllMinute"

KillCodeNikonHour="$EndDefaultAllHour"
KillCodeNikonMinute="$EndDefaultAllMinute"

#Log and other code
BegingLogAlpyHour="$BegingDefaultAllHour"
BegingLogAlpyMinute="$BegingDefaultAllMinute"

BegingLogQHYCCDHour="$BegingDefaultAllHour"
BegingLogQHYCCDMinute="$BegingDefaultAllMinute"

BegingLogNikonHour="$BegingDefaultAllHour"
BegingLogNikonMinute="$BegingDefaultAllMinute"

BegingCheckAlpyLogsHour="$BegingDefaultAllHour"
BegingCheckAlpyLogsMinute="$BegingDefaultAllMinute"

BegingAlpyLogRefreshHour="$BegingDefaultAllHour"
BegingAlpyLogRefreshMinute="$BegingDefaultAllMinute"

BegingInteropLogRefreshHour="$BegingDefaultAllHour"
BegingInteropLogRefreshMinute="$BegingDefaultAllMinute"

BegingConverterLogRefreshHour="$BegingDefaultAllHour"
BegingConverterLogRefreshMinute="$BegingDefaultAllMinute"

BegingTESSLogRefreshHour="$BegingDefaultAllHour"
BegingTESSLogRefreshMinute="$BegingDefaultAllMinute"

BegingNikonLogRefreshHour="$BegingDefaultAllHour"
BegingNikonLogRefreshMinute="$BegingDefaultAllMinute"

BegingConverterPYHour="$BegingDefaultAllHour"
BegingConverterPYMinute="$BegingDefaultAllMinute"

BegingCodeInteropHour="$BegingDefaultAllHour"
BegingCodeInteropMinute="$BegingDefaultAllMinute"

BegingCodeTESSHour="$BegingDefaultAllHour"
BegingCodeTESSMinute="$BegingDefaultAllMinute"

BegingmainTESSHour="$BegingDefaultAllHour"
BegingmainTESSMinute="$BegingDefaultAllMinute"

BegingVerifSleepStatusHour="$BegingDefaultAllHour"
BegingVerifSleepStatusMinute="$BegingDefaultAllMinute"

BegingVerifInternetHour="$BegingDefaultAllHour"
BegingVerifInternetMinute="$BegingDefaultAllMinute"

BegingVerifMemoryHour="$BegingDefaultAllHour"
BegingVerifMemoryMinute="$BegingDefaultAllMinute"



KillLogAlpyHour="$EndDefaultAllHour"
KillLogAlpyMinute="$EndDefaultAllMinute"

KillLogQHYCCDHour="$EndDefaultAllHour"
KillLogQHYCCDMinute="$EndDefaultAllMinute"

KillLogNikonHour="$EndDefaultAllHour"
KillLogNikonMinute="$EndDefaultAllMinute"

KillCheckAlpyLogsHour="$EndDefaultAllHour"
KillCheckAlpyLogsMinute="$EndDefaultAllMinute"

KillAlpyLogRefreshHour="$EndDefaultAllHour"
KillAlpyLogRefreshMinute="$EndDefaultAllMinute"

KillInteropLogRefreshHour="$EndDefaultAllHour"
KillInteropLogRefreshMinute="$EndDefaultAllMinute"

KillConverterLogRefreshHour="$EndDefaultAllHour"
KillConverterLogRefreshMinute="$EndDefaultAllMinute"

KillTESSLogRefreshHour="$EndDefaultAllHour"
KillTESSLogRefreshMinute="$EndDefaultAllMinute"

KillNikonLogRefreshHour="$EndDefaultAllHour"
KillNikonLogRefreshMinute="$EndDefaultAllMinute"

KillConverterPYHour="$EndDefaultAllHour"
KillConverterPYMinute="$((EndDefaultAllMinute + 1))"

KillCodeInteropHour="$EndDefaultAllHour"
KillCodeInteropMinute="$EndDefaultAllMinute"

KillCodeTESSHour="$EndDefaultAllHour"
KillCodeTESSMinute="$EndDefaultAllMinute"

KillmainTESSHour="$EndDefaultAllHour"
KillmainTESSMinute="$((EndDefaultAllMinute + 1))"

KillVerifSleepStatusHour="$EndDefaultAllHour"
KillVerifSleepStatusMinute="$EndDefaultAllMinute"

KillVerifInternetHour="$EndDefaultAllHour"
KillVerifInternetMinute="$EndDefaultAllMinute"

KillVerifMemoryHour="$EndDefaultAllHour"
KillVerifMemoryMinute="$EndDefaultAllMinute"




