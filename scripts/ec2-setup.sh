#!/bin/bash
# ==============================================================================
# BTech Project: Progressive Delivery + Automated Rollback
# EC2 Setup Script (Ubuntu 22.04/24.04) — Idempotent
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "======================================================================"
echo " Setting up Progressive Delivery Environment"
echo " Project Root: ${PROJECT_ROOT}"
echo "======================================================================"

echo -e "\n[STEP 1/10] Installing system packages..."
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl apt-transport-https ca-certificates gnupg lsb-release \
    python3 python3-pip python3-flask git jq conntrack socat

echo -e "\n[STEP 2/10] Docker Engine..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sudo sh
fi
sudo usermod -aG docker "$USER" || true
sudo systemctl enable --now docker
sudo chmod 666 /var/run/docker.sock || true

echo -e "\n[STEP 3/10] kind v0.27.0..."
if ! command -v kind &> /dev/null; then
    curl -Lo /tmp/kind https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-amd64
    chmod +x /tmp/kind && sudo mv /tmp/kind /usr/local/bin/kind
fi

echo -e "\n[STEP 4/10] kubectl..."
if ! command -v kubectl &> /dev/null; then
    KV=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -Lo /tmp/kubectl "https://dl.k8s.io/release/${KV}/bin/linux/amd64/kubectl"
    chmod +x /tmp/kubectl && sudo mv /tmp/kubectl /usr/local/bin/kubectl
fi

echo -e "\n[STEP 5/10] kubectl-argo-rollouts plugin v1.10.0..."
if ! command -v kubectl-argo-rollouts &> /dev/null; then
    curl -Lo /tmp/kubectl-argo-rollouts \
      https://github.com/argoproj/argo-rollouts/releases/download/v1.10.0/kubectl-argo-rollouts-linux-amd64
    chmod +x /tmp/kubectl-argo-rollouts
    sudo mv /tmp/kubectl-argo-rollouts /usr/local/bin/kubectl-argo-rollouts
fi

echo -e "\n[STEP 6/10] kind cluster 'rollouts-demo'..."
if ! kind get clusters 2>/dev/null | grep -q "^rollouts-demo$"; then
    kind create cluster --name rollouts-demo
else
    echo "Cluster already exists."
fi
kubectl cluster-info --context kind-rollouts-demo

echo -e "\n[STEP 7/10] Argo Rollouts controller & CRDs..."
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side -n argo-rollouts -f "${PROJECT_ROOT}/manifests/argo-rollouts/install.yaml"
kubectl rollout status deployment/argo-rollouts -n argo-rollouts --timeout=180s

echo -e "\n[STEP 8/10] Monitoring stack..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "${PROJECT_ROOT}/manifests/monitoring/prometheus.yaml"
kubectl apply -f "${PROJECT_ROOT}/manifests/monitoring/blackbox-exporter.yaml"
kubectl apply -f "${PROJECT_ROOT}/manifests/monitoring/grafana.yaml"

kubectl rollout status deployment/prometheus -n monitoring --timeout=180s
kubectl rollout status deployment/blackbox-exporter -n monitoring --timeout=120s
kubectl rollout status deployment/grafana -n monitoring --timeout=120s

echo "Provisioning Grafana dashboard..."
python3 - <<PYEOF
p = "${PROJECT_ROOT}/manifests/monitoring/dashboard.json"
with open(p, 'rb') as f:
    data = f.read()
if data.startswith(b'\xef\xbb\xbf'):
    with open(p, 'wb') as f:
        f.write(data[3:])
    print('BOM stripped from dashboard.json')
else:
    print('No BOM found')
PYEOF

kubectl create configmap grafana-dashboards \
  --from-file=canary-dashboard.json="${PROJECT_ROOT}/manifests/monitoring/dashboard.json" \
  -n monitoring --dry-run=client -o yaml | kubectl apply -f -

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-provider
  namespace: monitoring
data:
  dashboards.yaml: |
    apiVersion: 1
    providers:
    - name: 'default'
      orgId: 1
      folder: ''
      type: file
      disableDeletion: false
      updateIntervalSeconds: 10
      options:
        path: /var/lib/grafana/dashboards
EOF

if ! kubectl get deployment grafana -n monitoring -o jsonpath='{.spec.template.spec.volumes[*].name}' | grep -q dash-json; then
  kubectl patch deployment grafana -n monitoring --type=json -p='[
    {"op":"add","path":"/spec/template/spec/volumes/-","value":{"name":"dash-provider","configMap":{"name":"grafana-dashboard-provider"}}},
    {"op":"add","path":"/spec/template/spec/volumes/-","value":{"name":"dash-json","configMap":{"name":"grafana-dashboards"}}},
    {"op":"add","path":"/spec/template/spec/containers/0/volumeMounts/-","value":{"name":"dash-provider","mountPath":"/etc/grafana/provisioning/dashboards"}},
    {"op":"add","path":"/spec/template/spec/containers/0/volumeMounts/-","value":{"name":"dash-json","mountPath":"/var/lib/grafana/dashboards"}}
  ]'
  kubectl rollout status deployment/grafana -n monitoring --timeout=120s
fi

echo -e "\n[STEP 9/10] Application + Services..."
kubectl apply -f "${PROJECT_ROOT}/manifests/app/analysis-template.yaml"
kubectl apply -f "${PROJECT_ROOT}/manifests/app/canary-rollout.yaml"

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: canary-demo
  labels: {app: canary-demo}
spec:
  type: ClusterIP
  ports:
  - {port: 80, targetPort: http, protocol: TCP, name: http}
  selector: {app: canary-demo}
---
apiVersion: v1
kind: Service
metadata:
  name: canary-demo-preview
  labels: {app: canary-demo}
spec:
  type: ClusterIP
  ports:
  - {port: 80, targetPort: http, protocol: TCP, name: http}
  selector: {app: canary-demo}
EOF

kubectl rollout status rollout/canary-demo --timeout=180s

echo -e "\n[STEP 10/10] Verification:"
kubectl get pods -A

echo ""
echo "======================================================================"
echo " SUCCESS! Environment ready."
echo " Next: ./scripts/ec2-start.sh"
echo "======================================================================"
