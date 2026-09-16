#!/bin/bash
# ==============================================================================
# BTech Major Project: Progressive Delivery & Automated Rollback
# Background Services Teardown Script (AWS EC2)
# ==============================================================================

PID_FILE="/tmp/btech-demo-pids.txt"

echo "======================================================================"
echo " Stopping Progressive Delivery Services..."
echo "======================================================================"

# 1. Kill tracked PIDs from file
if [ -f "$PID_FILE" ]; then
    echo "Terminating tracked service PIDs..."
    while read -r pid; do
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null && echo "[-] Stopped PID: $pid" || true
        fi
    done < "$PID_FILE"
    rm -f "$PID_FILE"
fi

# 2. Kill any stray port-forward or background dashboard loops
echo "Cleaning up any remaining port-forward and dashboard subshells..."
pkill -f "kubectl port-forward" 2>/dev/null || true
pkill -f "kubectl argo rollouts dashboard" 2>/dev/null || true
pkill -f "python3 portal/server.py" 2>/dev/null || true

echo "======================================================================"
echo -e "\033[1;32m All Progressive Delivery Services Stopped Successfully.\033[0m"
echo "======================================================================"
