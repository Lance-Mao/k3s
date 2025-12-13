# K3s CI/CD Setup Guide

Complete guide to deploy apps on K3s with GitHub Actions and Helm.

**Everything is automated!** Just run the setup script on your VPS and push code.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Your VPS (K3s)                         │
│  ┌───────────────────────────────────────────────────────┐  │
│  │     Nginx Ingress Controller (auto-installed by Helm) │  │
│  └─────────────────────┬─────────────────────────────────┘  │
│                        │                                     │
│         ┌──────────────┴──────────────┐                     │
│         │ /                           │ /api/*              │
│         ▼                             ▼                     │
│  ┌──────────────┐              ┌──────────────┐            │
│  │   Frontend   │              │     API      │            │
│  │   (Nginx)    │              │  (FastAPI)   │            │
│  └──────────────┘              └──────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

---

## Quick Start (3 Steps)

### Step 1: Setup VPS

SSH into your VPS and run:

```bash
# Download and run setup script
curl -O https://raw.githubusercontent.com/dfanso/k3s/main/scripts/setup-k3s.sh
chmod +x setup-k3s.sh
sudo ./setup-k3s.sh
```

The script will:
- ✅ Install K3s (without traefik)
- ✅ Configure kubectl
- ✅ Open firewall ports
- ✅ Generate kubeconfig for GitHub Actions

**Copy the KUBECONFIG value** shown at the end.

### Step 2: Add GitHub Secret

1. Go to your repo → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Name: `KUBECONFIG`
4. Value: Paste the base64 value from Step 1
5. Click **Add secret**

### Step 3: Push Code

```bash
git add .
git commit -m "Deploy to K3s"
git push
```

**That's it!** GitHub Actions will:
1. Build Docker images
2. Push to GitHub Container Registry
3. Deploy your app (and nginx-ingress if `ingress-nginx.enabled: true`)

> **Fresh cluster?** Set `ingress-nginx.enabled: true` in `helm/k3s-app/values.yaml` before pushing.

---

## After First Deploy: Make Packages Public

GitHub creates container packages as **private** by default. K3s needs them public.

1. Go to `https://github.com/dfanso?tab=packages`
2. Click each package (`k3s-frontend`, `k3s-api`)
3. **Package settings** → **Danger Zone** → **Change visibility** → **Public**

Then re-run the GitHub Action or push again.

---

## Manual VPS Setup (Alternative)

If you prefer manual setup instead of the script:

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install K3s without traefik
curl -sfL https://get.k3s.io | sh -s - --disable traefik

# Setup kubectl
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=~/.kube/config

# Open firewall
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 6443/tcp

# Install nginx-ingress controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace

# Wait for nginx-ingress to be ready
kubectl get pods -n ingress-nginx -w

# Get kubeconfig for GitHub (replace YOUR_VPS_IP)
sudo cat /etc/rancher/k3s/k3s.yaml | sed 's/127.0.0.1/YOUR_VPS_IP/g' | base64 -w 0
```

> **Note:** If you install nginx-ingress manually, set `ingress-nginx.enabled: false` in `helm/k3s-app/values.yaml`.

---

## Project Structure

```
k3s/
├── .github/workflows/deploy.yaml    # CI/CD pipeline
├── app/
│   ├── api/                         # FastAPI backend
│   │   ├── Dockerfile
│   │   ├── main.py
│   │   └── requirements.txt
│   └── frontend/                    # Nginx frontend
│       ├── Dockerfile
│       ├── nginx.conf
│       ├── index.html
│       ├── styles.css
│       └── app.js
├── helm/k3s-app/
│   ├── Chart.yaml                   # Includes nginx-ingress dependency
│   ├── values.yaml                  # Configuration
│   └── templates/                   # K8s manifests
├── scripts/
│   └── setup-k3s.sh                 # VPS setup script
└── SETUP.md
```

---

## Configuration

### Change Replicas

Edit `helm/k3s-app/values.yaml`:

```yaml
frontend:
  replicaCount: 3  # Change this

api:
  replicaCount: 3  # Change this
```

### Nginx Ingress Controller

**For fresh clusters** (no nginx-ingress installed):
```yaml
ingress-nginx:
  enabled: true   # Helm will install nginx-ingress automatically
```

**If nginx-ingress is already installed** on your cluster:
```yaml
ingress-nginx:
  enabled: false  # Skip installation, use existing
```

> ⚠️ **Note:** If you get an error about "IngressClass nginx already exists", set `enabled: false`.

### Add Environment Variables

```yaml
api:
  env:
    MY_VAR: "my-value"
    DATABASE_URL: "postgres://..."
```

---

## Useful Commands

```bash
# Check pods
kubectl get pods

# Check logs
kubectl logs -f deployment/k3s-app-api

# Restart deployment
kubectl rollout restart deployment/k3s-app-frontend

# Check ingress
kubectl get ingress

# Helm status
helm list
helm get values k3s-app

# Uninstall
helm uninstall k3s-app
```

---

## Troubleshooting

### ImagePullBackOff
**Cause:** Packages are private
**Fix:** Make packages public on GitHub (see above)

### Pods Pending
**Cause:** Waiting for resources or dependencies
**Fix:** Wait a few minutes, check `kubectl describe pod <name>`

### 404 on /api/
**Cause:** Ingress not configured correctly
**Fix:** Check ingress: `kubectl describe ingress k3s-app`

### Connection Refused
**Cause:** Firewall blocking ports
**Fix:** `sudo ufw allow 80/tcp && sudo ufw allow 6443/tcp`

---

## SSL/TLS with Let's Encrypt

### Quick Setup (Recommended)

Use the provided script:

```bash
# On your VPS
cd /path/to/k3s
chmod +x scripts/setup-ssl.sh
./scripts/setup-ssl.sh yourdomain.com your@email.com
```

The script will:
1. Install cert-manager
2. Create Let's Encrypt ClusterIssuer
3. Create TLS-enabled Ingress
4. Request SSL certificate automatically

### Manual Setup

#### Step 1: Install cert-manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for it to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s
```

#### Step 2: Create ClusterIssuer

```bash
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your@email.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

#### Step 3: Create TLS Ingress

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: k3s-app-tls
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - yourdomain.com
    secretName: k3s-app-tls-secret
  rules:
  - host: yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: k3s-app-frontend
            port:
              number: 80
EOF
```

### DNS Configuration

Point your domain to your VPS:

| Type | Name | Value |
|------|------|-------|
| A | @ | YOUR_VPS_IP |
| A | www | YOUR_VPS_IP |

### Verify Certificate

```bash
# Check certificate status
kubectl get certificate

# Describe for details
kubectl describe certificate k3s-app-tls-secret

# Check secret was created
kubectl get secret k3s-app-tls-secret
```

### Troubleshooting SSL

```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check certificate events
kubectl describe certificaterequest

# Check challenge status
kubectl get challenges
```

---

## Monitoring Stack (Prometheus + Grafana)

### Option 1: Install Separately (Recommended)

Install monitoring stack separately on your VPS:

```bash
# Add Prometheus helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack (includes Grafana)
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30030 \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30090 \
  --set alertmanager.service.type=NodePort \
  --set alertmanager.service.nodePort=30093 \
  --set grafana.adminPassword=admin123

# Wait for pods
kubectl get pods -n monitoring -w
```

### Option 2: Enable in Helm Chart

First install CRDs, then enable in values.yaml:

```bash
# On VPS: Install Prometheus CRDs first
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagerconfigs.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_probes.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_prometheusagents.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_scrapeconfigs.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml
```

Then set `monitoring.enabled: true` in values.yaml and push.

### Access Monitoring UIs

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| **Grafana** | `http://YOUR_IP:30030` | admin / admin123 |
| **Prometheus** | `http://YOUR_IP:30090` | - |
| **AlertManager** | `http://YOUR_IP:30093` | - |

### Open Firewall Ports

```bash
sudo ufw allow 30030/tcp  # Grafana
sudo ufw allow 30090/tcp  # Prometheus
sudo ufw allow 30093/tcp  # AlertManager
```

### Custom App Metrics

The API exposes Prometheus metrics at `/api/metrics`:
- `k3s_app_uptime_seconds` - Pod uptime
- `k3s_app_requests_total` - Total requests
- `k3s_app_info` - App version and hostname

---

## Loki (Log Aggregation)

### Install Loki

```bash
# Add Grafana helm repo
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Loki stack
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set loki.auth_enabled=false \
  --set grafana.enabled=false \
  --set promtail.enabled=true

# Wait for Loki to be ready
kubectl wait --for=condition=ready pod -l app=loki -n monitoring --timeout=300s
```

### Add Loki to Grafana

**Option 1: Via UI**
1. Go to Grafana → **Connections** → **Data sources**
2. Click **+ Add new data source**
3. Select **Loki**
4. URL: `http://loki.monitoring:3100`
5. Click **Save & test**

**Option 2: Via API**
```bash
curl -X POST "http://admin:admin123@YOUR_IP:30030/api/datasources" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Loki",
    "type": "loki",
    "url": "http://loki.monitoring:3100",
    "access": "proxy"
  }'
```

### Query Logs in Grafana

1. Go to **Explore** → Select **Loki**
2. Example queries:

```logql
# All logs from your app
{namespace="default"}

# API logs only
{namespace="default", app="k3s-app-api"}

# Frontend logs
{namespace="default", app="k3s-app-frontend"}

# Search for errors
{namespace="default"} |= "error"
```

### Verify Loki is Working

```bash
# Check pods
kubectl get pods -n monitoring | grep loki

# Test Loki endpoint
kubectl exec -n monitoring loki-0 -- wget -qO- http://localhost:3100/ready
```

---

## Quick Reference

| Action | Command |
|--------|---------|
| Deploy | `git push` |
| Check status | `kubectl get pods` |
| View logs | `kubectl logs -f deploy/k3s-app-api` |
| Restart | `kubectl rollout restart deploy/k3s-app-api` |
| Uninstall | `helm uninstall k3s-app` |
| Grafana | `http://YOUR_IP:30030` |
| Prometheus | `http://YOUR_IP:30090` |
| Loki Logs | Grafana → Explore → Loki |
