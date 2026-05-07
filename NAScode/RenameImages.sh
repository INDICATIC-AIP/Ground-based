#!/bin/bash
# Renombra imágenes en el NAS al formato compacto ISO:
#   ALPY  : ccd_sx_825_*_2026-04-01T13-07-50_001.fits  → 20260401T130750.fits
#   QHY   : qhy_16200_Bs_*_2026-04-01T13-07-50_001.fits → 20260401T130750_B.fits
#   Nikon : image_20260401_130750.NEF                   → 20260401T130750.NEF

NAS_BASE="/var/services/homes/INDICATIC"
STATIONS=("Pacifico/INDICATIC/UTP" "Caribe" "Punto_medio/STRE")

rename_fits_alpy() {
    local dir="$1"
    [[ -d "$dir" ]] || return
    find "$dir" -maxdepth 1 -name "*.fits" | while read -r f; do
        base=$(basename "$f")
        [[ "$base" =~ ^[0-9]{8}T[0-9]{6}\.fits$ ]] && continue
        if [[ "$base" =~ ([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2})-([0-9]{2})-([0-9]{2}) ]]; then
            dt="${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}T${BASH_REMATCH[4]}${BASH_REMATCH[5]}${BASH_REMATCH[6]}"
            dest="$(dirname "$f")/${dt}.fits"
            [[ -e "$dest" ]] && { echo "SKIP (exists): $base"; continue; }
            mv "$f" "$dest" && echo "RENAMED: $base → $(basename "$dest")"
        fi
    done
}

rename_fits_qhy() {
    local dir="$1"
    local filter="$2"
    [[ -d "$dir" ]] || return
    find "$dir" -maxdepth 1 -name "*.fits" | while read -r f; do
        base=$(basename "$f")
        [[ "$base" =~ ^[0-9]{8}T[0-9]{6}${filter}\.fits$ ]] && continue
        if [[ "$base" =~ ([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2})-([0-9]{2})-([0-9]{2}) ]]; then
            dt="${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}T${BASH_REMATCH[4]}${BASH_REMATCH[5]}${BASH_REMATCH[6]}"
            dest="$(dirname "$f")/${dt}${filter}.fits"
            [[ -e "$dest" ]] && { echo "SKIP (exists): $base"; continue; }
            mv "$f" "$dest" && echo "RENAMED: $base → $(basename "$dest")"
        fi
    done
}

rename_nef() {
    local dir="$1"
    [[ -d "$dir" ]] || return
    find "$dir" -maxdepth 1 -name "*.NEF" | while read -r f; do
        base=$(basename "$f")
        [[ "$base" =~ ^[0-9]{8}T[0-9]{6}\.NEF$ ]] && continue
        # image_YYYYMMDD_HHMMSS.NEF (formato desplegado antiguo)
        if [[ "$base" =~ ^image_([0-9]{8})_([0-9]{6})\.NEF$ ]]; then
            dest="$(dirname "$f")/${BASH_REMATCH[1]}T${BASH_REMATCH[2]}.NEF"
            [[ -e "$dest" ]] && { echo "SKIP (exists): $base"; continue; }
            mv "$f" "$dest" && echo "RENAMED: $base → $(basename "$dest")"
        # YYYY-MM-DD_HH-MM-SS.NEF (formato local antiguo)
        elif [[ "$base" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})_([0-9]{2})-([0-9]{2})-([0-9]{2})\.NEF$ ]]; then
            dt="${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}T${BASH_REMATCH[4]}${BASH_REMATCH[5]}${BASH_REMATCH[6]}"
            dest="$(dirname "$f")/${dt}.NEF"
            [[ -e "$dest" ]] && { echo "SKIP (exists): $base"; continue; }
            mv "$f" "$dest" && echo "RENAMED: $base → $(basename "$dest")"
        fi
    done
}

for station in "${STATIONS[@]}"; do
    base="${NAS_BASE}/${station}"
    echo "=== Station: $station ==="
    rename_fits_alpy "${base}/ALPY/ALPYimages"
    rename_nef       "${base}/NIKON/NIKONimages"
    for filter in U B V R I; do
        rename_fits_qhy "${base}/QHYCCD/${filter}-Bessell/QHY_${filter}_images" "$filter"
    done
done
