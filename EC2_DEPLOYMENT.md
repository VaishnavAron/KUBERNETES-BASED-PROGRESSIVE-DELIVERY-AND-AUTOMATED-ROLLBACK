# AWS EC2 Deployment Guide: Progressive Delivery & Automated Rollback

This guide provides step-by-step instructions to deploy the entire Progressive Delivery Kubernetes demo on an **AWS EC2 instance (Ubuntu 22.04 / 24.04 LTS)** using a single setup command.

---

## 1. AWS Console Launch Configuration

Follow these exact settings in the AWS EC2 Launch Instance Console:

| Setting | Value / Recommendation | Why It Matters |
| :--- | :--- | :--- |
| **Instance Name** | `Progressive_delivery` | Matches your project name. |
| **Application & OS (AMI)** | **Ubuntu Server 22.04 LTS** or **24.04 LTS** (64-bit x86) | Standard Debian-based Linux distribution supported by Docker and Kind. |
| **Instance Type** | **`t3.large`** or **`m7i-flex.large`** (2 vCPU, 8 GiB RAM) | 8 GiB RAM is required to smoothly run Kind, Docker, Prometheus, Grafana, and Argo Rollouts concurrently. |
| **Key Pair** | Select or create your key pair (e.g. `Progressive_delivery.pem`) | Required for SSH access from your local machine. |
| **Storage (Volume)** | ⚠️ **Change from 8 GiB to at least 20 GiB or 30 GiB (gp3)** | **CRITICAL:** The default 8 GiB in the AWS console is too small. Docker images for Kind, Kubernetes nodes, Prometheus, Grafana, and demo apps require ~10–12 GiB of space. |

### Security Group Inbound Rules (Firewall)
In the **Network settings** section, click **Edit** (or create a new Security Group) and ensure the following **Inbound Rules** are added:

| Type | Port Range | Protocol | Source | Description |
| :--- | :--- | :--- | :--- | :--- |
| **SSH** | `22` | TCP | `0.0.0.0/0` (or My IP) | Remote SSH terminal access |
| **Custom TCP** | `5000` | TCP | `0.0.0.0/0` | **Operations Console (Web UI)** |
| **Custom TCP** | `3100` | TCP | `0.0.0.0/0` | **Argo Rollouts Dashboard** |
| **Custom TCP** | `3000` | TCP | `0.0.0.0/0` | **Grafana Observability UI** |
| **Custom TCP** | `9090` | TCP | `0.0.0.0/0` | **Prometheus Query Interface** |
| **Custom TCP** | `8080` | TCP | `0.0.0.0/0` | **Canary Live Demo App** |

> [!WARNING]
> If you only leave port 22 open (the default in AWS console), you will not be able to view the Operations Console in your browser! Always add ports `5000`, `3100`, `3000`, `9090`, and `8080`.

---

## 2. Connect to Your EC2 Instance & Upload Code

Once your EC2 instance enters the **Running** state, copy its **Public IPv4 address** (e.g. `54.210.88.120`).

### Option A: Clone from GitHub Directly on EC2 (Recommended — Fastest)
1. Open PowerShell on Windows and SSH into EC2:
   ```powershell
   ssh -i "C:\path\to\Progressive_delivery.pem" ubuntu@<EC2-PUBLIC-IP>
   ```
2. Clone the repository into your home directory:
   ```bash
   git clone https://github.com/VaishnavAron/KUBERNETES-BASED-PROGRESSIVE-DELIVERY-AND-AUTOMATED-ROLLBACK.git btech-project
   cd btech-project
   ```

---

### Option B: Upload from Your Windows Machine via SCP
If you want to transfer your local workspace files directly without using git:
```powershell
scp -i "C:\path\to\Progressive_delivery.pem" -r "c:\Users\vansh\Desktop\btech final project" ubuntu@<EC2-PUBLIC-IP>:~/btech-project
```
Then SSH in:
```powershell
ssh -i "C:\path\to\Progressive_delivery.pem" ubuntu@<EC2-PUBLIC-IP>
cd ~/btech-project
```

---

## 3. Run Single-Command Setup

Run the automated setup script. It installs Docker, Kind v0.27.0, Kubectl, the Argo Rollouts plugin v1.10.0, Python Flask, creates the Kubernetes cluster, and deploys all application and monitoring components:

```bash
cd ~/btech-project
chmod +x scripts/*.sh
./scripts/ec2-setup.sh
```

*(Estimated time to complete: 2 to 3 minutes)*

The script outputs colored `[STEP 1/10]` through `[STEP 10/10]` progress indicators and confirms when all pods are running.

---

## 4. Start Background Services

Start the resilient background port-forward loops and the Flask click-to-deploy backend:

```bash
./scripts/ec2-start.sh
```

This launches all background services using `nohup`, prints their process IDs, and displays your live public URLs.

---

## 5. Access the Operations Console & Live Views

Open your web browser on your laptop and navigate to:

- 🎛️ **Operations Console:** `http://<EC2-PUBLIC-IP>:5000`
- 🚀 **Argo Rollouts UI:** `http://<EC2-PUBLIC-IP>:3100/rollouts`
- 📊 **Grafana Dashboard:** `http://<EC2-PUBLIC-IP>:3000`
- 📈 **Prometheus Queries:** `http://<EC2-PUBLIC-IP>:9090`
- 🌐 **Live Demo Application:** `http://<EC2-PUBLIC-IP>:8080`

> [!NOTE]
> The Operations Console automatically adapts to your EC2 public IP. The embedded tabs inside `http://<EC2-PUBLIC-IP>:5000` will render the Argo Rollouts UI, Grafana, Prometheus, and Live Application seamlessly.

---

## 6. Conduct the Faculty Demonstration

The demo behaves identically to the local version:

1. **Successful Canary Promotion**:
   - Click the green **"Run Successful Canary Promotion"** button.
   - Watch the Rollout Activity card log scaling events and display canary pod allocation (`Stable: 4 pods`, `Canary: 1 pod`).
   - Switch between the **Argo Rollouts UI** and **Live Application** tabs to show the 20% traffic split and healthy analysis passing.
2. **Automated Rollback on SLA Breach**:
   - Click the red **"Run Faulty Canary & Rollback"** button.
   - Watch Prometheus detect failed HTTP probes from the `bad-red` image.
   - Observe Argo Rollouts aborting the deployment, reverting 100% of traffic to the stable baseline, and marking the pipeline as `Rollback Triggered`.
3. **Restore Baseline**:
   - Click **"Restore Baseline (Blue)"** to reset the system to stable production.

---

## 7. Stop Services & Teardown

### To Stop Background Services:
```bash
./scripts/ec2-stop.sh
```

### To Delete the Kind Cluster Completely:
```bash
kind delete cluster --name rollouts-demo
```

---

## 8. Troubleshooting & FAQ

### Issue 1: `docker: permission denied while trying to connect to the Docker daemon socket`
- **Cause:** Linux user group updates require re-authenticating the shell session.
- **Fix:** Run:
  ```bash
  newgrp docker
  ```
  Or simply log out and SSH back in:
  ```bash
  exit
  ssh -i <key.pem> ubuntu@<EC2-PUBLIC-IP>
  ```
  *(Note: `scripts/ec2-setup.sh` automatically configures socket permissions to prevent this during initial setup).*

### Issue 2: Kind cluster creation fails or pods show `Evicted` / `DiskPressure`
- **Cause:** The EC2 instance volume was left at the default 8 GiB and ran out of disk space.
- **Fix:** In the AWS EC2 console, go to **Volumes** → select volume → **Actions** → **Modify volume** → increase size to **30 GiB**.
  Then inside the instance run:
  ```bash
  sudo growpart /dev/root 1 || sudo growpart /dev/xvda 1
  sudo resize2fs /dev/root || sudo resize2fs /dev/xvda1
  df -h
  ```

### Issue 3: Browser times out when accessing `http://<EC2-PUBLIC-IP>:5000`
- **Cause:** Security Group inbound rules are missing or blocked.
- **Fix:** Go to **AWS Console** → **EC2 Instances** → Select instance → **Security** tab → Click the Security Group link → **Edit inbound rules** → Add ports `5000`, `3100`, `3000`, `9090`, `8080` from `Anywhere-IPv4` (`0.0.0.0/0`).

### Issue 4: Port-forward terminates during canary deployment
- **Cause:** Expected Kubernetes behavior. When Argo Rollouts scales pods down during canary steps, existing TCP connections close.
- **Fix:** Handled automatically! `scripts/ec2-start.sh` wraps all port-forwards in persistent `while true` reconnect loops that reconnect within 1 second.
