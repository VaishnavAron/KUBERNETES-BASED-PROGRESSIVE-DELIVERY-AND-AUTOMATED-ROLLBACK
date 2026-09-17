#!/bin/bash
PID_FILE="/tmp/btech-demo-pids.txt"

echo "======================================================================"
echo " Stopping Progressive Delivery Services..."
echo "======================================================================"

if [ -f "$PID_FILE" ]; then
    while read -r pid; do
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null && echo "[-] Stopped PID: $pid" || true
        fi
    done < "$PID_FILE"
    rm -f "$PID_FILE"
fi

pkill -f "kubectl port-forward" 2>/dev/null || true
pkill -f "kubectl argo rollouts dashboard" 2>/dev/null || true
pkill -f "socat TCP-LISTEN:3101" 2>/dev/null || true
pkill -f "python3 portal/server.py" 2>/dev/null || true

echo "======================================================================"
echo " All services stopped."
echo "======================================================================"
