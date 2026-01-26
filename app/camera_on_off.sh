#!/bin/bash

source /home/indicatic-e1/Desktop/.env

#usage: ./camera_on_off.sh on alpy
#usage: ./camera_on_off.sh off alpy qhy nikon
#El indice 0 es el que esta abajo de la entrada usb

accion="$1"
shift
nombres=("$@")

# Mapeo de nombres a índices
declare -A nombre_a_indice
nombre_a_indice=( ["alpy"]=0 ["qhy"]=1 ["nikon"]=2 )

IP="$STRIP_IP"

for nombre in "${nombres[@]}"; do
    idx="${nombre_a_indice[$nombre]}"
    if [[ -z "$idx" && "$nombre" != "0" ]]; then
        echo "Nombre de dispositivo desconocido: $nombre"
        continue
    fi
    /home/indicatic-e1/.local/bin/kasa --type strip --host $IP --username "$STRIP_USER" --password "$STRIP_PASSWORD" "$accion" --index "$idx"
done
