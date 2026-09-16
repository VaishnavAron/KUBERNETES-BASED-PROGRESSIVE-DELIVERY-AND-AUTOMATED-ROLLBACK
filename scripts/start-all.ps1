Write-Host "[1/6] Checking Kubernetes Cluster..." -ForegroundColor Cyan
kubectl cluster-info

Write-Host "`n[2/6] Starting Argo Rollouts Dashboard (Port 3100)..." -ForegroundColor Cyan
Start-Process -NoNewWindow -FilePath "kubectl" -ArgumentList "argo rollouts dashboard"

Write-Host "[3/6] Starting Prometheus Port-Forward (Port 9090)..." -ForegroundColor Cyan
Start-Process -NoNewWindow -FilePath "kubectl" -ArgumentList "port-forward svc/prometheus 9090:9090 -n monitoring"

Write-Host "[4/6] Starting Grafana Port-Forward (Port 3000)..." -ForegroundColor Cyan
Start-Process -NoNewWindow -FilePath "kubectl" -ArgumentList "port-forward svc/grafana 3000:3000 -n monitoring"

Write-Host "[5/6] Starting Rollouts-Demo App Port-Forward (Port 8080)..." -ForegroundColor Cyan
Start-Process -NoNewWindow -FilePath "kubectl" -ArgumentList "port-forward svc/canary-demo 8080:80"

Write-Host "[6/6] Starting Flask Click-to-Deploy Backend (Port 5000)..." -ForegroundColor Cyan
Start-Process -NoNewWindow -FilePath "python" -ArgumentList "portal/server.py"

Start-Sleep -Seconds 3
Write-Host "`nAll services active!" -ForegroundColor Green
Write-Host "Operations Portal:       http://localhost:5000" -ForegroundColor Yellow
Write-Host "Argo Rollouts Dashboard: http://localhost:3100/rollouts" -ForegroundColor Yellow
Write-Host "Grafana Observability:   http://localhost:3000" -ForegroundColor Yellow
Write-Host "Prometheus Query UI:     http://localhost:9090" -ForegroundColor Yellow
Write-Host "Live App Endpoint:       http://localhost:8080" -ForegroundColor Yellow

Start-Process "http://localhost:5000"
