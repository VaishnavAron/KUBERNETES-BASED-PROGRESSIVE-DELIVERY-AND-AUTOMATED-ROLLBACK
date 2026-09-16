import datetime
import json
import os
import subprocess
import sys
from flask import Flask, jsonify, request, send_from_directory

app = Flask(__name__, static_folder=".")

PORTAL_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(PORTAL_DIR, ".."))

def run_cmd(cmd):
    """Executes a command safely and returns output."""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            cwd=PROJECT_ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=30
        )
        return {
            "success": result.returncode == 0,
            "stdout": result.stdout.strip(),
            "stderr": result.stderr.strip()
        }
    except Exception as e:
        return {"success": False, "error": str(e)}

@app.route("/")
def index():
    return send_from_directory(PORTAL_DIR, "index.html")

@app.route("/<path:path>")
def static_files(path):
    return send_from_directory(PORTAL_DIR, path)

@app.route("/api/demo/success", methods=["POST"])
def demo_success():
    """Triggers healthy canary deployment: argoproj/rollouts-demo:yellow"""
    cmd = "kubectl argo rollouts set image canary-demo canary-demo=argoproj/rollouts-demo:yellow"
    res = run_cmd(cmd)
    return jsonify({
        "status": "success" if res["success"] else "error",
        "action": "canary-promotion",
        "image": "argoproj/rollouts-demo:yellow",
        "details": res
    })

@app.route("/api/demo/rollback", methods=["POST"])
def demo_rollback():
    """Triggers faulty canary deployment: argoproj/rollouts-demo:bad-red"""
    cmd = "kubectl argo rollouts set image canary-demo canary-demo=argoproj/rollouts-demo:bad-red"
    res = run_cmd(cmd)
    return jsonify({
        "status": "success" if res["success"] else "error",
        "action": "faulty-canary-rollback",
        "image": "argoproj/rollouts-demo:bad-red",
        "details": res
    })

@app.route("/api/demo/restore", methods=["POST"])
def demo_restore():
    """Restores baseline stable version: argoproj/rollouts-demo:blue"""
    cmd = "kubectl argo rollouts set image canary-demo canary-demo=argoproj/rollouts-demo:blue"
    res = run_cmd(cmd)
    return jsonify({
        "status": "success" if res["success"] else "error",
        "action": "restore-baseline",
        "image": "argoproj/rollouts-demo:blue",
        "details": res
    })

@app.route("/api/rollout/status", methods=["GET"])
def rollout_status():
    """Fetches real-time status of canary-demo including stable & canary pod counts."""
    res = run_cmd("kubectl get rollout canary-demo -o json")
    if not res["success"]:
        return jsonify({"status": "error", "error": res.get("stderr") or res.get("error")}), 500

    try:
        data = json.loads(res["stdout"])
        status = data.get("status", {})
        spec = data.get("spec", {})
        
        phase = status.get("phase", "Unknown")
        replicas = f"{status.get('readyReplicas', 0)}/{spec.get('replicas', 5)}"
        current_step_idx = status.get("currentStepIndex", 0)
        
        steps = spec.get("strategy", {}).get("canary", {}).get("steps", [])
        total_steps = len(steps)
        
        # Calculate current weight
        weight = 100
        if phase in ["Progressing", "Paused"]:
            weight = 0
            if current_step_idx is not None and current_step_idx < len(steps):
                for i in range(current_step_idx, -1, -1):
                    if "setWeight" in steps[i]:
                        weight = steps[i]["setWeight"]
                        break
        elif phase == "Degraded":
            weight = 0
            
        containers = spec.get("template", {}).get("spec", {}).get("containers", [{}])
        image = containers[0].get("image", "argoproj/rollouts-demo:blue")
        
        # Determine condition message
        message = ""
        conditions = status.get("conditions", [])
        for cond in conditions:
            if cond.get("type") in ["Healthy", "Degraded", "Progressing"]:
                message = cond.get("message", "")
                
        # Enhancement 2: Calculate stablePods and canaryPods from ReplicaSets
        stable_pods = 0
        canary_pods = 0
        stable_hash = status.get("stableRS")
        current_hash = status.get("currentPodHash")
        
        rs_res = run_cmd("kubectl get rs -l app=canary-demo -o json")
        if rs_res["success"]:
            try:
                rs_data = json.loads(rs_res["stdout"])
                for item in rs_data.get("items", []):
                    h = item.get("metadata", {}).get("labels", {}).get("rollouts-pod-template-hash")
                    ready = item.get("status", {}).get("readyReplicas", 0)
                    if h == stable_hash:
                        stable_pods = ready
                    elif h == current_hash and current_hash != stable_hash:
                        canary_pods = ready
            except Exception:
                pass
        else:
            stable_pods = status.get("readyReplicas", 5)
            canary_pods = 0
            
        # Optional: query Prometheus for live success rate
        sla_success = "100.0%"
        sla_latency = "< 15 ms"
        try:
            import urllib.request
            req = urllib.request.urlopen("http://localhost:9090/api/v1/query?query=avg_over_time(probe_success%7Bjob=%22canary-service-probe%22%7D%5B20s%5D)", timeout=2)
            p_data = json.loads(req.read().decode("utf-8"))
            results = p_data.get("data", {}).get("result", [])
            if results:
                val = float(results[0]["value"][1]) * 100
                sla_success = f"{val:.1f}%"
        except Exception:
            pass

        return jsonify({
            "status": "ok",
            "phase": phase,
            "image": image,
            "replicas": replicas,
            "weight": weight,
            "currentStep": current_step_idx,
            "totalSteps": total_steps,
            "message": message,
            "slaSuccess": sla_success,
            "slaLatency": sla_latency,
            "stablePods": stable_pods,
            "canaryPods": canary_pods
        })
    except Exception as e:
        return jsonify({"status": "error", "error": str(e)}), 500

@app.route("/api/rollout/events", methods=["GET"])
def rollout_events():
    """Enhancement 1: Returns chronologically sorted rollout events (last 15)."""
    events = []
    
    # 1. Fetch Kubernetes cluster events for canary-demo
    res = run_cmd("kubectl get events --field-selector involvedObject.name=canary-demo -o json")
    if res["success"]:
        try:
            k8s_events = json.loads(res["stdout"]).get("items", [])
            for e in k8s_events:
                ts_raw = e.get("lastTimestamp") or e.get("firstTimestamp") or e.get("eventTime") or ""
                msg = e.get("message", "")
                reason = e.get("reason", "")
                
                # Determine event classification
                ev_type = "info"
                if any(x in reason for x in ["Fail", "Aborted", "Error"]) or "Failed" in msg or "aborted" in msg:
                    ev_type = "failed"
                elif any(x in reason for x in ["Healthy", "Completed", "Success"]):
                    ev_type = "healthy"
                elif any(x in reason for x in ["Scaling", "Progress", "Started", "Updated"]):
                    ev_type = "progressing"
                elif "Pause" in reason or "Pause" in msg:
                    ev_type = "info"
                    
                # Format timestamp to HH:MM:SS
                time_str = ts_raw
                if ts_raw:
                    try:
                        clean_ts = ts_raw.replace("Z", "+00:00")
                        dt = datetime.datetime.fromisoformat(clean_ts).astimezone()
                        time_str = dt.strftime("%H:%M:%S")
                    except Exception:
                        time_str = ts_raw[-9:-1] if len(ts_raw) >= 9 else ts_raw
                        
                events.append({
                    "raw_time": ts_raw,
                    "time": time_str,
                    "type": ev_type,
                    "message": f"{reason}: {msg}" if reason and not msg.startswith(reason) else msg
                })
        except Exception:
            pass

    # 2. Fetch Rollout conditions to supplement events
    r_res = run_cmd("kubectl get rollout canary-demo -o json")
    if r_res["success"]:
        try:
            r_data = json.loads(r_res["stdout"])
            for cond in r_data.get("status", {}).get("conditions", []):
                ts_raw = cond.get("lastTransitionTime", "")
                msg = cond.get("message", "")
                ctype = cond.get("type", "")
                
                ev_type = "info"
                if ctype == "Healthy":
                    ev_type = "healthy"
                elif ctype == "Degraded":
                    ev_type = "failed"
                elif ctype == "Progressing":
                    ev_type = "progressing"
                    
                time_str = ts_raw
                if ts_raw:
                    try:
                        clean_ts = ts_raw.replace("Z", "+00:00")
                        dt = datetime.datetime.fromisoformat(clean_ts).astimezone()
                        time_str = dt.strftime("%H:%M:%S")
                    except Exception:
                        time_str = ts_raw[-9:-1] if len(ts_raw) >= 9 else ts_raw
                        
                events.append({
                    "raw_time": ts_raw,
                    "time": time_str,
                    "type": ev_type,
                    "message": f"Condition [{ctype}] - {msg}"
                })
        except Exception:
            pass

    # Sort chronologically by raw_time (oldest to newest)
    events.sort(key=lambda x: x.get("raw_time", ""))
    
    # Keep last 15 events
    last_15 = events[-15:] if len(events) > 15 else events
    
    # Strip raw_time before returning
    clean_events = [{"time": x["time"], "type": x["type"], "message": x["message"]} for x in last_15]
    
    return jsonify(clean_events)

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    print(f"Starting Progressive Delivery Operations Console on http://0.0.0.0:{port}")
    app.run(host="0.0.0.0", port=port, debug=False)
