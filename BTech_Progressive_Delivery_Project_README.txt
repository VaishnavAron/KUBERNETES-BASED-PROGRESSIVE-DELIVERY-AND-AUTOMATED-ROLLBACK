# BTech Major Project — Progressive Delivery & Automated Rollback

## Final Project Direction

**Project title:**
**Progressive Delivery and Automated Rollback for Containerized Applications Using Kubernetes and Argo Rollouts**

## Why this project

The project addresses the operational risk of releasing a new software version directly to all users.

A new release can be technically deployable and still produce:
- higher latency
- increased error rates
- service degradation
- unexpected runtime problems

The system therefore demonstrates controlled progressive delivery:

**New version → Canary → Observation/Analysis → Promote OR Abort/Rollback**

This is an engineering implementation project using established open-source technologies. Originality/research novelty is NOT a project requirement.

---

## Core Technology Stack

- Kubernetes — container orchestration
- Argo Rollouts — progressive rollout controller
- Canary deployment — gradual exposure strategy
- Prometheus — metrics collection and analysis data source
- Grafana — observability/visualization
- Docker — container image/runtime foundation
- kubectl + Argo Rollouts plugin — operational control

### Important UI decision

Do NOT make separate full UI pages for every technology.

Use:

1. **Argo Rollouts UI** as the main rollout/deployment control view.
2. **Grafana** as the monitoring/observability view.
3. **Prometheus** as the metrics/data backend and query source, not a major standalone product page.
4. **Argo CD is optional and currently NOT required.** It adds GitOps scope and should not be introduced unless there is a very clear reason.

---

## Official Starting Repositories

### Argo Rollouts
https://github.com/argoproj/argo-rollouts

### Official Rollouts Demo
https://github.com/argoproj/rollouts-demo

Use these as the primary implementation foundation.

The goal is not to write a rollout controller from scratch.

---

## Target End-to-End Flow

```text
Developer releases new version
            ↓
Container image / application version
            ↓
Kubernetes Rollout
            ↓
Canary version starts
            ↓
Small percentage of traffic
            ↓
Observation / measurement window
            ↓
Prometheus metrics
            ↓
Argo Analysis
            ↓
        ┌───────────────┐
        │               │
      Healthy       Unhealthy
        │               │
        ↓               ↓
 Increase traffic   Abort/Rollback
        │               │
        ↓               ↓
   25% → 50% → 100%   Stable version
        │
        ↓
     Promote
```

### Critical conceptual point

The system should NOT appear to decide immediately after sending a small traffic percentage.

It should communicate:

**traffic exposure → observation period → collect enough measurements → analysis → decision**

This is important in the UI, demo, report, and viva.

---

# Demo Scenarios

## Scenario A — Successful Deployment

1. Stable version is running.
2. New version is deployed.
3. Canary receives a small percentage of traffic.
4. The system waits/observes.
5. Prometheus collects metrics.
6. Analysis passes.
7. Canary traffic increases.
8. Eventually the new version is promoted to stable.

Example:

```text
Stable 100%
      ↓
Canary 10%
      ↓
Observe
      ↓
Analysis Passed
      ↓
25%
      ↓
Observe
      ↓
50%
      ↓
Observe
      ↓
100%
      ↓
Promoted
```

## Scenario B — Failed Deployment

1. Stable version is healthy.
2. New version is deployed as canary.
3. Canary receives small traffic.
4. Deliberately introduce/use a bad or slow version.
5. Latency/error rate becomes unhealthy.
6. Observation/analysis detects the problem.
7. Rollout aborts.
8. Stable version remains active.

```text
Stable
  ↓
Canary 10%
  ↓
Observe
  ↓
High latency / errors
  ↓
Analysis Failed
  ↓
Abort
  ↓
Rollback
  ↓
Stable version remains active
```

This should be the strongest live demonstration.

---

# Main UI Direction

Do not create a generic “technology dashboard”.

The main application should feel like a production deployment/control console.

## Primary navigation

- Overview
- Applications
- Deployments
- Rollouts
- Monitoring
- Logs
- Alerts

## Homepage priorities

The main homepage should focus on one active rollout and make the deployment state immediately understandable.

Show:

- application/service name
- stable version
- canary version
- current canary percentage
- rollout stage
- observation/analysis state
- latency
- error rate
- availability/success rate
- analysis checks
- rollout events
- Promote
- Pause
- Abort / Rollback
- rollout history

Do NOT fill the page with unrelated Kubernetes metrics.

## Visual style

- light theme
- white/light gray background
- dark text
- subtle borders
- restrained shadows
- minimal rounded cards
- professional enterprise/SRE appearance
- green = healthy
- amber = warning/analysis
- red = failure
- blue = active/progress
- no flashy gradients
- no “college project” visual style

---

# UI References

Use these as references rather than copying screenshots:

### 1. Argo Rollouts Dashboard
https://argoproj.github.io/argo-rollouts/dashboard/

Purpose:
- rollout state
- revision information
- traffic/progress
- rollout actions

### 2. Grafana Kubernetes Deployment Dashboard
https://grafana.com/grafana/dashboards/20161-kubernetes-deployment-dashboard/

Purpose:
- monitoring layout
- operational metrics
- drill-down style

### 3. Grafana ArgoCD Overview Dashboard
https://grafana.com/grafana/dashboards/24192-argocd-overview/

Purpose:
- enterprise control-plane information hierarchy

The final UI should be a coherent design inspired by these, not a direct screenshot copy.

---

# What each tool is doing

## Kubernetes

Runs and manages the containerized application workloads.

## Argo Rollouts

Controls advanced deployment behavior such as:
- canary progression
- pauses
- analysis
- promotion
- abort/rollback

## Prometheus

Collects/query metrics used to judge rollout health.

## Grafana

Visualizes monitoring information.

## Argo CD

Not required for the current MVP. Avoid adding it unless the project is intentionally expanded into a GitOps workflow.

---

# Expected Questions and Core Answers

## What problem are you solving?

We are reducing the risk of exposing a new software release to all users before its real behavior is known.

## Why not deploy normally?

A bad release may only reveal problems after significant user exposure. Progressive delivery limits the initial blast radius.

## Why not just rollback through Git?

Git changes the desired code/version state. Progressive delivery controls how much live traffic reaches the new version before full promotion.

## What is Canary deployment?

A new version is exposed to a small portion of traffic first. Its behavior is observed before increasing exposure.

## Why Kubernetes?

Kubernetes manages the containerized application and its desired state.

## Why Argo Rollouts?

Argo adds progressive rollout capabilities such as canary steps, analysis, promotion and rollback.

## Why Prometheus?

It provides measurable application/runtime metrics that can be used during rollout analysis.

## What happens when the canary fails?

The rollout is aborted and traffic returns to the stable version.

## What happens when it succeeds?

Traffic is increased through the defined stages and the new version is eventually promoted.

## Is Canary deployment already an existing technology?

Yes. It is an established deployment strategy. The project demonstrates and configures the complete workflow using established open-source technologies.

## Isn't Argo Rollouts already available on GitHub?

Yes. It is used as the open-source foundation. The project work is configuring the end-to-end application, rollout strategy, monitoring, analysis scenarios, testing, and demonstration.

## What is the project's limitation?

The current project is a controlled implementation/demo rather than a complete production platform. A production environment would add broader traffic management, observability, security, GitOps, autoscaling, audit/incident integration, and more extensive testing.

## Future scope

- additional application/infrastructure metrics
- richer rollout policies
- more traffic-management options
- OpenTelemetry/logs/traces
- GitOps with Argo CD
- autoscaling
- RBAC and audit controls
- larger workload/failure testing

## Research question

Preferred answer:

“Sir, our focus is on engineering implementation of an established industry approach rather than a new research contribution. We studied the deployment problem, evaluated the available technologies, selected an appropriate architecture, and implemented the complete workflow.”

If specifically asked about a future paper:

“Sir, one possible future study would be comparing different rollout policies and health metrics under controlled workloads. Our current focus is the working system.”

---

# Existing BTech Report

The current report has 17 pages and already has a usable academic structure:

1. Abstract
2. Introduction
3. Literature Review
4. Technologies
5. Project Requirements
6. Problem Statement
7. Objective
8. Methodology
9. References

The structure should be retained.

The content must be rewritten from the old self-healing project to the progressive-delivery project.

Old concepts to replace:
- self-healing infrastructure
- confidence score
- healing ladder
- predictive disk remediation
- crash healing
- circuit breaker

New concepts:
- progressive delivery
- canary release
- observation/analysis window
- Prometheus metrics
- rollout promotion
- rollout abort
- automated rollback
- Kubernetes + Argo Rollouts

Do not make false novelty claims.

---

# Previous Self-Healing Project

The old BTech concept was:

“Autonomous Self-Healing Infrastructure for Containerized Applications via Ensemble Confidence Scoring.”

Its report described Docker, Prometheus, cAdvisor, Python, SQLite, Grafana, a healing ladder, confidence scoring, predictive disk remediation, circuit breaker, and chaos testing.

The decision was made to move away from that exact implementation because too much of its behavior overlaps with capabilities already provided by container/orchestration tooling and because the user does not want to spend time developing or researching a custom self-healing system.

---

# Existing Resume Project That Can Be Reused as Application Context

The user's existing resume project is:

**Distributed AI Task Scheduler & Chaos Engine**

Technology:
- FastAPI
- Celery
- Redis
- Python
- Docker
- TextBlob

Current architecture:
FastAPI → Redis → Celery workers → Redis result backend.

It already has:
- asynchronous task execution
- worker scaling
- queue monitoring
- retries/backoff
- worker crash simulation
- traffic spikes
- observability/dashboard
- Docker deployment

Potential use:
This existing distributed application can optionally be used as the application/service being deployed through the BTech progressive-delivery system.

Do NOT merge both systems unnecessarily. Only use the existing project as the workload/application if it makes the deployment setup easier.

Important audit correction:
The code audit found that Redis SETNX distributed locking is NOT actually implemented, even though an existing resume bullet claims it. Do not present SETNX locking as an implemented feature unless it is actually added.

---

# Execution Plan

## Immediate

1. Get Docker + local Kubernetes working.
2. Use kind (or Minikube if necessary).
3. Install Argo Rollouts.
4. Install/use the Argo Rollouts kubectl plugin.
5. Run the official rollouts-demo.
6. Verify normal rollout/promotion.
7. Verify bad/slow release and rollback.
8. Open the Argo Rollouts dashboard.
9. Add/configure Prometheus.
10. Add Grafana for monitoring if time permits.
11. Only make minimal UI customization where useful.

## Report

Keep the existing report structure.

Rewrite the technical content around:
Progressive Delivery + Canary + Kubernetes + Argo Rollouts + Prometheus + rollback.

## PPT

Use the college's required PPT template.

Suggested presentation order:

1. Problem
2. Real-world motivation
3. Existing deployment approach
4. Progressive delivery
5. Proposed system
6. Architecture
7. Technology stack
8. Canary workflow
9. Successful rollout
10. Failed rollout / rollback
11. Results/demo
12. Limitations
13. Future scope
14. Conclusion

## Time constraint

The project is intentionally being kept low-effort.

Target:
- minimal additional coding
- maximum use of established open-source software
- coding-agent assistance for setup/configuration
- no research program
- no requirement to invent algorithms
- no unnecessary technologies

---

# One-Sentence Project Explanation

“We implemented a Kubernetes-based progressive-delivery system that gradually exposes new application versions, evaluates their health using monitoring metrics, and automatically promotes or rolls back the release based on the observed results.”

---

# Current Final Decision

**LOCKED DIRECTION:**

**Progressive Delivery and Automated Rollback for Containerized Applications Using Kubernetes and Argo Rollouts**

Use:
**Argo Rollouts + official demo + Kubernetes + Prometheus + Grafana**

Avoid unnecessary:
**Argo CD, custom rollout controller, custom proxy, custom anomaly-detection research, large frontend rebuild**

Primary goal:
**Working demo + coherent report + PPT + viva confidence with minimal time investment.**
