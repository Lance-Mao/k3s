# K3s CI/CD Setup with Helm & Nginx Ingress

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Your VPS (K3s)                       │
│  ┌─────────────────────────────────────────────────┐   │
│  │              Nginx Ingress Controller            │   │
│  │                   (Port 80/443)                  │   │
│  └─────────────────┬───────────────────────────────┘   │
│                    │                                    │
│         ┌─────────┴──────────┐                         │
│         │                    │                         │
│         ▼                    ▼                         │
│  ┌──────────────┐    ┌──────────────┐                 │
│  │   Frontend   │    │     API      │                 │
│  │   (Nginx)    │───▶│  (FastAPI)   │                 │
│  │   Port 80    │    │  Port 8000   │                 │
│  └──────────────┘    └──────────────┘                 │
│       /                    /api/                       │
└─────────────────────────────────────────────────────────┘
```

---

## Step 1: Install Nginx Ingress Controller (on VPS)

SSH into your VPS and run:

```bash
# Remove default Traefik (comes with k3s)
kubectl delete helmchart traefik traefik-crd -n kube-system 2>/dev/null || true

# Install Nginx Ingress via Helm
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.publishService.enabled=true
```

Verify it's running:
```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

---

## Step 2: Get Kubeconfig

On your VPS:

```bash
# Get kubeconfig with external IP
sudo cat /etc/rancher/k3s/k3s.yaml | sed 's/127.0.0.1/37.60.228.133/g' | base64 -w 0
```

Copy the entire output.

---

## Step 3: Open Firewall Ports

```bash
# Kubernetes API
sudo ufw allow 6443/tcp

# HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Reload
sudo ufw reload
```

---

## Step 4: Add GitHub Secret

Go to your GitHub repository:
**Settings** → **Secrets and variables** → **Actions** → **New repository secret**

| Name | Value |
|------|-------|
| `KUBECONFIG` | The base64 encoded kubeconfig from Step 2 |

---

## Step 5: Push to GitHub

```bash
cd F:\Git\k3s

# Initialize git
git init
git add .
git commit -m "Initial: K3s app with Helm, Nginx, Frontend"

# Add remote (replace YOUR_USERNAME)
git remote add origin https://github.com/YOUR_USERNAME/k3s.git
git branch -M main
git push -u origin main
```

---

## Step 6: Verify Deployment

After the GitHub Action completes:

```bash
# On your VPS
kubectl get pods
kubectl get svc
kubectl get ingress
helm list
```

Visit: **http://37.60.228.133**

---

## Project Structure

```
k3s/
├── .github/
│   └── workflows/
│       └── deploy.yaml          # CI/CD pipeline
├── api/
│   ├── Dockerfile               # API container
│   ├── main.py                  # FastAPI app
│   └── requirements.txt
├── frontend/
│   ├── Dockerfile               # Frontend container
│   ├── nginx.conf               # Nginx config
│   ├── index.html               # Dashboard
│   ├── styles.css               # Styles
│   └── app.js                   # JavaScript
├── helm/
│   └── k3s-app/
│       ├── Chart.yaml           # Helm chart metadata
│       ├── values.yaml          # Configuration values
│       └── templates/
│           ├── _helpers.tpl     # Template helpers
│           ├── frontend-deployment.yaml
│           ├── frontend-service.yaml
│           ├── api-deployment.yaml
│           ├── api-service.yaml
│           └── ingress.yaml
├── SETUP.md                     # This file
└── .gitignore
```

---

## Useful Commands

### Helm
```bash
# List releases
helm list

# Upgrade deployment
helm upgrade k3s-app ./helm/k3s-app

# Rollback
helm rollback k3s-app 1

# Uninstall
helm uninstall k3s-app

# Show values
helm get values k3s-app
```

### Kubernetes
```bash
# Watch pods
kubectl get pods -w

# View logs
kubectl logs -f deployment/k3s-app-frontend
kubectl logs -f deployment/k3s-app-api

# Describe resources
kubectl describe ingress k3s-app

# Port forward for debugging
kubectl port-forward svc/k3s-app-api 8000:8000
```

---

## Troubleshooting

### Nginx Ingress not responding
```bash
# Check ingress controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

### Image pull errors
- Ensure GitHub Container Registry is public, or add imagePullSecrets
- Check image names in `helm/k3s-app/values.yaml`

### 502 Bad Gateway
```bash
# Check if backend pods are running
kubectl get pods
kubectl logs deployment/k3s-app-api
```

---

## SSL/TLS (Optional)

To add Let's Encrypt SSL:

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ClusterIssuer (save as cluster-issuer.yaml)
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

Then update `helm/k3s-app/values.yaml`:
```yaml
ingress:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: yourdomain.com
      paths:
        - path: /
          pathType: Prefix
          service: frontend
  tls:
    - secretName: k3s-app-tls
      hosts:
        - yourdomain.com
```
