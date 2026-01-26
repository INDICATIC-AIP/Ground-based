#!/bin/bash

# Monitor ALPY - Script para enviar datos por MQTT
# Uso: ./alpy_monitor.sh {temperature_update|capture_start|capture_complete} [args...]

# Cargar configuración centralizada
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Función para enviar MQTT con logging
send_mqtt_with_log() {
    local topic="$1"
    local message="$2"
    
    send_mqtt "$topic" "$message"
    
    if [ $? -eq 0 ]; then
        log_message "$ALPY_LOG" " SENT to $topic: $message"
    else
        log_message "$ALPY_LOG" " FAILED to send to $topic: $message"
    fi
}

# Procesar argumentos
EVENT=$1
TOPIC_PREFIX="$JETSON_NAME/alpy"

case $EVENT in
    "temperature_update")
        TEMPERATURE=$2
        JSON_MSG="{\"temperature\":$TEMPERATURE}"
        send_mqtt_with_log "$TOPIC_PREFIX/temperature_update" "$JSON_MSG"
        ;;
    "capture_start")
        EXPOSURE_TIME=$2
        JSON_MSG="{\"exposure_time\":$EXPOSURE_TIME}"
        send_mqtt_with_log "$TOPIC_PREFIX/capture_start" "$JSON_MSG"
        ;;
    "capture_complete")
        FILENAME=$2
        TIME=$3
        TEMPERATURE=$4
        JSON_MSG="{\"filename\":\"$FILENAME\",\"time\":\"$TIME\",\"temperature\":$TEMPERATURE}"
        send_mqtt_with_log "$TOPIC_PREFIX/capture_complete" "$JSON_MSG"
        ;;
    *)
        echo "Usage: $0 {temperature_update|capture_start} [args...]"
        echo "Note: capture_complete deprecated - files detected by status_cameras.sh"
        exit 1
        ;;
esac

log_message "$ALPY_LOG" " Event '$EVENT' processed successfully" 