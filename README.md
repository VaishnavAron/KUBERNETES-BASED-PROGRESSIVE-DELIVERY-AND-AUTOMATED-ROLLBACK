# BTech Major Project: Progressive Delivery and Automated Rollback for Containerized Applications

## Overview
This project implements an end-to-end cloud-native **Progressive Delivery & Automated Rollback** platform using **Kubernetes**, **Argo Rollouts**, **Prometheus**, and **Grafana**. 

Instead of traditional all-at-once ("big bang") deployments, new containerized versions are introduced incrementally through canary traffic slicing. During each stage, the system enforces an **observation window** where live Prometheus telemetry is evaluated by an Argo Rollouts `AnalysisTemplate`.
- **Healthy releases** pass metric checks and are progressively promoted ($20\% \to 40\% \to 60\% \to 80\% \to 100\%$).
- **Degraded or slow releases** trigger metric failures, immediately aborting the rollout and safely rolling back to the stable replica set with zero downtime.

---

## Active Architecture & Endpoints

| Component | Role | Local URL / Port |
| :--- | :--- | :--- |
| **Operations Console** | Unified SRE Light-Theme Portal | [http://localhost:5000](http://localhost:5000) |
| **Argo Rollouts UI** | Official Rollout Controller Dashboard | [http://localhost:3100/rollouts](http://localhost:3100/rollouts) |
| **Grafana** | Live Observability & Telemetry View | [http://localhost:3000](http://localhost:3000) |
| **Prometheus** | Metrics Collection & Analysis Data Source | [http://localhost:9090](http://localhost:9090) |
| **Rollouts Demo App** | Target Containerized Workload | [http://localhost:8080](http://localhost:8080) |

---

## Step-by-Step Demonstration Playbook

### 1. Start the Environment & Dashboards
To launch port-forwarding tunnels and open the portal:
```powershell
.\scripts\start-all.ps1
```

### 2. Scenario A — Successful Canary Promotion (Happy Path)
1. Trigger a healthy release update (`argoproj/rollouts-demo:yellow`):
   ```powershell
   .\scripts\demo-canary-success.ps1
   # Or directly:
   kubectl argo rollouts set image canary-demo canary-demo=argoproj/rollouts-demo:yellow
   ```
2. **Observation & Analysis:**
   - Traffic routes 20% to canary, 80% to stable.
   - Dwell period (10s) elapses.
   - Prometheus runs 3 consecutive metric checks (`avg_over_time(probe_success) >= 0.95`).
   - Checks pass (`AnalysisRun: Successful`).
   - Traffic advances to 40%, 60%, 80%, and final 100% promotion.
3. Monitor via CLI:
   ```powershell
   kubectl argo rollouts get rollout canary-demo --watch
   ```

### 3. Scenario B — Faulty Release & Automated Rollback (Failure Path)
1. Trigger a faulty release update (`argoproj/rollouts-demo:bad-red`):
   ```powershell
   .\scripts\demo-canary-rollback.ps1
   # Or directly:
   kubectl argo rollouts set image canary-demo canary-demo=argoproj/rollouts-demo:bad-red
   ```
2. **Observation & Automated Abort:**
   - Canary receives 20% traffic.
   - During observation, the canary returns HTTP 500 errors.
   - Prometheus records degraded probe success rate.
   - Argo Rollouts AnalysisTemplate evaluates the metric, identifies `success-rate < 0.95`, and reaches failure limit.
   - Rollout state transitions to `✖ Degraded / Aborted`.
   - The canary pods are immediately terminated and scaled down.
   - 100% of production traffic remains served by the stable baseline replica set with **zero user downtime**.

### 4. Restore Baseline (Clean State)
```powershell
.\scripts\restore-baseline.ps1
# Or:
kubectl argo rollouts undo canary-demo
```

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
│   └── index.html                     # Light-theme enterprise operational console
├── rollouts-demo/                     # Cloned official Argo Rollouts demo repository
├── scripts/
│   ├── start-all.ps1                  # Launches all port-forwards and portal
│   ├── demo-canary-success.ps1        # Runs Scenario A
│   ├── demo-canary-rollback.ps1       # Runs Scenario B
│   └── restore-baseline.ps1           # Resets to baseline stable version
└── README.md                          # Project documentation and guide
```

---

## Technical Viva & Defense Q&A

**Q1: What problem does this project solve?**  
A: It mitigates the operational blast radius of software releases. Instead of updating 100% of pods at once, canary progressive delivery routes a small percentage of live traffic to the new revision, analyzes telemetry via Prometheus during an observation window, and automatically aborts if health degradations occur.

**Q2: Why not just rollback through Git?**  
A: Git commits represent desired state changes, but do not provide runtime traffic shifting, automated metric evaluation, or instantaneous automated rollbacks based on real-time latency and error rates.

**Q3: How does the automated rollback trigger?**  
A: Argo Rollouts executes an `AnalysisTemplate` connecting to Prometheus. It executes PromQL queries (e.g. `avg_over_time(probe_success) >= 0.95`). When the canary generates errors, the metric check fails, exceeding `failureLimit`. The Argo Rollouts controller then marks the rollout as `Degraded`, reduces canary traffic weight to 0, and scales down canary pods while keeping stable pods active.
