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
