# NetBird Configuration Recommendations for Production

## Issue: Services Not Persisting After Restart

The primary issue is that NetBird services and routes need to persist after pod restarts. This configuration guide helps ensure all necessary data is properly persisted.

## Recommended configmap-server.yaml Updates

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: netbird-server-config
  namespace: netbird
data:
  config.yaml: |
    server:
      listenAddress: ":80"
      exposedAddress: "https://netbird.company.com:443"
      stunPorts:
        - 3478
      metricsPort: 9090
      healthcheckAddress: ":9000"
      logLevel: "info"
      logFile: "console"

      authSecret: "${NETBIRD_AUTH_SECRET}"
      dataDir: "/var/lib/netbird"

      auth:
        issuer: "https://netbird.company.com/oauth2"
        signKeyRefreshEnabled: true
        dashboardRedirectURIs:
          - "https://netbird.company.com/nb-auth"
          - "https://netbird.company.com/nb-silent-auth"
        cliRedirectURIs:
          - "http://localhost:53000/"

      reverseProxy:
        trustedHTTPProxies:
          - "10.0.0.0/8"
        # Add service synchronization settings
        serviceRefreshInterval: "30s"
        healthCheckInterval: "60s"

      store:
        engine: "sqlite"
        encryptionKey: "${NETBIRD_STORE_ENCRYPTION_KEY}"
        # Connection pool settings for SQLite
        # maxOpenConnections: 1
        # maxIdleConnections: 1
        # connectionMaxLifetime: "1h"
        # connectionMaxIdleTime: "3m"
```

## Why These Settings Matter

1. **serviceRefreshInterval: "30s"**
   - Forces proxy to re-sync service routes every 30 seconds
   - Ensures new services are discovered quickly after restart
   - Prevents route registration timeouts

2. **healthCheckInterval: "60s"**
   - Validates service health status regularly
   - Helps detect proxy or service failures
   - Enables faster failover

3. **trustedHTTPProxies: ["10.0.0.0/8"]**
   - Allows reverse proxy to forward client IPs correctly
   - Necessary for proper client identification
   - Prevents authentication issues

## Database Persistence Configuration

### Current PVC Configuration (Good)
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: netbird-data
  namespace: netbird
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: managed-csi
```

### What Data is Persisted
- SQLite database with user/peer/service data
- Setup keys and authentication data
- DNS cache and records
- Service routes and configuration
- User profiles and permissions

### Recommended Backup Strategy
```bash
# Daily backup of netbird-data
kubectl exec -n netbird <server-pod> -- tar czf - /var/lib/netbird | \
  gzip > netbird-data-$(date +%Y%m%d).tar.gz

# Or use Azure Backup for AKS PVCs
```

## Service Route Registration

### How Routes Are Stored
1. User registers a service in NetBird
2. Service metadata stored in SQLite database on `netbird-data` PVC
3. On startup, server loads all services from database
4. Proxy connects and fetches service list via management API
5. Proxy caches routes in memory (and now also on `netbird-proxy-certs` PVC)

### Ensuring Routes Persist

1. **Verify Database Persistence**
```bash
# Check PVC is bound and available
kubectl get pvc netbird-data -n netbird

# Check database file exists and has data
kubectl exec -n netbird <server-pod> -- \
  ls -lh /var/lib/netbird/ | grep -E "database|sqlite"
```

2. **Verify Service Registration**
```bash
# After restart, check if services are still registered
# Log into NetBird dashboard or check API

curl -s https://netbird.company.com/api/peers | jq '.data[] | {name, ip}' | head -20
```

3. **Monitor Service Synchronization**
```bash
# Check proxy logs for successful route registration
kubectl logs -n netbird -l app=netbird-reverse-proxy | \
  grep "SNI route lookup" | grep "match: true" | tail -10

# Should see successful matches for your domains like test1.company.com.au
```

## On-Premise Peer Configuration

### Issue: Peer Loses Connection After Restart

The on-premise peer maintains its state in a local database (usually in `/var/lib/netbird/` on Linux).

**Ensure the following:**

1. **Peer Data Directory is Persistent**
```bash
# On on-premise machine, check peer data directory
ls -la /var/lib/netbird/

# Should contain:
# - wg0.conf or similar (WireGuard config)
# - cache/ (peer cache)
# - log/ (logs)
```

2. **Systemd Service Configuration**
```bash
# Check NetBird systemd service
cat /etc/systemd/system/netbird.service

# Verify it has:
# - After=network-online.target
# - Restart=on-failure
# - RestartSec=10s
```

3. **Auto-Reconnect After Restart**

The netbird service should automatically:
1. Load saved peer configuration
2. Reconnect to management server within 30 seconds
3. Re-establish routing to all peers
4. Restore reverse proxy access

### Testing On-Premise Peer Reconnection

```bash
# On on-premise machine
systemctl restart netbird

# Check reconnection (should complete within 60 seconds)
netbird status

# Check for errors
journalctl -u netbird -n 100 -e

# Expected output:
# - "Connected to management server"
# - "Peer configured"
# - "Routes established"
```

## Troubleshooting Persistence Issues

### Symptom: Services Disappear After Restart

1. **Check database isn't corrupted**
```bash
kubectl exec -n netbird <server-pod> -- \
  sqlite3 /var/lib/netbird/*.db ".tables"

# Should show: peers, users, accounts, services, etc.
```

2. **Force database check**
```bash
kubectl exec -n netbird <server-pod> -- \
  sqlite3 /var/lib/netbird/*.db "PRAGMA integrity_check;"

# Should return: ok
```

3. **Verify PVC isn't full**
```bash
kubectl exec -n netbird <server-pod> -- \
  df -h /var/lib/netbird

# Should have free space
```

### Symptom: Proxy Can't Find Services After Restart

1. **Check proxy can reach management server**
```bash
kubectl logs -n netbird -l app=netbird-reverse-proxy | \
  grep -i "management\|connect\|fail" | tail -20
```

2. **Verify proxy token is valid**
```bash
kubectl get secret netbird-proxy-token -n netbird -o jsonpath='{.data.token}' | \
  base64 -d | head -c 50
echo ""

# Should output a token (50+ characters)
```

3. **Check certificate cache**
```bash
kubectl exec -n netbird <proxy-pod> -- \
  ls -la /certs/ | head -20

# Should show certificate files
```

## Production Recommendations

1. **Add Network Policies**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: netbird-allowed
  namespace: netbird
spec:
  podSelector:
    matchLabels:
      app: netbird-reverse-proxy
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
      - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 443
        - protocol: TCP
          port: 80
  egress:
    - to:
      - namespaceSelector: {}
    - to:
      - podSelector:
          matchLabels:
            app: netbird-server
```

2. **Enable Pod Disruption Budgets**
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: netbird-server-pdb
  namespace: netbird
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: netbird-server
```

3. **Add Resource Quotas**
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: netbird-quota
  namespace: netbird
spec:
  hard:
    requests.memory: "4Gi"
    requests.cpu: "2"
    limits.memory: "8Gi"
    limits.cpu: "4"
    persistentvolumeclaims: "5"
```

4. **Monitor Disk Usage**
```bash
# Alert if database grows too large
kubectl exec -n netbird <server-pod> -- \
  du -sh /var/lib/netbird/

# Clean old activity logs if needed
# (Usually NetBird handles this automatically)
```
