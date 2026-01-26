#!/bin/bash

source /home/indicatic-e1/Desktop/.env

# Script para verificar el estado de las cámaras
# Uso: ./strip_status.sh [alpy|qhy|nikon]

camera_name="$1"
IP="$STRIP_IP"

# Mapeo de nombres a índices
declare -A nombre_a_indice
nombre_a_indice=( ["alpy"]=0 ["qhy"]=1 ["nikon"]=2 )

if [[ -z "$camera_name" ]]; then
    echo "Uso: $0 [alpy|qhy|nikon]"
    exit 1
fi

idx="${nombre_a_indice[$camera_name]}"
if [[ -z "$idx" ]]; then
    echo "Nombre de cámara desconocido: $camera_name"
    exit 1
fi

# Verificar el estado de la cámara
status=$(/home/indicatic-e1/.local/bin/kasa --type strip --host $IP --username "$STRIP_USER" --password "$STRIP_PASSWORD" state --index "$idx" 2>&1)

# Verificar si el comando fue exitoso (aunque haya warnings)
if [[ $? -eq 0 ]] || [[ "$status" == *"Device state: True"* ]] || [[ "$status" == *"Device state: False"* ]]; then
    if [[ "$status" == *"Device state: True"* ]]; then
        echo "on"
    elif [[ "$status" == *"Device state: False"* ]]; then
        echo "off"
    else
        echo "error"
    fi
else
    echo "error"
fi