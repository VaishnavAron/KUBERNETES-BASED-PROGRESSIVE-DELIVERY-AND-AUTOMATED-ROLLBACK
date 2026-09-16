#!/bin/bash
# ==============================================================================
# BTech Major Project: Progressive Delivery & Automated Rollback
# Single-Command Setup Script for Ubuntu 22.04 / 24.04 LTS (AWS EC2)
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "======================================================================"
echo " Starting Progressive Delivery Environment Setup on AWS EC2"
echo " Project Root: ${PROJECT_ROOT}"
echo " Local Time:   $(date)"
echo "======================================================================"

# ------------------------------------------------------------------------------
# [STEP 1/10] System Packages & Prerequisites
# ------------------------------------------------------------------------------
echo -e "\n\033[1;34m[STEP 1/10] Updating system packages and installing prerequisites...\033[0m"
sudo apt-get update -y
sudo apt-get install -y \
    curl \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    python3 \
    python3-pip \
    python3-flask \
    git \
    jq \
    conntrack

# Ensure Flask is available
if ! python3 -c "import flask" &> /dev/null; then
    echo "Installing Flask via pip..."
    sudo pip3 install flask --break-system-packages 2>/dev/null || sudo pip3 install flask || true
fi

# ------------------------------------------------------------------------------
# [STEP 2/10] Docker Engine Installation & User Group Configuration
# ------------------------------------------------------------------------------
echo -e "\n\033[1;34m[STEP 2/10] Setting up Docker Engine...\033[0m"
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing official Docker Engine..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh
    rm -f /tmp/get-docker.sh
else
    echo "Docker is already installed ($(docker --version)). Skipping installation."
fi

# Add current user to docker group and start service
sudo usermod -aG docker "$USER" || true
sudo systemctl enable docker
sudo systemctl start docker

# Ensure current session has permissions to the docker socket immediately
sudo chmod 666 /var/run/docker.sock || true

echo "Docker verification:"
docker info > /dev/null && echo " Docker daemon is active and accessible."

# ------------------------------------------------------------------------------
# [STEP 3/10] Install Kind (Kubernetes-in-Docker) v0.27.0
# ------------------------------------------------------------------------------
echo -e "\n\033[1;34m[STEP 3/10] Installing Kind (v0.27.0, Linux amd64)...\033[0m"
KIND_BIN="/usr/local/bin/kind"
if [ ! -f "$KIND_BIN" ] || ! "$KIND_BIN" --version 2>&1 | grep -q "0.27.0"; then
    echo "Downloading kind v0.27.0..."
    curl -Lo /tmp/kind https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-amd64
    chmod +x /tmp/kind
    sudo mv /tmp/kind "$KIND_BIN"
    echo "Kind v0.27.0 installed successfully to ${KIND_BIN}."
else
    echo "Kind v0.27.0 is already installed. Skipping."
fi

# ------------------------------------------------------------------------------
# [STEP 4/10] Install kubectl (Latest Stable, Linux amd64)
# ------------------------------------------------------------------------------
echo -e "\n\033[1;34m[STEP 4/10] Installing kubectl...\033[0m"
KUBECTL_BIN="/usr/local/bin/kubectl"
if ! command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    echo "Downloading kubectl (${KUBECTL_VERSION})..."
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl "$KUBECTL_BIN"
    echo "kubectl installed successfully to ${KUBECTL_BIN}."
else
    echo "kubectl is already installed ($(kubectl version --client --short 2>/dev/null || kubectl version --client)). Skipping."
fi

# ------------------------------------------------------------------------------
# [STEP 5/10] Install kubectl-argo-rollouts plugin (v1.10.0, Linux amd64)
# ------------------------------------------------------------------------------
echo -e "\n\033[1;34m[STEP 5/10] Installing kubectl-argo-rollouts plugin (v1.10.0)...\033[0m"
PLUGIN_BIN="/usr/local/bin/kubectl-argo-rollouts"
if [ ! -f "$PLUGIN_BIN" ]; then
    echo "Downloading argo-rollouts plugin v1.10.0..."
    curl -Lo /tmp/kubectl-argo-rollouts https://github.com/argoproj/argo-rollouts/releases/download/v1.10.0/kubectl-argo-rollouts-linux-amd64
    chmod +x /tmp/kubectl-argo-rollouts
    sudo mv /tmp/kubectl-argo-rollouts "$PLUGIN_BIN"
    echo "kubectl-argo-rollouts plugin installed to ${PLUGIN_BIN}."
else
    echo "kubectl-argo-rollouts plugin is already installed. Skipping."
fi

# ------------------------------------------------------------------------------
# [STEP 6/10] Create Kind Cluster 'rollouts-demo'
# ------------------------------------------------------------------------------
echo -e "\n\033[1;34m[STEP 6/10] Creating Kind Cluster 'rollouts-demo'...\033[0m"
if kind get clusters 2>/dev/null | grep -q "^rollouts-demo$"; then
    echo "Cluster 'rollouts-demo' already exists. Skipping creation."
else
    echo "Creating single-node Kind cluster 'rollouts-demo'..."
    kind create cluster --name rollouts-demo
fi

kubectl cluster-info --context kind-rollouts-demo

# ------------------------------------------------------------------------------
# [STEP 7/10] Deploy Argo Rollouts Controller & CRDs
# ------------------------------------------------------------------------------
echo -e "\n\033[1;34m[STEP 7/10] Applying Argo Rollouts Controller & CRDs...\033[0m"
kubectl apply -n argo-rollouts -f "${PROJECT_ROOT}/manifests/argo-rollouts/install.yaml"

echo "Waiting for Argo Rollouts controller to become available (up to 120s)..."
kubectl wait --for=condition=Available --timeout=120s deployment/argo-rollouts -n argo-rollouts

# ------------------------------------------------------------------------------
# [STEP 8/10] Deploy Monitoring Stack (Prometheus, Blackbox, Grafana)
# ------------------------------------------------------------------------------
echo -e "\n\033[1;34m[STEP 8/10] Applying Monitoring Manifests (Prometheus, Blackbox Exporter, Grafana)...\033[0m"
kubectl apply -f "${PROJECT_ROOT}/manifests/monitoring/"

echo "Waiting for Prometheus deployment to be available..."
kubectl wait --for=condition=Available --timeout=180s deployment/prometheus -n monitoring

echo "Waiting for Blackbox Exporter to be available..."
kubectl wait --for=condition=Available --timeout=120s deployment/blackbox-exporter -n monitoring

echo "Waiting for Grafana deployment to be available..."
kubectl wait --for=condition=Available --timeout=120s deployment/grafana -n monitoring

# ------------------------------------------------------------------------------
# [STEP 9/10] Deploy Application (Canary Rollout & AnalysisTemplate)
# ------------------------------------------------------------------------------
echo -e "\n\033[1;34m[STEP 9/10] Applying Application Manifests (Rollout & AnalysisTemplate)...\033[0m"
kubectl apply -f "${PROJECT_ROOT}/manifests/app/"

echo "Waiting for Canary Rollout baseline to stabilize..."
kubectl argo rollouts status canary-demo --timeout 120s || true

# ------------------------------------------------------------------------------
# [STEP 10/10] Final Health Verification & Instructions
# ------------------------------------------------------------------------------
echo -e "\n\033[1;32m[STEP 10/10] Verification Complete! Current Cluster Pods:\033[0m"
kubectl get pods -A

echo "======================================================================"
echo -e "\033[1;32m SUCCESS! Progressive Delivery Environment is Ready.\033[0m"
echo "======================================================================"
echo "Next step: Start all background services and the Operations Console:"
echo "    ./scripts/ec2-start.sh"
echo "======================================================================"
