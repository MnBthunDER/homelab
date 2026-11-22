# NetBird Reverse Proxy - Fix Deployment Guide

## Problem Summary

After `kubectl rollout restart deployment -n netbird` and on-premise peer restart (`systemctl restart netbird`):
- Pages fail to load on `test1.company.com.au`
- Reverse proxy shows TLS handshake timeouts
- Multiple "SNI peek failed" errors
- ACME certificate rate limiting errors from Let's Encrypt
- Routes not properly registered

## Root Causes Identified

1. **Certificate Storage Loss** - Using `emptyDir` for ACME certificates (lost on restart)
2. **Let's Encrypt Rate Limiting** - Excessive certificate requests after restart
3. **Connection Timeouts** - No explicit timeout configuration for TLS handshakes
4. **Service Route Synchronization** - Routes not re-synced after proxy restart
5. **On-Premise Peer Reconnection** - Peer doesn't reconnect after management server/proxy restarts

## Solution: Multi-Step Fix

### Step 1: Backup Current Configuration
```bash
# Backup existing reverse proxy deployment
kubectl get deployment -n netbird netbird-reverse-proxy -o yaml > reverse-proxy-backup.yaml
kubectl get pvc -n netbird -o yaml > pvc-backup.yaml
kubectl get secret -n netbird netbird-proxy-token -o yaml > proxy-token-backup.yaml
```

### Step 2: Apply the Fix - Create Certificate PVC
```bash
# First, create the new PVC for persistent certificate storage
# This is included in reverse-proxy-v2.yaml

# Delete old reverse proxy deployment (keep data)
kubectl delete deployment netbird-reverse-proxy -n netbird --ignore-not-found

# Apply new configuration with persistent certificate storage
kubectl apply -f reverse-proxy-v2.yaml

# Verify PVC creation
kubectl get pvc -n netbird
# Expected output should show:
#   netbird-proxy-data       Bound
#   netbird-proxy-certs      Bound (NEW)
```

### Step 3: Verify Reverse Proxy Health
```bash
# Check pod status
kubectl get pods -n netbird -l app=netbird-reverse-proxy

# Check logs for startup (wait ~60 seconds for initialization)
kubectl logs -n netbird -l app=netbird-reverse-proxy --follow

# Expected logs after 60 seconds:
# - "SNI router started"
# - "ACME manager initialized"
# - No certificate errors
```

### Step 4: Verify Server Health
```bash
# Check server pod
kubectl get pods -n netbird -l app=netbird-server

# Check server can reach proxy
kubectl exec -n netbird $(kubectl get pod -n netbird -l app=netbird-server -o jsonpath='{.items[0].metadata.name}') -- \
  netstat -tlnp | grep -E ':80|:443|:3478'
```

### Step 5: Test On-Premise Peer Reconnection
```bash
# On the on-premise machine:
systemctl restart netbird

# Check logs on machine (should see connection within 30 seconds)
journalctl -u netbird -f --lines=50

# Expected output:
# - Connection established to proxy.company.com
# - Service routes synchronized
# - No TLS errors
```

### Step 6: Test Web Access
```bash
# Test from your machine
curl -v https://test1.company.com.au/

# Expected: HTTP 200 (or redirect to service)
# Not expected: TLS handshake errors, connection timeouts

# Or use browser:
# https://test1.company.com.au
```

### Step 7: Monitor for Issues
```bash
# Watch for TLS/certificate errors (should be none)
kubectl logs -n netbird -l app=netbird-reverse-proxy | grep -i "error\|fail\|timeout" | tail -20

# Check certificate files exist and are readable
kubectl exec -n netbird $(kubectl get pod -n netbird -l app=netbird-reverse-proxy -o jsonpath='{.items[0].metadata.name}') -- \
  find /certs -type f 2>/dev/null | head -20

# Check ACME cache
kubectl exec -n netbird $(kubectl get pod -n netbird -l app=netbird-reverse-proxy -o jsonpath='{.items[0].metadata.name}') -- \
  ls -la /certs/acme/ 2>/dev/null || echo "ACME cache directory"
```

## If Issues Persist: Troubleshooting

### Issue: Still seeing "i/o timeout" errors

1. Check network connectivity between components:
```bash
# From reverse proxy pod
kubectl exec -n netbird <reverse-proxy-pod> -- \
  timeout 5 bash -c "</dev/tcp/netbird-server.netbird.svc.cluster.local/80" && echo "Connected" || echo "Failed"

# From server pod  
kubectl exec -n netbird <server-pod> -- \
  timeout 5 bash -c "</dev/tcp/10.224.0.5/443" && echo "Connected" || echo "Failed"
```

2. Check firewall/NSG rules in Azure:
```bash
# Ensure NSG allows traffic on:
# - Port 80 (HTTP)
# - Port 443 (HTTPS)
# - Port 3478 (STUN, UDP)

# From on-premise:
telnet test1.company.com.au 443  # Should connect
```

3. Increase timeout values in reverse-proxy-v2.yaml:
```yaml
- name: NB_PROXY_CONNECTION_READ_TIMEOUT
  value: "60s"  # Increase from 30s
- name: NB_PROXY_CONNECTION_WRITE_TIMEOUT
  value: "60s"  # Increase from 30s
```

### Issue: ACME certificates still failing

1. Check Let's Encrypt rate limits:
```bash
# Wait at least 1 hour before retrying
# Or use staging Let's Encrypt for testing

# Check which domains have certificates:
kubectl exec -n netbird <proxy-pod> -- \
  find /certs -name "*.crt" 2>/dev/null | xargs -I {} basename {}
```

2. Pre-create certificates using staging:
```bash
# Edit reverse-proxy-v2.yaml and add:
- name: NB_PROXY_ACME_DIRECTORY_URL
  value: "https://acme-staging-v02.api.letsencrypt.org/directory"

# After testing works, remove this to use production
```

### Issue: Routes not registered after restart

1. Check proxy token is valid:
```bash
kubectl get secret netbird-proxy-token -n netbird -o jsonpath='{.data.token}' | base64 -d
```

2. Verify proxy can reach management server:
```bash
kubectl exec -n netbird <proxy-pod> -- \
  timeout 5 wget -O- http://netbird-server.netbird.svc.cluster.local:80/api/health 2>&1
```

3. Check service registration in server logs:
```bash
kubectl logs -n netbird -l app=netbird-server | grep -i "proxy\|service\|route" | tail -50
```

## Configuration Changes Summary

### New Environment Variables
```
NB_PROXY_CONNECTION_READ_TIMEOUT=30s
NB_PROXY_CONNECTION_WRITE_TIMEOUT=30s
NB_PROXY_IDLE_TIMEOUT=60s
NB_PROXY_ACME_CACHE_DIR=/certs/acme
NB_PROXY_DISABLE_CERTIFICATE_PREFETCH=false
NB_PROXY_ACME_RENEW_BEFORE_DAYS=30
```

### New Persistent Storage
```
netbird-proxy-certs: 2Gi
  - Stores ACME certificates
  - Stores cached certificate data
  - Persists across pod restarts
```

### Enhanced Health Checks
```
Liveness: HTTP GET /debug/health:8080 (30s interval)
Readiness: HTTP GET /debug/health:8080 (10s interval)
```

## Rollback if Needed

```bash
# If the new configuration causes issues:
kubectl delete -f reverse-proxy-v2.yaml
kubectl apply -f reverse-proxy-backup.yaml

# Clean up new PVC
kubectl delete pvc netbird-proxy-certs -n netbird --ignore-not-found
```

## Monitoring After Fix

### Metrics to Watch

1. **Proxy Pod Restart Count**
```bash
kubectl get pods -n netbird -l app=netbird-reverse-proxy -o wide
# Should show: RESTART = 0 after first startup
```

2. **Certificate Age**
```bash
kubectl exec -n netbird <proxy-pod> -- \
  find /certs -name "*.crt" -exec openssl x509 -in {} -noout -dates \;
```

3. **Connection Errors**
```bash
kubectl logs -n netbird -l app=netbird-reverse-proxy | \
  grep -i "error\|fail" | wc -l
# Should gradually decrease to minimal
```

4. **Service Synchronization**
```bash
# Check if routes are being synced properly
kubectl logs -n netbird -l app=netbird-reverse-proxy | \
  grep "SNI route lookup" | tail -5
# Should see "match: true" for your domains
```

## Next Steps

1. Apply the configuration
2. Monitor logs for 5 minutes
3. Test on-premise peer connectivity
4. Test web access to services
5. Monitor for 24 hours to ensure stability
6. If stable, consider replacing old deployment-server.yaml with deployment-server-enhanced.yaml

## Support Information

If issues persist:
1. Check the FIXES_APPLIED.md for detailed issue descriptions
2. Review logs at: `kubectl logs -n netbird -l app=netbird-reverse-proxy --tail=500`
3. Check on-premise peer logs: `journalctl -u netbird -n 500 -e`
4. Verify DNS resolution: `nslookup test1.company.com.au` from AKS node
