#!/bin/bash

source /home/indicatic-e1/Desktop/.env

# Configuración centralizada MQTT para todos los monitores
# Este archivo se carga en cada monitor para evitar duplicación

# Configuración MQTT - usando variables del .env
LAPTOP="$LAPTOP_BROKER_IP"
SERVER="$SERVER_BROKER_IP"
MQTT_BROKERS=("$LAPTOP" "$SERVER")  # Array con ambos brokers
MQTT_PORT="${MQTT_PORT:-1883}"

# Credenciales por broker - usar arrays asociativos
declare -A MQTT_USERS
declare -A MQTT_PASSWORDS

# Configurar credenciales para cada broker desde .env
MQTT_USERS["$LAPTOP"]="$LAPTOP_USER"
MQTT_PASSWORDS["$LAPTOP"]="$LAPTOP_PASSWORD"

MQTT_USERS["$SERVER"]="$SERVER_USER"
MQTT_PASSWORDS["$SERVER"]="$SERVER_PASSWORD"

# Obtener nombre del Jetson desde .env o hostname automático
JETSON_NAME="${JETSON_NAME:-$(hostname)}"

# Topics base para cada cámara
ALPY_TOPIC_BASE="alpy"
NIKON_TOPIC_BASE="nikon"
QHY_TOPIC_BASE="qhy"

# Archivos de log
ALPY_LOG="/tmp/alpyMQTT.txt"
# NIKON_LOG="/tmp/nikonMQTT.txt"
QHY_LOG="/tmp/qhyMQTT.txt"
CAMERAS_LOG="/tmp/camerasMQTT.txt"

# Función para enviar MQTT (reutilizable) - envía a todos los brokers
send_mqtt() {
    local topic="$1"
    local message="$2"
    
    # Enviar a cada broker en el array
    for broker in "${MQTT_BROKERS[@]}"; do
        local user="${MQTT_USERS[$broker]}"
        local pass="${MQTT_PASSWORDS[$broker]}"
        
        echo "Intentando enviar a broker: $broker con usuario: $user"
        
        # Verificar conectividad antes de enviar
        if ping -c 1 -W 2 "$broker" > /dev/null 2>&1; then
            mosquitto_pub -h "$broker" -u "$user" -P "$pass" -t "$topic" -m "$message"
            if [ $? -eq 0 ]; then
                echo "✓ Mensaje enviado exitosamente a broker: $broker (user: $user)"
            else
                echo "✗ Error enviando mensaje a broker: $broker (user: $user)"
            fi
        else
            echo "✗ No se puede conectar a broker: $broker (sin conectividad)"
        fi
    done
}

# Función para logging con timestamp
# log_message() {
#     local log_file="$1" 
#     local message="$2"
#     echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$log_file"
# } 
log_message() {
    local log_file="$1"
    local message="$2"
    touch "$log_file"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$log_file"
    # Mantener solo las últimas 1000 líneas
    tail -n 1000 "$log_file" > "$log_file.tmp" && mv "$log_file.tmp" "$log_file"
}