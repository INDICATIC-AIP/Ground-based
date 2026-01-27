#!/bin/bash
# ==============================================
# SCRIPT PRINCIPAL - MENÚ DE CONTROL DE CÁMARAS
# ==============================================
# Este script muestra un menú interactivo para:
# - Configurar ciclos automáticos por intervalo
# - Encender / apagar cámaras
# - Consultar estado de cámaras
#
# Usa scripts auxiliares:
# - variables.sh          → configuración global
# - camera_on_off.sh      → encendido/apagado
# - status_cameras.sh    → estado de cámaras
# ==============================================


# ===============================
# RUTAS BASE DEL SCRIPT
# ===============================
# SCRIPT_DIR obtiene la ruta absoluta del directorio
# donde se encuentra este script, sin importar desde
# dónde se ejecute.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Archivo de variables compartidas
VARIABLES_FILE="$SCRIPT_DIR/../AutoRun/variables.sh"

# Script encargado de encender/apagar cámaras
CAMERA_SCRIPT="$SCRIPT_DIR/camera_on_off.sh"

# Script encargado de mostrar estado de cámaras
STATUS_SCRIPT="$SCRIPT_DIR/status_cameras.sh"


# ===============================
# VERIFICACIÓN CRÍTICA
# ===============================
# Si variables.sh no existe, el sistema no puede continuar
# porque contiene configuración esencial (horarios, flags, etc.)
if [ ! -f "$VARIABLES_FILE" ]; then
    echo "ERROR: No se encontró variables.sh"
    echo "Ruta buscada:"
    echo "$VARIABLES_FILE"
    read -p "ENTER para salir..."
    exit 1
fi


# ===============================
# FUNCIÓN: CONFIGURAR CICLO AUTOMÁTICO
# ===============================
# Permite definir un intervalo de tiempo en minutos
# y guarda el horario de inicio y fin en variables.sh
set_cycle_interval() {
    clear
    echo "======================================"
    echo "   CICLO AUTOMÁTICO POR INTERVALO"
    echo "======================================"
    echo "1) 3 minutos"
    echo "2) 5 minutos"
    echo "3) 10 minutos"
    echo "4) 30 minutos"
    echo "5) 1 hora"
    echo "6) 3 horas"
    echo "7) 5 horas"
    echo "8) Personalizado (minutos)"
    echo "0) Volver"
    echo "--------------------------------------"
    read -p "Seleccione una opción: " opt

    # Asignación de minutos según la opción elegida
    case $opt in
        1) minutes=3 ;;
        2) minutes=5 ;;
        3) minutes=10 ;;
        4) minutes=30 ;;
        5) minutes=60 ;;
        6) minutes=180 ;;
        7) minutes=300 ;;
        8) read -p "Ingrese minutos: " minutes ;;
        0) return ;;
        *) echo "Opción inválida"; sleep 1; return ;;
    esac

    # Hora actual (inicio del ciclo)
    start_time=$(date +%H:%M)
    start_hour=$(date +%H)
    start_min=$(date +%M)

    # Hora final calculada en base a los minutos elegidos
    end_time=$(date -d "+$minutes minutes" +%H:%M)
    end_hour=$(date -d "+$minutes minutes" +%H)
    end_min=$(date -d "+$minutes minutes" +%M)

    # Se actualizan las variables dentro de variables.sh
    sed -i \
        -e "s/^BegingDefaultAllHour=.*/BegingDefaultAllHour=\"$start_hour\"/" \
        -e "s/^BegingDefaultAllMinute=.*/BegingDefaultAllMinute=\"$start_min\"/" \
        -e "s/^EndDefaultAllHour=.*/EndDefaultAllHour=\"$end_hour\"/" \
        -e "s/^EndDefaultAllMinute=.*/EndDefaultAllMinute=\"$end_min\"/" \
        "$VARIABLES_FILE"

    echo ""
    echo "✅ Ciclo configurado correctamente"
    echo "Inicio : $start_time"
    echo "Fin    : $end_time"
    echo ""
    read -p "ENTER para continuar..."
}


# ===============================
# SUBMENÚ DE CÁMARAS + CONFIRMACIÓN
# ===============================
# Esta función recibe la acción ("on" o "off")
# y permite seleccionar qué cámaras se afectan
camera_menu() {
    local action="$1"
    local action_text

    # Texto legible según la acción
    if [ "$action" = "on" ]; then
        action_text="ENCENDER"
    else
        action_text="APAGAR"
    fi

    clear
    echo "======================================"
    echo "   $action_text CÁMARAS"
    echo "======================================"
    echo "1) Todas"
    echo "2) Alpy"
    echo "3) QHY"
    echo "4) Nikon"
    echo "0) Volver"
    echo "--------------------------------------"
    read -p "Seleccione una opción: " cam

    # Definición de cámaras según selección
    case $cam in
        1)
            cams="alpy qhy nikon"
            cams_text="TODAS LAS CÁMARAS"
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
            echo "Opción inválida"
            sleep 1
            return
            ;;
    esac

    # Confirmación del usuario antes de ejecutar
    echo ""
    echo "⚠️  CONFIRMACIÓN"
    echo "--------------------------------------"
    echo "Está a punto de $action_text: $cams_text"
    echo ""
    read -p "¿Está seguro? (s/N): " confirm

    # Solo ejecuta si el usuario confirma con S o s
    if [[ "$confirm" =~ ^[sS]$ ]]; then
        "$CAMERA_SCRIPT" "$action" $cams

        # Verifica si el script falló
        if [ $? -ne 0 ]; then
            echo ""
            echo "🚨 ERROR: no se pudo ejecutar la acción"
        else
            echo ""
            echo "✅ Acción ejecutada correctamente"
        fi
    else
        echo ""
        echo "❌ Acción cancelada por el usuario"
    fi

    echo ""
    read -p "ENTER para continuar..."
}


# ===============================
# MENÚ PRINCIPAL
# ===============================
# Bucle infinito hasta que el usuario seleccione salir
while true; do
    clear
    now=$(date "+%Y-%m-%d %H:%M:%S")

    echo "================================================"
    echo "        MENU CAMARAS        [ $now ]"
    echo "================================================"
    echo "1) Configurar ciclo por intervalo"
    echo "2) Encender cámaras"
    echo "3) Apagar cámaras"
    echo "4) Estado de cámaras"
    echo "0) Salir"
    echo "------------------------------------------------"
    read -p "Seleccione una opción: " choice

    case $choice in
        1) set_cycle_interval ;;
        2) camera_menu "on" ;;
        3) camera_menu "off" ;;
        4)
            "$STATUS_SCRIPT" status
            read -p "ENTER para continuar..."
            ;;
        0)
            echo "Saliendo..."
            exit 0
            ;;
        *)
            echo "Opción inválida"
            sleep 1
            ;;
    esac
done
