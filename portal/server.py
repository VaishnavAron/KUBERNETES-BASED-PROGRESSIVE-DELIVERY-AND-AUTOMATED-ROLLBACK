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
    """Fetches real-time status of canary-demo from Kubernetes and Prometheus."""
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
            "slaLatency": sla_latency
        })
    except Exception as e:
        return jsonify({"status": "error", "error": str(e)}), 500

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    print(f"Starting Progressive Delivery Operations Console on http://0.0.0.0:{port}")
    app.run(host="0.0.0.0", port=port, debug=False)
