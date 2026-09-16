Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  SCENARIO A: SUCCESSFUL CANARY PROMOTION & VERIFICATION   " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Deploying healthy canary image: argoproj/rollouts-demo:yellow" -ForegroundColor Cyan

kubectl argo rollouts set image canary-demo canary-demo=argoproj/rollouts-demo:yellow

Write-Host "`nObserving progressive canary steps and Prometheus AnalysisRuns..." -ForegroundColor Yellow
kubectl argo rollouts get rollout canary-demo --watch
