#!/bin/bash

# This script checks the temperature from the logalpy.txt file in two different cases:
# 1. **Setting the temperature**: When the temperature is being set, the script monitors if the cooling system is reaching the target value.
# 2. **Checking the temperature**: Once the temperature has been reached, the script verifies whether there are any problems while the ALPY is functioning.

filePath="/home/indicatic-e1/Desktop/AutoRun/logalpy.txt" 

if [[ -s "$filePath" ]]; then

    last_run_file_checking="/tmp/last_run_alpy"
    last_run_file_setting="/tmp/last_run_alpy_setting"

    nb_lines=$(grep -c "^Received" "$filePath") #Get the number of lines with Received
    while [[ "$nb_lines" -eq 3 ]]; do
        sleep 1
        nb_lines=$(grep -c "^Received" "$filePath") #Get the number of lines with Received
    done

    if grep -q "CCD connected." "$filePath" && ! grep -q "CCD temperature reached!" "$filePath"; then #CCD string is to know when alpy is setting the temperature or checking it
        CCD="Setting temp"
    else
        CCD="Checking temp"
    fi

    while :; do

        #Used to know the last time the file has been running, to avoid an sending email to be executed too much times
        if [[ -f "$last_run_file_setting" ]]; then
        last_run_setting=$(cat "$last_run_file_setting")
        else
            last_run_setting=0 
        fi

        current_time_setting=$(date +%s)

        if [[ -f "$last_run_file_checking" ]]; then
        last_run_checking=$(cat "$last_run_file_checking")
        else
            last_run_checking=0 
        fi

        current_time_checking=$(date +%s)

        LastLine=$(tail -n 1 "$filePath") #Get the last line

        nb_lines=$(grep -c "^Received" "$filePath") #Get the number of lines with Received

        #Check the setting of the temperature until the temperature is reached
        if [[ "$CCD" == "Setting temp" ]];then
            sleep 1
            if [[ "$LastLine" == Received* ]]; then
                
                temperature=$(echo "$LastLine" | awk '{print $4}') #Get the temperature of the last line (the last temperature received)
                echo "Temperature from the alpy logs file: $temperature °C in the case of setting the temperature"
                if [[ "$nb_lines" -ge 2 ]]; then
                    LastlineMone=$(tail -n 2 "$filePath" | head -n 1) #Get the penultimate line
                    temperatureMone=$(echo "$LastlineMone" | awk '{print $4}') #And get his temperature
                    if (( $(echo "$temperature > $temperatureMone" | bc -l) )); then #If the penultimate temperature is equal or greater then the last one
                        FiveLineBefore=$(tail -n 5 "$filePath" | head -n 1) #Get the the fifth higher line
                        temperatureFive=$(echo "$FiveLineBefore" | awk '{print $4}') #Get his temperature
                        if (( current_time_setting - last_run_setting >= 20 )); then
                            if [[ -n "$temperature" && -n "$temperatureFive" ]] && (( $(echo "$temperature == $temperatureFive || $temperature > $temperatureFive" | bc -l) )); then #Compare it
                                echo "sending email"
                                sbj="Cooling problem ALPY"
                                msg="The ALPY seems to have a problem to reach the setted temperature, Last temperature received : $temperature, temperature received before : $temperatureFive ."
                                pwd=$(pwd)
                                "$pwd"/SendMail.sh "$sbj" "$msg" #Send the email to inform of the temperature error
                                echo "$current_time_setting" > "$last_run_file_setting"
                            fi
                        fi
                    fi    
                fi
            else
                echo "NO temperature in setting."
            fi
        fi
        #Checking of the temperature until the temperature is reached
        if [[ "$CCD" == "Checking temp" ]];then
            sleep 1
            if [[ "$LastLine" == Received* ]]; then
                temperature=$(echo "$LastLine" | awk '{print $4}') #Get the temperature of the last line (the last temperature received)
                echo "Temperature from the alpy logs file: $temperature °C int the case of checking the temperature"
                if [[ "$nb_lines" -ge 2 ]]; then
                    LastlineMone=$(tail -n 2 "$filePath" | head -n 1) #Get the penultimate line
                    temperatureMone=$(echo "$LastlineMone" | awk '{print $4}') #And get his temperature
                    if (( current_time_checking - last_run_checking >= 600 )); then
                        if (( $(echo "$temperatureMone - 1 > $temperature" | bc -l) )); then #Compare it
                            echo "temperature : $temperature"
                            echo "temperatureMone : $temperatureMone"
                            sbj="Cooling problem ALPY"
                            msg="The ALPY seems to have a problem to maintain the setted temperature, Last temperature received : $temperature, temperature received before : $temperatureMone ."
                            pwd=$(pwd)
                            "$pwd"/SendMail.sh "$sbj" "$msg" #Send the email to inform of the temperature error
                            echo "email sent"
                            echo "$current_time_checking" > "$last_run_file_checking"
                        fi
                    fi
                fi
            else
                echo "NO temperature in checking."
            fi
        fi
    done
fi
