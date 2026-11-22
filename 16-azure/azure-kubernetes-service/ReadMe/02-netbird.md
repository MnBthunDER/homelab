# NetBird Helm Chart for Kubernetes
https://github.com/netbirdio/helms/tree/main/charts/netbird

# Config YAML Example
https://raw.githubusercontent.com/netbirdio/netbird/main/combined/config.yaml.example

---

# Prerequisites - ingress-nginx
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.6/deploy/static/provider/cloud/deploy.yaml

# Prerequisites - cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.21.0/cert-manager.crds.yaml
kubectl create namespace cert-manager

---

# Deployment 

# Create namespace
kubectl apply -f namespace.yaml

# Create secrets (do this first)
kubectl apply -f secrets.yaml

# Create ConfigMaps
kubectl apply -f configmap-server.yaml
kubectl apply -f configmap-dashboard.yaml

# Create PVC
kubectl apply -f pvc.yaml
kubectl apply -f proxy-pvc.yaml

# Deploy services
kubectl apply -f deployment-server.yaml
kubectl apply -f deployment-dashboard.yaml

# Create services
kubectl apply -f service-server.yaml
kubectl apply -f service-dashboard.yaml
kubectl apply -f service-server-grpc.yaml

# Create ingress (requires cert-manager)
kubectl apply -f clusterissuer.yaml
kubectl apply -f ingress.yaml
kubectl apply -f ingress-grpc.yaml

# Create reverse proxy (requires cert-manager)
kubectl apply -f reverse-proxy.yaml
kubectl apply -f reverse-proxy-ingress.yaml
---
# Verification
# Check pod status
kubectl get pods -n netbird

# Check logs
kubectl logs -n netbird -l app=netbird-server -f
kubectl logs -n cert-manager -l app.kubernetes.io/component=controller --tail=100 2>/dev/null | grep -iE 'rate|limit|429|too many|retry|reset' || echo "No rate limit messages found in controller logs"

# Check ingress
kubectl get ingress -n netbird

# Test connectivity
curl https://netbird.example.com/api/health
---

# Restart all deployments in cert-manager namespace and wait for ready
kubectl rollout restart deployment -n cert-manager && kubectl rollout status deployment -n cert-manager --timeout=300s

# Restart all deployments in ingress-nginx namespace and wait for ready
kubectl rollout restart deployment -n ingress-nginx && kubectl rollout status deployment -n ingress-nginx --timeout=300s

# Restart all deployments in netbird namespace and wait for ready
kubectl rollout restart deployment -n netbird && kubectl rollout status deployment -n netbird --timeout=300s

# Verify final state
kubectl get pods -n cert-manager -o wide
kubectl get pods -n netbird -o wide
The key command is kubectl rollout restart deployment -n <namespace> — it performs a rolling restart of all deployments in that namespace without downtime. The rollout status part blocks until the new pods are ready.

# Verify Peers state
systemctl restart netbird
netbird status
