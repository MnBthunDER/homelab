# NetBird on AKS - Deployment Plan

## Overview
Deploy NetBird on Azure Kubernetes Service (AKS) in Australia East using Helm with the embedded IdP (local login).

**Domain:** `netbird.company.com`
**Dashboard:** `netbird.company.com`
**Region:** Australia East

---

## Phase 1: Prerequisites (AKS Infrastructure)

### Step 1.1 - Install NGINX Ingress Controller

```bash
# Add the ingress-nginx Helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX Ingress Controller
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --create-namespace \
  --namespace ingress-nginx \
  --set controller.replicaCount=2 \
  --set controller.nodeSelector."kubernetes\.io/os"=linux \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz
```

Wait for the external IP to be assigned:

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller -w
```

### Step 1.2 - Install cert-manager

```bash
# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

### Step 1.3 - Create Let's Encrypt ClusterIssuer

Create `cluster-issuer.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: <YOUR_EMAIL_ADDRESS>
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
    - http01:
        ingress:
          class: nginx
```

Apply it:

```bash
kubectl apply -f cluster-issuer.yaml
```

---

## Phase 2: Generate Secrets & Encryption Key

### Step 2.1 - Generate Encryption Key

```bash
openssl rand -base64 32
```

Save this output - it will be used as `DATASTORE_ENCRYPTION_KEY`.

### Step 2.2 - Generate Relay Password

```bash
openssl rand -base64 32
```

Save this output - it will be used as `RELAY_PASSWORD`.

### Step 2.3 - Create Kubernetes Secret

Replace the placeholder values below with your generated keys:

```bash
kubectl create namespace netbird

kubectl create secret generic netbird-secrets \
  --namespace netbird \
  --from-literal=relayPassword='<RELAY_PASSWORD>' \
  --from-literal=datastoreEncryptionKey='<ENCRYPTION_KEY>'
```

---

## Phase 3: Update values.yaml for Local Login

The key changes from your current Auth0-based config to embedded IdP:

1. **Remove** all Auth0 references (`IdpManagerConfig`, Auth0 URLs)
2. **Add** `EmbeddedIdP` configuration
3. **Add** `EncryptionKey` reference
4. **Update** `HttpConfig` to use embedded IdP endpoints
5. **Update** dashboard environment variables
6. **Ensure relay ingress includes `relay.company.com` host**

See the complete `values.yaml` file for the full updated configuration.

---

## Phase 4: Install NetBird Helm Chart

```bash
# Add NetBird Helm repository
helm repo add netbirdio https://netbirdio.github.io/helms
helm repo update

# Install NetBird
helm install netbird netbirdio/netbird \
  --namespace netbird \
  -f values.yaml
```

### Verify Installation

```bash
# Check all pods are running
kubectl get pods -n netbird

# Check ingress resources
kubectl get ingress -n netbird

# Get the external IP
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

---

## Phase 5: DNS Configuration

Once you have the external IP from Step 1.1, create DNS A records:

|         Record        | Type |      Value      |
|-----------------------|------|-----------------|
| `netbird.company.com` |   A  | `<EXTERNAL_IP>` |
| `relay.company.com`   |   A  | `<EXTERNAL_IP>` |

---

## Phase 6: Deploy Reverse Proxy

The reverse proxy is a standalone deployment (NOT managed by Helm). See `proxy-setup.yaml` and `PROXY-SETUP.md` for details.

```bash
kubectl apply -f proxy-setup.yaml -n netbird
```

After deployment, get the external IP and update DNS:

|         Record        |  Type |        Value        |
|-----------------------|-------|---------------------|
| `proxy.company.com`   |   A   | `<PROXY_LB_IP>`     |
| `*.proxy.company.com` | CNAME | `proxy.company.com` |
| `*.company.com.au`    | CNAME | `proxy.company.com` |

---

## Phase 7: Instance Setup

1. Wait for DNS propagation and TLS certificates to be issued
2. Navigate to `https://netbird.company.com`
3. The Instance Setup Wizard will appear (first-time setup)
4. Create your owner account:
   - Email address
   - Password (minimum 8 characters)
   - Name (optional)
5. You'll be redirected to login with your new credentials
6. Install the NetBird client and connect using `netbird up --management-url https://netbird.company.com`

---

## Files Summary

|          File          | Managed by Helm |                  Purpose                 |
|------------------------|-----------------|------------------------------------------|
| `values.yaml`          |       Yes       | Main Helm values                         |
| `proxy-setup.yaml`     |      **No**     | Reverse proxy (apply manually)           |
| `cluster-issuer.yaml`  |      **No**     | Let's Encrypt ClusterIssuer (apply once) |
| `1-PREREQUISITE.md`    |        —        | Architecture notes & gotchas             |
| `2-DEPLOYMENT-PLAN.md` |        —        | This deployment guide                    |
| `3-COMMANDS.md`        |        —        | Maintenance commands                     |
| `4-UPDATE.md`          |        —        | Helm update guide                        |
| `PROXY-SETUP.md`       |        —        | Reverse proxy reference                  |
