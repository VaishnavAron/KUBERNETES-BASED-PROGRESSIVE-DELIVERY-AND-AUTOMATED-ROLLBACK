Write-Host "Restoring rollout to baseline stable version (argoproj/rollouts-demo:blue)..." -ForegroundColor Cyan
kubectl argo rollouts set image canary-demo canary-demo=argoproj/rollouts-demo:blue
Start-Sleep -Seconds 3
kubectl argo rollouts get rollout canary-demo
