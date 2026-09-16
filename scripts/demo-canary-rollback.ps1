Write-Host "==========================================================" -ForegroundColor Red
Write-Host "  SCENARIO B: FAULTY CANARY & AUTOMATED METRIC ROLLBACK    " -ForegroundColor Red
Write-Host "==========================================================" -ForegroundColor Red
Write-Host "Deploying faulty canary image: argoproj/rollouts-demo:bad-red" -ForegroundColor Yellow

kubectl argo rollouts set image canary-demo canary-demo=argoproj/rollouts-demo:bad-red

Write-Host "`nObserving canary failure detection and automated rollback..." -ForegroundColor Cyan
kubectl argo rollouts get rollout canary-demo --watch
