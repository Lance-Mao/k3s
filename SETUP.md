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
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/k3s/main/scripts/setup-k3s.sh
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
3. Install nginx-ingress (via Helm dependency)
4. Deploy your app

---

## After First Deploy: Make Packages Public

GitHub creates container packages as **private** by default. K3s needs them public.

1. Go to `https://github.com/YOUR_USERNAME?tab=packages`
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

# Get kubeconfig for GitHub (replace YOUR_VPS_IP)
sudo cat /etc/rancher/k3s/k3s.yaml | sed 's/127.0.0.1/YOUR_VPS_IP/g' | base64 -w 0
```

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

### Disable Nginx Ingress (if already installed)

```yaml
ingress-nginx:
  enabled: false
```

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

## SSL/TLS (Optional)

Add cert-manager for automatic Let's Encrypt certificates:

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create issuer
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

Then update `values.yaml`:

```yaml
ingress:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: yourdomain.com
      paths:
        - path: /api(/|$)(.*)
          pathType: ImplementationSpecific
          service: api
        - path: /
          pathType: Prefix
          service: frontend
  tls:
    - secretName: k3s-app-tls
      hosts:
        - yourdomain.com
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
