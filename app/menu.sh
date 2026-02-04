#!/bin/bash
# ==============================================
# MAIN SCRIPT - CAMERA CONTROL MENU
# ==============================================
# This script displays an interactive menu to:
# - Configure automatic cycles by interval
# - Turn cameras on/off
# - Check camera status
#
# Uses auxiliary scripts:
# - variables.sh          → global configuration
# - camera_on_off.sh      → power control
# - status_cameras.sh     → camera status
# ==============================================


# ===============================
# BASE PATHS OF THE SCRIPT
# ===============================
# SCRIPT_DIR gets the absolute path of the directory
# where this script is located, regardless of
# where it is executed from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Shared variables file
VARIABLES_FILE="$SCRIPT_DIR/../AutoRun/variables.sh"

# Script responsible for turning cameras on/off
CAMERA_SCRIPT="$SCRIPT_DIR/camera_on_off.sh"

# Script responsible for showing camera status
STATUS_SCRIPT="$SCRIPT_DIR/status_cameras.sh"

# Camera control source files
INDI_CPP="$SCRIPT_DIR/../INDIcode/indi.cpp"
QHY_CPP="$SCRIPT_DIR/../INDIcode/qhy_ccd_test.cpp"
NIKON_SH="$SCRIPT_DIR/../code/nikon.sh"

# Dome control (Sun-based automation + MQTT)
SUN_DOMO_SCRIPT="$SCRIPT_DIR/sun_time_broker.py"




# ===============================
# CRITICAL CHECK
# =============================== 
# If variables.sh does not exist, the system cannot continue
# because it contains essential configuration (schedules, flags, etc.)
if [ ! -f "$VARIABLES_FILE" ]; then
    echo "ERROR: variables.sh not found"
    echo "Searched path:"
    echo "$VARIABLES_FILE"
    read -p "Press ENTER to exit..."
    exit 1
fi


# ===============================
# FUNCTION: CONFIGURE AUTOMATIC CYCLE
# ===============================
# Allows setting a time interval in minutes
# and saves start and end times in variables.sh
set_cycle_interval() {
    clear
    echo "======================================"
    echo "   AUTOMATIC CYCLE BY INTERVAL"
    echo "======================================"
    echo "1) 3 minutes"
    echo "2) 5 minutes"
    echo "3) 10 minutes"
    echo "4) 30 minutes"
    echo "5) 1 hour"
    echo "6) 3 hours"
    echo "7) 5 hours"
    echo "8) Custom (minutes)"
    echo "0) Back"
    echo "--------------------------------------"
    read -p "Select an option: " opt

    # Assign minutes based on selected option
    case $opt in
        1) minutes=3 ;;
        2) minutes=5 ;;
        3) minutes=10 ;;
        4) minutes=30 ;;
        5) minutes=60 ;;
        6) minutes=180 ;;
        7) minutes=300 ;;
        8) read -p "Enter minutes: " minutes ;;
        0) return ;;
        *) echo "Invalid option"; sleep 1; return ;;
    esac

    # Current time (cycle start)
    start_time=$(date +%H:%M)
    start_hour=$(date +%H)
    start_min=$(date +%M)

    # End time calculated based on chosen minutes
    end_time=$(date -d "+$minutes minutes" +%H:%M)
    end_hour=$(date -d "+$minutes minutes" +%H)
    end_min=$(date -d "+$minutes minutes" +%M)

    # Update variables inside variables.sh
    sed -i \
        -e "s/^BegingDefaultAllHour=.*/BegingDefaultAllHour=\"$start_hour\"/" \
        -e "s/^BegingDefaultAllMinute=.*/BegingDefaultAllMinute=\"$start_min\"/" \
        -e "s/^EndDefaultAllHour=.*/EndDefaultAllHour=\"$end_hour\"/" \
        -e "s/^EndDefaultAllMinute=.*/EndDefaultAllMinute=\"$end_min\"/" \
        "$VARIABLES_FILE"

    echo ""
    echo "✅ Cycle configured successfully"
    echo "Start : $start_time"
    echo "End   : $end_time"
    echo ""
    read -p "Press ENTER to continue..."
}


# ===============================
# CAMERA SUBMENU + CONFIRMATION
# ===============================
# This function receives the action ("on" or "off")
# and allows selecting which cameras are affected
camera_menu() {
    local action="$1"
    local action_text

    # Human-readable text based on the action
    if [ "$action" = "on" ]; then
        action_text="TURN ON"
    else
        action_text="TURN OFF"
    fi

    clear
    echo "======================================"
    echo "   $action_text CAMERAS"
    echo "======================================"
    echo "1) All"
    echo "2) Alpy"
    echo "3) QHY"
    echo "4) Nikon"
    echo "0) Back"
    echo "--------------------------------------"
    read -p "Select an option: " cam

    # Define cameras based on selection
    case $cam in
        1)
            cams="alpy qhy nikon"
            cams_text="ALL CAMERAS"
            ;;
        2)
            cams="alpy"
            cams_text="ALPY"
            ;;
        3)
            cams="qhy"
            cams_text="QHY"
            ;;
        4)
            cams="nikon"
            cams_text="NIKON"
            ;;
        0)
            return
            ;;
        *)
            echo "Invalid option"
            sleep 1
            return
            ;;
    esac

    # User confirmation before executing
    echo ""
    echo "⚠️  CONFIRMATION"
    echo "--------------------------------------"
    echo "You are about to $action_text: $cams_text"
    echo ""
    read -p "Are you sure? (y/N): " confirm

    # Only execute if user confirms with Y or y
    if [[ "$confirm" =~ ^[yY]$ ]]; then
        "$CAMERA_SCRIPT" "$action" $cams

        # Check if the script failed
        if [ $? -ne 0 ]; then
            echo ""
            echo "🚨 ERROR: action could not be executed"
        else
            echo ""
            echo "✅ Action executed successfully"
        fi
    else
        echo ""
        echo "❌ Action cancelled by user"
    fi

    echo ""
    read -p "Press ENTER to continue..."
}

# ===============================
# CAMERA EXPOSURE/TEMPERATURE
# ===============================
# This function controls the expuse/temperature

# Convert seconds → microseconds (QHY)
to_microseconds() {
    echo "$(printf "%.0f" "$(echo "$1 * 1000000" | bc -l)")"
}

# Convert seconds → Nikon shutter format
to_nikon_shutter() {
    local s="$1"

    if (( $(echo "$s >= 1" | bc -l) )); then
        printf "%.4fs" "$s"
    else
        local inv
        inv=$(printf "%.0f" "$(echo "1 / $s" | bc -l)")
        echo "1/$inv"
    fi
}

# Force decimal format (10 -> 10.0, -5 -> -5.0)
to_decimal() {
    local v="$1"

    # add a .0
    if [[ "$v" =~ ^-?[0-9]+$ ]]; then
        echo "${v}.0"
    else
        echo "$v"
    fi
}



configure_cameras() {
    clear
    echo "======================================"
    echo "       CONFIGURE CAMERAS"
    echo "======================================"
    echo "1) All"
    echo "2) Alpy (INDI)"
    echo "3) QHY"
    echo "4) Nikon"
    echo "0) Back"
    echo "--------------------------------------"
    read -p "Select camera(s): " cam

    case $cam in
        1) CAMS="alpy qhy nikon" ;;
        2) CAMS="alpy" ;;
        3) CAMS="qhy" ;;
        4) CAMS="nikon" ;;
        0) return ;;
        *) echo "Invalid Option"; sleep 1; return ;;
    esac

    echo ""
    echo "1) Exposition / Capture"

    if [[ "$CAMS" =~ "alpy" || "$CAMS" =~ "qhy" ]]; then
        echo "2) Temperature"
        echo "0) Back"
        echo "--------------------------------------"
        read -p "Select option: " opt
        [ "$opt" = "0" ] && return
        if [[ ! "$opt" =~ ^[12]$ ]]; then
            echo "Invalid Option"; sleep 1; return
        fi
    else
        opt=1  # only Nikon
    fi

    # -----------------------------
    # Exposure / Capture
    # -----------------------------
    if [ "$opt" = "1" ]; then
        echo ""
        echo "1) 10 seconds"
        echo "2) Minimum"
        echo "3) Custom"
        echo "--------------------------------------"
        read -p "Select exposure: " expopt
        case $expopt in
            1) USER_VAL=10 ;;
            2) USER_VAL="MIN" ;;
            3) read -p "Enter exposure in seconds: " USER_VAL ;;
            *) echo "Invalid Option"; sleep 1; return ;;
        esac

        for cam in $CAMS; do
            case $cam in
                alpy)
                    if [ "$USER_VAL" = "MIN" ]; then VAL=0.1; else VAL=$(to_decimal "$USER_VAL"); fi
                    sed -i "s/double ExpositionTime = .*/double ExpositionTime = $VAL;/" "$INDI_CPP"
                    ;;
                qhy)
                    if [ "$USER_VAL" = "MIN" ]; then VAL=1000; else VAL=$(to_microseconds "$USER_VAL"); fi
                    sed -i "s/int EXPOSURE_TIME = .*/int EXPOSURE_TIME = $VAL ;/" "$QHY_CPP"
                    ;;
                nikon)
                    if [ "$USER_VAL" = "MIN" ]; then VAL="1/4000"; else VAL=$(to_nikon_shutter "$USER_VAL"); fi
                    sed -i "s|gphoto2 --set-config shutterspeed=.*|gphoto2 --set-config shutterspeed=$VAL|" "$NIKON_SH"
                    ;;
            esac
        done
    fi

    # -----------------------------
    # Temperature
    # -----------------------------
    if [ "$opt" = "2" ]; then
        echo ""
        echo "1) -5.0"
        echo "2) Custom"
        echo "--------------------------------------"
        read -p "Select temperature: " topt

        case $topt in
            1) TEMP=-5.0 ;;
            2)
                read -p "Enter temperature: " TEMP
                TEMP=$(to_decimal "$TEMP")
                ;;
            *) echo "Invalid Option"; sleep 1; return ;;
        esac

        for cam in $CAMS; do
            case $cam in
                alpy)
                    sed -i "s/double TargetedTemp = .*/double TargetedTemp = $TEMP;/" "$INDI_CPP"
                    ;;
                qhy)
                    sed -i "s/double TargetedTemp = .*/double TargetedTemp = $TEMP ;/" "$QHY_CPP"
                    ;;
            esac
        done
    fi


    echo ""
    echo "✅ Configuration applied successfully"
    read -p "Press ENTER to continue..."
}

# ===============================
# DOME CONTROL MENU (SUN + MQTT)
# ===============================
# Dome actions are controlled via MQTT commands sent to
# ESP32 devices. Automatic OPEN/CLOSE events are scheduled
# based on solar twilight calculations:
#
# - Civil Twilight
# - Nautical Twilight
# - Astronomical Twilight

dome_menu() {
    while true; do
        clear
        echo "======================================"
        echo "     ASTRONOMICAL DOME CONTROL"
        echo "======================================"
        echo "1) Enable AUTO (Civil Twilight)"
        echo "2) Enable AUTO (Nautical Twilight)"
        echo "3) Enable AUTO (Astronomical Twilight)"
        echo "--------------------------------------"
        echo "4) OPEN dome now"
        echo "5) CLOSE dome now"
        echo "--------------------------------------"
        echo "6) Show today's sun times"
        echo "7) Dome status (MQTT callback)"
        echo "0) Back"
        echo "--------------------------------------"
        read -p "Select option: " opt

        case $opt in
            1)
                clear
                echo "Enabling AUTO mode (Civil Twilight)..."
                "$SUN_DOMO_SCRIPT" auto civil
                read -p "Press ENTER to continue..."
                ;;
            2)
                clear
                echo "Enabling AUTO mode (Nautical Twilight)..."
                "$SUN_DOMO_SCRIPT" auto nautical
                read -p "Press ENTER to continue..."
                ;;
            3)
                clear
                echo "Enabling AUTO mode (Astronomical Twilight)..."
                "$SUN_DOMO_SCRIPT" auto astronomical
                read -p "Press ENTER to continue..."
                ;;
            4)
                clear
                echo "Opening dome now..."
                "$SUN_DOMO_SCRIPT" open civil
                read -p "Press ENTER to continue..."
                ;;
            5)
                clear
                echo "Closing dome now..."
                "$SUN_DOMO_SCRIPT" close civil
                read -p "Press ENTER to continue..."
                ;;
            6)
                clear
                echo "Today's sun times:"
                echo "------------------"
                "$SUN_DOMO_SCRIPT" --info civil
                echo ""
                "$SUN_DOMO_SCRIPT" --info nautical
                echo ""
                "$SUN_DOMO_SCRIPT" --info astronomical
                echo ""
                read -p "Press ENTER to continue..."
                ;;
            7)
                clear
                echo "Listening for dome status (CTRL+C to exit)..."
                echo ""
                mosquitto_sub -v -t "domo/+/status"
                read -p "Press ENTER to continue..."
                ;;
            0)
                break
                ;;
            *)
                echo "Invalid option"
                sleep 1
                ;;
        esac
    done
}


# ===============================
# MAIN MENU
# ===============================
# Infinite loop until user chooses to exit
while true; do
    clear
    now=$(date "+%Y-%m-%d %H:%M:%S")

    echo "================================================"
    echo "        CAMERA MENU        [ $now ]"
    echo "================================================"
    echo "1) Configure cycle by interval"
    echo "2) Turn cameras on"
    echo "3) Turn cameras off"
    echo "4) Camera status"
    echo "5) Configure cameras"
    echo "6) Dome control"
    echo "0) Exit"
    echo "------------------------------------------------"
    read -p "Select an option: " choice

    case $choice in
        1) set_cycle_interval ;;
        2) camera_menu "on" ;;
        3) camera_menu "off" ;;
        4)
            "$STATUS_SCRIPT" status
            read -p "Press ENTER to continue..."
            ;;
        5) configure_cameras ;;
        6) dome_menu ;;
        0)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option"
            sleep 1
            ;;
    esac
done
