# BTech Major Project: Progressive Delivery and Automated Rollback for Containerized Applications

## Overview
This project implements an end-to-end cloud-native **Progressive Delivery & Automated Rollback** platform using **Kubernetes**, **Argo Rollouts**, **Prometheus**, and **Grafana**, controlled via an interactive **Click-to-Deploy Operations Console** powered by a lightweight Python Flask backend.

Instead of traditional all-at-once ("big bang") deployments, new containerized versions are introduced incrementally through canary traffic slicing. During each stage, the system enforces an **observation window** where live Prometheus telemetry is evaluated by an Argo Rollouts `AnalysisTemplate`.
- **Healthy releases** pass metric checks and are progressively promoted ($20\% \to 40\% \to 60\% \to 80\% \to 100\%$).
- **Degraded or slow releases** trigger metric failures, immediately aborting the rollout and safely rolling back to the stable replica set with zero downtime.

---

## Active Architecture & Endpoints

| Component | Role | Local URL / Port |
| :--- | :--- | :--- |
| **Operations Console** | Interactive 1-Click Flask Portal | [http://localhost:5000](http://localhost:5000) |
| **Argo Rollouts UI** | Official Rollout Controller Dashboard | [http://localhost:3100/rollouts](http://localhost:3100/rollouts) |
| **Grafana** | Live Observability & Telemetry View | [http://localhost:3000](http://localhost:3000) |
| **Prometheus** | Metrics Collection & Analysis Data Source | [http://localhost:9090](http://localhost:9090) |
| **Rollouts Demo App** | Target Containerized Workload | [http://localhost:8080](http://localhost:8080) |

---

## Zero-Terminal Faculty Demonstration Workflow

> [!IMPORTANT]
> **No Terminal Interaction Needed During Demo!**  
> Everything happens entirely inside your browser from the **Operations Console** at `http://localhost:5000`. You do **not** need to touch the terminal or copy-paste commands during the presentation.

### 1. Launch All Services (One-Time Startup)
In PowerShell:
```powershell
.\scripts\start-all.ps1
# Or manually run: python portal/server.py
```
This automatically verifies the Kubernetes cluster, establishes the background port-forward tunnels, launches the Flask backend, and opens your browser directly to `http://localhost:5000`.

### 2. Live Demo: Scenario A — Successful Canary Promotion (Happy Path)
1. In the browser dashboard, click **"Run Successful Canary Promotion"**.
2. **What Happens Automatically:**
   - The button shows a spinner (`Deploying Canary (Yellow)...`) and triggers `POST /api/demo/success`.
   - The canary receives 20% traffic while stable retains 80%.
   - The live metric cards immediately update to `Traffic Allocation: 20%` and `Phase: Progressing`.
   - The 10s observation window elapses, Prometheus collects healthy probe metrics, and `AnalysisRun` passes (`SLA ≥ 95%`).
   - The system automatically promotes through 40% $\to$ 60% $\to$ 80% $\to$ 100% full promotion.
   - The embedded Argo Rollouts UI below reflects every step live with zero page refreshes.

### 3. Live Demo: Scenario B — Faulty Canary & Automated Rollback (Failure Path)
1. In the browser dashboard, click **"Run Faulty Canary & Rollback"**.
2. **What Happens Automatically:**
   - The button shows a spinner (`Deploying Faulty (Bad-Red)...`) and triggers `POST /api/demo/rollback`.
   - Canary receives 20% traffic and throws HTTP 500 errors.
   - Prometheus probe success rate drops drastically (`SLA < 95% Fail`).
   - Argo Rollouts AnalysisTemplate assesses metric failure (`failureLimit: 1` exceeded).
   - Rollout status shifts to `✖ Degraded / Aborted` in RED.
   - The bad canary pods are terminated, traffic drops to 0%, and 100% of production traffic remains safely on stable `blue` with **zero user downtime**.

### 4. Restore Baseline (Clean State)
Click **"Restore Baseline (Blue)"** on the dashboard to return the rollout to a clean `100% stable` baseline at any point.

---

## Project Directory & Files to Keep for Final Submission

```
btech final project/
├── bin/
│   ├── kind.exe                       # Local Kubernetes cluster engine
│   └── kubectl-argo-rollouts.exe      # Official Argo Rollouts kubectl CLI plugin
├── manifests/
│   ├── argo-rollouts/
│   │   └── install.yaml               # Official Argo Rollouts controller & CRDs
│   ├── monitoring/
│   │   ├── prometheus.yaml            # Prometheus scraping & RBAC manifests
│   │   ├── blackbox-exporter.yaml     # Live HTTP probing exporter
│   │   ├── grafana.yaml               # Grafana deployment & datasource provisioning
│   │   └── dashboard.json             # Pre-configured Grafana telemetry dashboard
│   └── app/
│       ├── canary-rollout.yaml        # Rollout resource with canary steps & analysis
│       └── analysis-template.yaml     # Prometheus metric analysis definition
├── portal/
│   ├── index.html                     # Polished, interactive light-theme SRE console
│   └── server.py                      # Flask API backend (serves UI & executes actions)
├── rollouts-demo/                     # Cloned official Argo Rollouts demo repository
├── scripts/
│   ├── start-all.ps1                  # Launches all port-forwards and Flask portal
│   ├── demo-canary-success.ps1        # PowerShell CLI alternative for Scenario A
│   ├── demo-canary-rollback.ps1       # PowerShell CLI alternative for Scenario B
│   └── restore-baseline.ps1           # Resets to baseline stable version
└── README.md                          # Project documentation and guide
```

---

## Technical Viva & Defense Q&A

**Q1: What problem does this project solve?**  
A: It mitigates the operational blast radius of software releases. Instead of updating 100% of pods at once, canary progressive delivery routes a small percentage of live traffic to the new revision, analyzes telemetry via Prometheus during an observation window, and automatically aborts if health degradations occur.

**Q2: How does the 1-Click Operations Console work?**  
A: The frontend interacts with a lightweight Python Flask API (`portal/server.py`). When actions are clicked, Flask invokes the rollout lifecycle via `kubectl argo rollouts` commands and continuously synchronizes Kubernetes rollout CRD status and Prometheus telemetry to power real-time metric cards and pipeline state diagrams.

**Q3: How does the automated rollback trigger?**  
A: Argo Rollouts executes an `AnalysisTemplate` connecting to Prometheus. It executes PromQL queries (`avg_over_time(probe_success) >= 0.95`). When the canary generates errors, the metric check fails, exceeding `failureLimit`. The Argo Rollouts controller then marks the rollout as `Degraded`, reduces canary traffic weight to 0%, and scales down canary pods while keeping stable pods active.
