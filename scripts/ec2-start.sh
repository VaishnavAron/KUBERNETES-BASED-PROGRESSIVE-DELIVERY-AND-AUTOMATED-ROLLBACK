#!/bin/bash
# ==============================================================================
# BTech Project: Start all background services (EC2)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PID_FILE="/tmp/btech-demo-pids.txt"

echo "======================================================================"
echo " Starting Progressive Delivery Services"
echo "======================================================================"

rm -f "$PID_FILE"
touch "$PID_FILE"

pkill -f "kubectl port-forward" 2>/dev/null || true
pkill -f "kubectl argo rollouts dashboard" 2>/dev/null || true
pkill -f "socat TCP-LISTEN:3101" 2>/dev/null || true
pkill -f "python3 portal/server.py" 2>/dev/null || true
sleep 2

nohup bash -c "while true; do kubectl argo rollouts dashboard --port 3100 >/dev/null 2>&1; sleep 1; done" >/dev/null 2>&1 &
echo "$!" >> "$PID_FILE"
echo "[+] Argo Rollouts dashboard (127.0.0.1:3100)"
sleep 3

nohup sudo socat TCP-LISTEN:3101,fork,reuseaddr TCP:127.0.0.1:3100 > /tmp/socat.log 2>&1 &
echo "$!" >> "$PID_FILE"
echo "[+] Socat bridge (0.0.0.0:3101 → 127.0.0.1:3100)"

nohup bash -c "while true; do kubectl port-forward --address 0.0.0.0 svc/prometheus 9090:9090 -n monitoring >/dev/null 2>&1; sleep 1; done" >/dev/null 2>&1 &
echo "$!" >> "$PID_FILE"
echo "[+] Prometheus (0.0.0.0:9090)"

nohup bash -c "while true; do kubectl port-forward --address 0.0.0.0 svc/grafana 3000:3000 -n monitoring >/dev/null 2>&1; sleep 1; done" >/dev/null 2>&1 &
echo "$!" >> "$PID_FILE"
echo "[+] Grafana (0.0.0.0:3000)"

nohup bash -c "while true; do kubectl port-forward --address 0.0.0.0 svc/canary-demo 8080:80 >/dev/null 2>&1; sleep 1; done" >/dev/null 2>&1 &
echo "$!" >> "$PID_FILE"
echo "[+] Canary demo app (0.0.0.0:8080)"

cd "$PROJECT_ROOT"
nohup python3 portal/server.py > /tmp/flask-portal.log 2>&1 &
echo "$!" >> "$PID_FILE"
echo "[+] Flask portal (0.0.0.0:5000)"

sleep 5

PUBLIC_IP=$(curl -s --connect-timeout 3 http://checkip.amazonaws.com 2>/dev/null | tr -d '\n')

echo ""
echo "======================================================================"
echo " ALL SERVICES LIVE"
echo "======================================================================"
echo " Operations Console:  http://${PUBLIC_IP}:5000"
echo " Argo Rollouts UI:    http://${PUBLIC_IP}:3101/rollouts"
echo " Grafana:             http://${PUBLIC_IP}:3000"
echo " Prometheus:          http://${PUBLIC_IP}:9090"
echo " Live App:            http://${PUBLIC_IP}:8080"
echo "======================================================================"
