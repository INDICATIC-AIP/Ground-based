#!/bin/bash
# Start indiserver for this station.
# Usage: ./IndiServ.sh <driver> <device_string>
#   indicatice2  →  ./IndiServ.sh indi_sx_ccd  "SX CCD"
#   indicatic-e1 →  ./IndiServ.sh indi_qhy_ccd "QHY"

DRIVER="${1:-indi_sx_ccd}"
DEVICE_STR="${2:-SX CCD}"

pkill -TERM -f "indiserver|$DRIVER" 2>/dev/null || true
sleep 2
pkill -KILL -f "indiserver|$DRIVER" 2>/dev/null || true
rm -f /tmp/indiserver_main

echo "Starting INDI server ($DRIVER)..."
indiserver -u /tmp/indiserver_main -p 7624 -v "$DRIVER" > ~/logINDI.txt 2>&1 &
sleep 5

if ! pgrep -f 'indiserver.*-p 7624' > /dev/null; then
    echo "❌ INDI server (7624) failed."
    tail -n 40 ~/logINDI.txt 2>/dev/null
    exit 1
fi
echo "✅ INDI server running ($DRIVER on port 7624)."

echo "Waiting for $DEVICE_STR on INDI..."
for i in $(seq 1 12); do
    if indi_getprop -h localhost -p 7624 2>/dev/null | grep -q "$DEVICE_STR"; then
        echo "✅ $DEVICE_STR visible on INDI (attempt $i)."
        exit 0
    fi
    echo "$DEVICE_STR not visible yet ($i/12)..."
    sleep 5
done

echo "❌ $DEVICE_STR not visible on INDI after 60s. Check USB."
exit 1
