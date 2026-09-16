#!/bin/bash
# ==============================================================================
# BTech Major Project: Progressive Delivery & Automated Rollback
# Background Services Startup Script (AWS EC2)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PID_FILE="/tmp/btech-demo-pids.txt"

echo "======================================================================"
echo " Starting Progressive Delivery Services in Background"
echo " Project Root: ${PROJECT_ROOT}"
echo "======================================================================"

# Clean up any previously stored PIDs
rm -f "$PID_FILE"
touch "$PID_FILE"

# 1. Start Argo Rollouts Dashboard (Port 3100) with resilient reconnect loop
nohup bash -c "while true; do kubectl argo rollouts dashboard --port 3100 --address 0.0.0.0 >/dev/null 2>&1; sleep 1; done" >/dev/null 2>&1 &
PID_ARGO=$!
echo "$PID_ARGO" >> "$PID_FILE"
echo "[+] Argo Rollouts Dashboard started (PID: $PID_ARGO, Port: 3100)"

# 2. Start Prometheus Port-Forward (Port 9090) with resilient reconnect loop
nohup bash -c "while true; do kubectl port-forward --address 0.0.0.0 svc/prometheus 9090:9090 -n monitoring >/dev/null 2>&1; sleep 1; done" >/dev/null 2>&1 &
PID_PROM=$!
echo "$PID_PROM" >> "$PID_FILE"
echo "[+] Prometheus port-forward started (PID: $PID_PROM, Port: 9090)"

# 3. Start Grafana Port-Forward (Port 3000) with resilient reconnect loop
nohup bash -c "while true; do kubectl port-forward --address 0.0.0.0 svc/grafana 3000:3000 -n monitoring >/dev/null 2>&1; sleep 1; done" >/dev/null 2>&1 &
PID_GRAF=$!
echo "$PID_GRAF" >> "$PID_FILE"
echo "[+] Grafana port-forward started (PID: $PID_GRAF, Port: 3000)"

# 4. Start Canary Demo App Port-Forward (Port 8080) with resilient reconnect loop
nohup bash -c "while true; do kubectl port-forward --address 0.0.0.0 svc/canary-demo 8080:80 >/dev/null 2>&1; sleep 1; done" >/dev/null 2>&1 &
PID_APP=$!
echo "$PID_APP" >> "$PID_FILE"
echo "[+] Canary Demo App port-forward started (PID: $PID_APP, Port: 8080)"

# 5. Start Python Flask Click-to-Deploy Backend (Port 5000)
cd "$PROJECT_ROOT"
nohup python3 portal/server.py > /tmp/flask-portal.log 2>&1 &
PID_FLASK=$!
echo "$PID_FLASK" >> "$PID_FILE"
echo "[+] Operations Console Flask backend started (PID: $PID_FLASK, Port: 5000)"

# Wait 2 seconds for sockets to bind
sleep 2

# Discover Public IP
PUBLIC_IP=$(curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null \
    || curl -s --connect-timeout 2 https://api.ipify.org 2>/dev/null \
    || curl -s --connect-timeout 2 http://checkip.amazonaws.com 2>/dev/null \
    || echo "<EC2-PUBLIC-IP>")

echo ""
echo "======================================================================"
echo -e "\033[1;32m All Progressive Delivery Services are LIVE in Background!\033[0m"
echo "======================================================================"
echo -e "\033[1;33m Operations Console (UI):     http://${PUBLIC_IP}:5000\033[0m"
echo -e "\033[1;33m Argo Rollouts Dashboard:     http://${PUBLIC_IP}:3100/rollouts\033[0m"
echo -e "\033[1;33m Grafana Observability:       http://${PUBLIC_IP}:3000\033[0m"
echo -e "\033[1;33m Prometheus Telemetry:        http://${PUBLIC_IP}:9090\033[0m"
echo -e "\033[1;33m Live Application Endpoint:   http://${PUBLIC_IP}:8080\033[0m"
echo "======================================================================"
echo "To view Flask server logs:  tail -f /tmp/flask-portal.log"
echo "To stop all services:       ./scripts/ec2-stop.sh"
echo "======================================================================"
