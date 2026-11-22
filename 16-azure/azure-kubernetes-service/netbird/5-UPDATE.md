# NetBird Helm Update Guide

## File Overview

|          File          | Managed by Helm |    Needed?   |                                      Notes                                          |
|------------------------|-----------------|--------------|-------------------------------------------------------------------------------------|
| `values.yaml`          |       Yes       | **Required** | Main Helm values — always edit this, never raw resources                            |
| `proxy-setup.yaml`     |      **No**     | **Required** | Reverse proxy (Deployment, ServiceAccount, Role, PVC, Service, LB) — apply manually |
| `cluster-issuer.yaml`  |      **No**     | **Required** | Let's Encrypt ClusterIssuer — apply manually once                                   |
| `1-PREREQUISITE.md`    |        —        |     Keep     | Architecture notes & gotchas                                                        |
| `2-DEPLOYMENT-PLAN.md` |        —        |     Keep     | Initial deployment guide                                                            |
| `3-COMMANDS.md`        |        —        |     Keep     | Maintenance commands                                                                |
| `4-PROXY-SETUP.md`     |        —        |     Keep     | Reference docs for reverse proxy                                                    |
| `5-UPDATE.md`          |        —        |     Keep     | This update guide                                                                   |

## Pre-Update Checklist

### 1. Pin All Image Tags (NEVER use `latest`)

Using `latest` caused the reverse proxy to restart many times during the 0.74.7 upgrade, each requesting new ACME certs, hitting Let's Encrypt's 5-certs/week rate limit.

In `values.yaml`, **all** tags must be pinned:

```yaml
management:
  image:
    tag: 0.74.7        # ← pinned (good)

relay:
  image:
    tag: latest        # ← UNPINNED — pin this

signal:
  image:
    tag: latest        # ← UNPINNED — pin this
```

In `proxy-setup.yaml`:

```yaml
containers:
  - name: reverse-proxy
    image: netbirdio/reverse-proxy:latest   # ← UNPINNED — pin this
    imagePullPolicy: IfNotPresent            # change from Always
```

**Rule**: Always pin to the same version as management (e.g., `0.74.7`). Check available tags:

```bash
# Check available reverse-proxy tags (run this)
curl -s "https://hub.docker.com/v2/repositories/netbirdio/reverse-proxy/tags?page_size=50" | jq -r '.results[].name'
```

### 2. Check Management Config for Consistency

The management configmap has a `Relay.Addresses` field. This must match the relay ingress host in `values.yaml`.

```bash
# Check what relay addresses the management server expects
kubectl get configmap -n netbird netbird-management \
  -o jsonpath='{.data.management\.json}' | jq '.Relay.Addresses'
```

Expected:
```json
["rels://relay.company.com:443"]
```

In `values.yaml`, the relay ingress and relay env must use the same domain:
- `relay.ingress.hosts[1].host` → `relay.company.com` (routes `/` to relay)
- `relay.env.NB_EXPOSED_ADDRESS` → `rels://relay.company.com:443`

### 3. Verify DNS Match

|         Domain        |             Must point to             |
|-----------------------|---------------------------------------|
| `netbird.company.com` | NGINX Ingress LB IP (your-netbird-ip) |
| `proxy.company.com`   | Reverse Proxy LB IP (your-proxy-ip)   |
| `relay.company.com`   | NGINX Ingress LB IP (your-netbird-ip) |
| `*.proxy.company.com` | CNAME → `proxy.company.com`           |
| `*.company.com.au`    | CNAME → `proxy.company.com`           |

### 4. Check Certificate Status

```bash
# Check existing TLS secrets and their expiry
kubectl get certificate -n netbird
kubectl get secret -n netbird | grep tls
```

## Performing the Update

### Step 1: Backup Current Values

```bash
helm get values netbird -n netbird -o yaml > values-backup-$(date +%Y%m%d).yaml
```

### Step 2: Review Changes with Diff

```bash
# Show what Helm would change (dry-run)
helm upgrade netbird netbirdio/netbird -n netbird \
  -f values.yaml --dry-run --debug 2>&1 | less
```

### Step 3: Upgrade Helm Chart

```bash
# IMPORTANT: Do NOT use --reuse-values — it ignores new defaults from the chart
helm upgrade netbird netbirdio/netbird -n netbird \
  -f values.yaml \
  --timeout 5m --wait --atomic
```

If it fails, Helm automatically rolls back with `--atomic`.

### Step 4: Apply Standalone Manifests

Resources NOT managed by Helm:

```bash
# ClusterIssuer (one-time, idempotent)
kubectl apply -f cluster-issuer.yaml

# Reverse proxy (Deployment, ServiceAccount, RBAC, PVC, Service, LB)
kubectl apply -f proxy-setup.yaml -n netbird
```

### Step 5: Verify

```bash
# Pods
kubectl get pods -n netbird -o wide

# Ingress
kubectl get ingress -n netbird

# Services — note LB IPs may change
kubectl get svc -n netbird

# Reverse proxy health
PROXY=$(kubectl get pods -n netbird -l app=netbird-reverse-proxy \
  -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n netbird "$PROXY" -- wget -q -O- http://localhost:8080/healthz | jq .
```

### Step 6: Update DNS If LB IP Changed

If the reverse proxy or NGINX Ingress LB IP changed (common after upgrades):

```bash
# Check new IPs
kubectl get svc -n netbird netbird-reverse-proxy
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

Update DNS A records accordingly.

## Verifying Relay Connectivity

After upgrade, confirm the reverse proxy can reach the relay:

```bash
kubectl logs -n netbird -l app=netbird-reverse-proxy --tail=50 2>&1 | grep -E "relay|Relay"
```

Expected output may show benign warnings like:

```
failed to read from remote conn: rels://relay.company.com:443, use of closed network connection
failed to close relay connection: use of closed network connection
```

These are **harmless race conditions** from the lazy connection manager closing idle connections while another goroutine reads/closes them. The connection is automatically re-established when needed. If the proxy health check shows `relays_connected: 1`, the relay is working fine.

**Real problems to watch for**:

|                                 Error                              |                   Cause                 |                            Fix                           |
|--------------------------------------------------------------------|-----------------------------------------|----------------------------------------------------------|
| `expected handshake response status code 101 but got 4xx`          | Ingress not routing `relay.company.com` | Verify ingress rules: `kubectl describe ingress -n netbird netbird-relay` |
| `timeout: no recent network activity` (persistent, not occasional) | DNS or network path broken              | Verify DNS: `relay.company.com` resolves to NGINX Ingress IP |
| `no relay server available`                                        |             0/2+ relays available       | Check relay pod status: `kubectl get pods -n netbird -l app.kubernetes.io/name=netbird-relay` |

Verify ingress rules:
```bash
kubectl describe ingress -n netbird netbird-relay | grep -E "Host:|/ "
```
Both `netbird.company.com/relay` AND `relay.company.com/` should route to `netbird-relay:33080`.

## Rollback

If the upgrade breaks things:

```bash
# List revisions
helm history netbird -n netbird

# Rollback to previous revision
helm rollback netbird <REVISION> -n netbird --wait --timeout 5m
```

## Common Pitfalls & How to Avoid Them

### 1. ACME Rate Limiting
**What happened**: Upgrade caused multiple reverse proxy pod restarts, each requesting new Let's Encrypt certificates for `proxy.company.com`. Hit 5 certs/week limit.

**Prevention**:
- Pin image tags (prevents unnecessary pod restarts on upgrade)
- If you do hit the limit, wait: the rate limit resets automatically (check exact retry time in proxy logs)

```bash
# Check rate limit status
kubectl logs -n netbird -l app=netbird-reverse-proxy 2>&1 | grep "rateLimited"
```

### 2. Relay 404 Errors
**What happened**: The standalone `ingress-relay.yaml` was never applied. The relay ingress only had `netbird.company.com/relay` but the proxy needed `relay.company.com/`.

**Prevention**: Ensure the relay ingress covers the correct host. Since v0.74.7, this is fixed in `values.yaml`. Verify after upgrade:

```bash
kubectl describe ingress -n netbird netbird-relay | grep -E "Host:|/ "
```

### 3. Version Mismatch Between Components
**What happened**: `reverse-proxy:latest` may pull a version incompatible with management 0.74.7.

**Prevention**: Pin all image tags to the same version. The management, signal, relay, reverse proxy, and dashboard should all use compatible versions.

### 4. LB IP Changes
**What happened**: Service recreation during upgrade may change the LoadBalancer IP of the reverse proxy.

**Prevention**: After upgrade, always check and update DNS for `proxy.company.com`.

### 5. Helm `--reuse-values`
**What happened**: Using `--reuse-values` prevents new chart defaults from being applied, leaving old configs in place.

**Prevention**: Never use `--reuse-values`. Always pass the updated `-f values.yaml`.

### 6. ConfigMap Changes Not Picked Up
Helm may not trigger pod restart when only the configmap data changes.

```bash
# Force restart after config changes
kubectl rollout restart deployment -n netbird
kubectl rollout status deployment -n netbird --timeout=300s
```

### 7. NET_ADMIN Capability Required by Proxy
**What happened**: The reverse proxy embedded client failed to create a WireGuard tunnel interface after the upgrade. The container only had `NET_BIND_SERVICE` capability but lacked `NET_ADMIN`, which is required to create TUN interfaces (even in userspace mode).

**Prevention**: The `proxy-setup.yaml` must include both capabilities:

```yaml
securityContext:
  runAsUser: 1000
  capabilities:
    add:
      - NET_BIND_SERVICE
      - NET_ADMIN
```

### 8. Lazy Connection Manager
**What happened**: After the upgrade and restart, the proxy showed `peers_connected: 0` even though management, signal, and relay were all connected. The lazy connection manager (enabled by management feature flag in 0.74.7+) only establishes WireGuard tunnels when traffic is actively sent. The first request after a restart may take 20-30s while the tunnel is established.

**Prevention**: After restarting the proxy, trigger a request to a proxied service and wait for the lazy connection to establish. This is normal behavior — subsequent requests will be fast.

```bash
# Verify lazy connection is the cause
kubectl logs -n netbird -l app=netbird-reverse-proxy 2>&1 | grep "lazy connection"
# Expected: "lazy connection manager is enabled by management feature flag"
```

## Version Compatibility Reference

| Management | Reverse Proxy | Signal |  Relay |               Notes                 |
|------------|---------------|--------|--------|-------------------------------------|
|   0.74.7   |     0.74.7    | latest | latest | Current — all components compatible |
|   0.74.4   |     0.74.4    | latest | latest | Previous working config             |
