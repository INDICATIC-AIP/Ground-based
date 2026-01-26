#!/bin/bash

#Regularly check if the folders on each device are empty, and either terminate or keep the interoperability code running accordingly. 

source /home/indicatic-e1/Desktop/AutoRun/variables.sh

pidval=$(cat /tmp/Interop.pid)
echo " valor of interop pid $pidval"

while :; do
    sleep 30

    if [[ -z "$(ls -A /home/indicatic-e1/Desktop/ASTRODEVICES/ALPYFILE)" &&
          -z "$(ls -A /home/indicatic-e1/Desktop/ASTRODEVICES/NIKONFILE)" &&
          -z "$(ls -A /home/indicatic-e1/Desktop/ASTRODEVICES/QHYCCDFILE)" &&
          -z "$(ls -A /home/indicatic-e1/Desktop/ASTRODEVICES/TESSFILE)" &&
          -z "$(ls -A /home/indicatic-e1/Desktop/ASTRODEVICES/TESS-W)" &&
          -z "$(ls -A /home/indicatic-e1/Desktop/ASTRODEVICES/TESS-W4)" ]]; then
        newpidval=$(cat /tmp/Interop.pid)
        
       if [ "$pidval" -eq "$newpidval" ]; then

		pgrep -fl InteropLogRefresh.sh && kill -9 $(pgrep -f InteropLogRefresh.sh)
        pgrep -fl VerifInternet.sh && kill -9 $(pgrep -f VerifInternet.sh)
		pgrep -fl my_program && kill -9 $(pgrep -f my_program)
		> /tmp/Interop.pid
            exit 0
        fi
    fi

done
