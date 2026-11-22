# Kubernetes Crash Course for Absolute Beginners
https://www.youtube.com/watch?v=s_o8dwzRlu4

# AKS Initial Setup
https://www.youtube.com/watch?v=YlR9AkDJMMA&list=PL9aNQqB-xjbAjGjkAKuydrYa8ZDM4TcI7

# Install Azure CLI
https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?view=azure-cli-latest&pivots=apt

# Upgrade Azure CLI
az upgrade

# Install kubectl
az aks install-cli

# Get credentials for your cluster
az aks get-credentials --resource-group homelab --name aks-homelab

# Verify access
kubectl get nodes

# Config view
kubectl config view

# Get all Pods running in the AKS
kubectl get pods --all-namespaces -o wide
kubectl get pods --all-namespaces

# Get all deployments running in the AKS
kubectl get deployments --all-namespaces -o wide
kubectl get deployments --all-namespaces

# Restart all deployments in cert-manager namespace and wait for ready
kubectl rollout restart deployment -n cert-manager && kubectl rollout status deployment -n cert-manager
kubectl rollout restart deployment -n netbird && kubectl rollout status deployment -n netbird


# Kubernetes Deployment
https://netbirdio-netbird-9.mintlify.app/deployment/kubernetes

# Export aks-kubeconfig.yml for remote access
az aks get-credentials \
  --resource-group homelab \
  --name aks-homelab \
  --file ./aks-kubeconfig.yml

