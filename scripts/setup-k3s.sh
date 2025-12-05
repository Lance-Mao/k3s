#!/bin/bash
set -e

echo "🚀 K3s Setup Script"
echo "==================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (sudo ./setup-k3s.sh)"
    exit 1
fi

# Get VPS IP
VPS_IP=$(curl -s ifconfig.me)
echo -e "${GREEN}✓ Detected VPS IP: ${VPS_IP}${NC}"

# Update system
echo -e "\n${YELLOW}📦 Updating system...${NC}"
apt update && apt upgrade -y

# Install K3s without traefik (we use nginx-ingress via Helm)
echo -e "\n${YELLOW}📦 Installing K3s...${NC}"
curl -sfL https://get.k3s.io | sh -s - --disable traefik

# Wait for K3s to be ready
echo -e "\n${YELLOW}⏳ Waiting for K3s to be ready...${NC}"
sleep 10
kubectl wait --for=condition=Ready nodes --all --timeout=120s

# Setup kubectl for current user
echo -e "\n${YELLOW}🔧 Setting up kubectl...${NC}"
mkdir -p ~/.kube
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
chmod 600 ~/.kube/config
export KUBECONFIG=~/.kube/config

# Add KUBECONFIG to bashrc
if ! grep -q "KUBECONFIG" ~/.bashrc; then
    echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
fi

# Open firewall ports
echo -e "\n${YELLOW}🔥 Configuring firewall...${NC}"
if command -v ufw &> /dev/null; then
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 6443/tcp
    ufw --force enable
    echo -e "${GREEN}✓ Firewall configured${NC}"
else
    echo "UFW not installed, skipping firewall config"
fi

# Generate kubeconfig for GitHub Actions
echo -e "\n${YELLOW}🔑 Generating kubeconfig for GitHub Actions...${NC}"
KUBECONFIG_B64=$(cat /etc/rancher/k3s/k3s.yaml | sed "s/127.0.0.1/${VPS_IP}/g" | base64 -w 0)

echo -e "\n${GREEN}✅ K3s Setup Complete!${NC}"
echo ""
echo "=========================================="
echo "📋 NEXT STEPS:"
echo "=========================================="
echo ""
echo "1. Add this secret to GitHub:"
echo "   Name: KUBECONFIG"
echo "   Value (copy everything below):"
echo ""
echo "----------------------------------------"
echo "${KUBECONFIG_B64}"
echo "----------------------------------------"
echo ""
echo "2. Push your code to trigger deployment"
echo ""
echo "3. After deployment, visit:"
echo "   http://${VPS_IP}/"
echo ""
echo "=========================================="

