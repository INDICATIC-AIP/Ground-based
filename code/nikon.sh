#!/bin/bash

# ============================================================
# nikon.sh — Captura continua con Nikon D5600 via gphoto2
# ============================================================
#gphoto2 --get-config shutterspeed

# ALPY (SX-825) — INDI driver:

# Mínimo: 0.001 segundos
# En el .esq se pone como: <Exposure>0.001</Exposure> 10
# Nikon D5600 — gphoto2:

# Mínimo: 0,0002s (lo que viste como Choice 0)
# En nikon.sh se pone como: SHUTTER="0,0002s" 10,0000s

NIKON_ID="04b0:043f"
SAVEDIR="/home/indicatice2/Desktop/ASTRODEVICES/NIKONFILE"
SHUTTER="${1:-10,0000s}"
ISO="${2:-800}"
INTERVAL="${3:-0}"
WAIT_SECS="${4:-0}"
MAX_FAILS=3       # Fallos consecutivos antes de reset USB
MAX_RESETS=5      # Resets totales sin éxito → salir para que watchdog reinicie

LOGFILE="/tmp/logNikon.txt"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"; }

mkdir -p "$SAVEDIR"

log "[INICIO] nikon.sh arrancado (PID $$) — shutter=${SHUTTER} ISO=${ISO} INTERVAL=${INTERVAL}s"

# ============================================================
# Reset inicial + limpieza GVFS
# ============================================================
pkill -9 -f gvfsd-gphoto2 2>/dev/null
pkill -9 -f gvfs-mtp-volume-monitor 2>/dev/null
sleep 2

# Reset USB solo si el dispositivo ya está en el bus
if lsusb | grep -q "$NIKON_ID"; then
    log "[RESET] Reset USB inicial..."
    sudo /usr/bin/usbreset $NIKON_ID
    sleep 12
else
    log "[INFO] Nikon no detectada en USB aún, esperando encendido..."
fi

# Reintentar detección hasta 10 veces (5 min) para dar tiempo al encendido
for attempt in $(seq 1 10); do
    if gphoto2 --auto-detect 2>/dev/null | grep -q "Nikon"; then
        log "[OK] Nikon detectada (intento $attempt)."
        break
    fi
    if [ "$attempt" -eq 10 ]; then
        log "[ERROR] Nikon no detectada tras 10 intentos. Saliendo."
        exit 1
    fi
    log "[INFO] Nikon no detectada, reintentando en 30s ($attempt/10)..."
    sleep 30
done

# Configuración inicial
gphoto2 --set-config capturetarget=0
gphoto2 --set-config shutterspeed="$SHUTTER"
gphoto2 --set-config iso="$ISO"
log "[OK] Cámara configurada — RAM, shutterspeed=${SHUTTER}, ISO=${ISO}"

trap 'log "Señal recibida, saliendo."; exit 0' SIGUSR1 SIGTERM SIGINT

if [ "$WAIT_SECS" -gt 0 ]; then
    log "[INFO] Esperando ${WAIT_SECS}s hasta hora de inicio..."
    sleep "$WAIT_SECS"
fi

FAIL_COUNT=0
RESET_COUNT=0

while true; do
    # Asegurar que gvfs no despertó (ni gphoto2 ni MTP)
    pkill -f gvfsd-gphoto2 2>/dev/null
    pkill -f gvfs-mtp-volume-monitor 2>/dev/null
    sleep 3

    TIMESTAMP=$(date +%Y%m%dT%H%M%S)
    OUTFILE="${SAVEDIR}/${TIMESTAMP}.NEF"

    gphoto2 --capture-image-and-download --filename "$OUTFILE" --force-overwrite 2>&1
    STATUS=$?

    # gphoto2 puede retornar 0 aunque el download falle (PTP timeout silencioso).
    # Verificar que el archivo exista y tenga al menos 1 MB.
    FILE_SIZE=$(stat --format=%s "$OUTFILE" 2>/dev/null || echo 0)
    if [ "$FILE_SIZE" -lt 1000000 ]; then
        STATUS=1
        log "[ERROR] Archivo ausente o incompleto (${FILE_SIZE} bytes) — tratando como fallo"
        rm -f "$OUTFILE"
    fi

    if [ $STATUS -ne 0 ]; then
        FAIL_COUNT=$((FAIL_COUNT + 1))
        log "[ERROR] Fallo captura #${FAIL_COUNT} — ${OUTFILE}"

        if [ $FAIL_COUNT -ge $MAX_FAILS ]; then
            RESET_COUNT=$((RESET_COUNT + 1))
            log "[RESET] Reset USB #${RESET_COUNT}/${MAX_RESETS}..."

            pkill -9 -f gvfsd-gphoto2 2>/dev/null
            sleep 2
            sudo /usr/bin/usbreset $NIKON_ID
            sleep 15

            if ! gphoto2 --auto-detect 2>/dev/null | grep -q "Nikon"; then
                log "[ERROR] Nikon no detectada tras reset #${RESET_COUNT}."
            else
                gphoto2 --set-config capturetarget=0
                gphoto2 --set-config shutterspeed="$SHUTTER"
                gphoto2 --set-config iso="$ISO"
                log "[OK] Cámara reconfigurada tras reset."
            fi

            FAIL_COUNT=0

            # Si ya intentamos demasiados resets, salir limpiamente
            # para que el watchdog reinicie el proceso desde cero
            if [ $RESET_COUNT -ge $MAX_RESETS ]; then
                log "[FATAL] ${MAX_RESETS} resets sin recuperar la cámara. Saliendo para reinicio por watchdog."
                exit 2
            fi
        fi
    else
        log "[OK] Guardada: $(basename $OUTFILE)"
        FAIL_COUNT=0
        RESET_COUNT=0
        sync
    fi

    sleep $INTERVAL &
    wait $!
done