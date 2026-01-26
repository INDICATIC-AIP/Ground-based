#!/bin/bash

# =====================
# status_cameras.sh 
# Uso recomendado: configurar para arrancar automáticamente con systemd o cron @reboot.
# Evita múltiples instancias y limpia temporales al salir.
# =====================

PIDFILE="/tmp/status_cameras.pid"
FAIL_COUNT=0
MAX_FAILS=5

# Limpieza al salir
cleanup() {
    # Borrar el PID sólo si el PID en el archivo corresponde al proceso actual
    if [ -f "$PIDFILE" ]; then
        PID_IN_FILE=$(cat "$PIDFILE" 2>/dev/null || echo "")
        if [ "$PID_IN_FILE" = "$$" ]; then
            rm -f "$PIDFILE"
        fi
    fi

    # Borrar el log sólo si este proceso es el propietario del PID almacenado
    if [ -f "/tmp/status_cameras.txt" ]; then
        if [ -f "$PIDFILE" ] && [ "$(cat "$PIDFILE" 2>/dev/null)" = "$$" ]; then
            rm -f "/tmp/status_cameras.txt"
        fi
    fi
}
trap cleanup EXIT
# Función para enviar MQTT con logging y manejo de errores
send_mqtt_with_log() {
    local topic="$1"
    local message="$2"
    send_mqtt "$topic" "$message"
    if [ $? -eq 0 ]; then
        log_message "$CAMERAS_LOG" " SENT to $topic: $message"
        FAIL_COUNT=0
    else
        log_message "$CAMERAS_LOG" " FAILED to send to $topic: $message"
        FAIL_COUNT=$((FAIL_COUNT+1))
        if [ $FAIL_COUNT -ge $MAX_FAILS ]; then
            log_message "$CAMERAS_LOG" "ALERTA: $FAIL_COUNT fallos consecutivos de MQTT. Verifica el broker o la red."
            FAIL_COUNT=0
        fi
    fi
}

# Función para generar JSON de archivos y enviarlo por MQTT
process_files() {
    local dir="$1"
    local topic="$2"
    local extension="$3"

    if [ -d "$dir" ] && compgen -G "$dir/*.$extension" > /dev/null; then
        files_json="["
        for f in "$dir"/*."$extension"; do
            size=$(stat -c%s "$f" 2>/dev/null || echo 0)
            files_json+="{\"filepath\":\"$(echo "$f" | sed 's/"/\\"/g')\",\"filesize\":$size},"
        done
        files_json=${files_json%,} # Remove trailing comma
        files_json+="]"

        # Validar JSON antes de enviarlo
        if echo "$files_json" | jq empty > /dev/null 2>&1; then
            send_mqtt_with_log "$topic" "$files_json"
        else
            log_message "$CAMERAS_LOG" "Error: JSON generado no es válido para $topic"
        fi
    else
        log_message "$CAMERAS_LOG" "No se encontraron archivos .$extension en $dir"
    fi
}

if [ "$1" == "1" ]; then
    # Evitar múltiples instancias
    if [ -f "$PIDFILE" ]; then
        if kill -0 $(cat "$PIDFILE") 2>/dev/null; then
            echo "status_cameras.sh ya está corriendo con PID $(cat $PIDFILE)"
            exit 1
        else
            echo "Archivo PID encontrado, pero el proceso no está corriendo. Limpiando archivo PID..."
            rm -f "$PIDFILE"
        fi
    fi

    echo "Iniciando status_cameras.sh..."
    nohup "$0" run > /tmp/status_cameras.txt 2>&1 &
    PID=$!

    # Verificar si el PID es válido antes de escribirlo
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        echo $PID > "$PIDFILE"
        if [ -f "$PIDFILE" ]; then
            echo "status_cameras.sh iniciado con PID $PID"
            echo "PID file creado en: $PIDFILE"
            echo "Log file: /tmp/status_cameras.txt"
        else
            echo "ERROR: No se pudo crear el archivo PID en $PIDFILE"
            exit 1
        fi
    else
        echo "ERROR: No se pudo iniciar el script correctamente o el PID no es válido."
        exit 1
    fi
    exit 0
elif [ "$1" == "2" ]; then
    # Detener el script usando el PID guardado
    if [ -f "$PIDFILE" ]; then
        PID=$(cat "$PIDFILE")
        echo "Deteniendo status_cameras.sh con PID: $PID"
        
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID" && echo "status_cameras.sh detenido exitosamente"
        else
            echo "El proceso con PID $PID no está corriendo"
        fi
            
        rm -f "$PIDFILE"
        rm -f /tmp/camerasMQTT.txt
        rm -f /tmp/status_cameras.txt
        echo "Archivos temporales limpiados"
    else
        echo "No se encontró el archivo de PID en $PIDFILE"
        echo "¿Está corriendo el script?"
    fi
    exit 0
elif [ "$1" == "status" ]; then
    # Mostrar estado del script
    if [ -f "$PIDFILE" ]; then
        PID=$(cat "$PIDFILE")
        echo "=== Estado de status_cameras.sh ==="
        echo "PID file: $PIDFILE"
        echo "PID: $PID"
        
        if kill -0 "$PID" 2>/dev/null; then
            echo "Estado: CORRIENDO"
            echo "Proceso activo con PID $PID"
        else
            echo "Estado: DETENIDO"
            echo "El proceso con PID $PID no está activo"
        fi
        
        if [ -f "/tmp/status_cameras.txt" ]; then
            echo "Log file: /tmp/status_cameras.txt"
            echo "Últimas líneas del log:"
            tail -5 /tmp/status_cameras.txt 2>/dev/null || echo "No se puede leer el log"
        fi
    else
        echo "=== Estado de status_cameras.sh ==="
        echo "Estado: NO INICIADO"
        echo "No se encontró archivo PID en $PIDFILE"
    fi
    exit 0
elif [ "$1" == "run" ]; then
    # Cargar configuración centralizada
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/config.sh"
    HEARTBEAT_INTERVAL=10
    last_heartbeat=0

    while true; do
        lsusb > /tmp/status_cameras.txt
        sleep 1
        drivs=$(cat /tmp/status_cameras.txt)

        # NIKON
        if echo "$drivs" | grep -q "Nikon Corp. D5600"; then
            send_mqtt_with_log "$JETSON_NAME/$NIKON_TOPIC_BASE/status" "CONECTADA"
            process_files "/home/indicatice2/Desktop/ASTRODEVICES/NIKONFILE" "$JETSON_NAME/$NIKON_TOPIC_BASE/files" "NEF"
        else
            send_mqtt_with_log "$JETSON_NAME/$NIKON_TOPIC_BASE/status" "DESCONECTADA"
        fi

        # ALPY
        if echo "$drivs" | grep -E -q "Starlight Xpress|Cypress Semiconductor Corp. Unprogrammed CY7C65642 hub"; then
            send_mqtt_with_log "$JETSON_NAME/$ALPY_TOPIC_BASE/status" "CONECTADA"
            process_files "/home/indicatice2/Desktop/ASTRODEVICES/ALPYFILE" "$JETSON_NAME/$ALPY_TOPIC_BASE/files" "fits"
        else
            send_mqtt_with_log "$JETSON_NAME/$ALPY_TOPIC_BASE/status" "DESCONECTADA"
        fi

        # QHY
        if echo "$drivs" | grep -E -q "Terminus Technology Inc. FE 2.1 7-port Hub|Future Technology Devices International, Ltd FT2232C/D/H"; then
            send_mqtt_with_log "$JETSON_NAME/$QHY_TOPIC_BASE/status" "CONECTADA"
            process_files "/home/indicatice2/Desktop/ASTRODEVICES/QHYCCDFILE" "$JETSON_NAME/$QHY_TOPIC_BASE/files" "fits"
        else
            send_mqtt_with_log "$JETSON_NAME/$QHY_TOPIC_BASE/status" "DESCONECTADA"
        fi

        # Enviar heartbeat cada 10 segundos
        now=$(date +%s)
        if [ $((now - last_heartbeat)) -ge $HEARTBEAT_INTERVAL ]; then
            send_mqtt "$JETSON_NAME/heartbeat" "$now"
            log_message "$CAMERAS_LOG" "Heartbeat enviado: $now"
            last_heartbeat=$now
        fi
        sleep 2
    done
    exit 0
else
    echo "Uso: $0 1 (iniciar) | $0 2 (detener) | $0 status (ver estado)"
    exit 1
fi