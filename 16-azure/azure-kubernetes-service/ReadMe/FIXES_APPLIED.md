# NetBird Reverse Proxy Fixes Applied

## Issues Identified and Fixed

### 1. **Certificate Storage Issue (CRITICAL)**
**Problem:** Reverse proxy used `emptyDir` for certificates, causing loss of ACME certificates on restart
**Fix:** Migrated to persistent storage via PVC
**Impact:** Certificates now persist across pod restarts, preventing Let's Encrypt rate limiting

### 2. **Reverse Proxy TLS Timeouts**
**Problem:** On-premise peer connections timeout on TLS handshake after service restart
**Fix:** 
- Added connection read/write timeout configurations
- Improved TCP connection handling in reverse-proxy-v2.yaml
- Added idle timeout to prevent hanging connections

### 3. **Service Route Synchronization**
**Problem:** Routes not properly registered after proxy restart
**Fix:**
- Added health check to proxy deployment
- Added proper initialization delay for ACME certificate loading
- Added volume mounts with correct permissions

### 4. **Let's Encrypt Rate Limiting**
**Problem:** Rate limiting due to excessive certificate requests: "too many new registrations (10) from this IP in 3h"
**Fix:**
- Certificate caching via persistent storage
- Reduced ACME certificate prefetch frequency
- Added fallback certificate handling

## Files Modified/Created

1. **reverse-proxy-v2.yaml** - Improved reverse proxy deployment with fixes
2. **proxy-pvc-certs.yaml** - New PVC specifically for ACME certificates
3. **deployment-server-enhanced.yaml** - Enhanced server deployment with better health checks

## Deployment Instructions

See the DEPLOYMENT_STEPS.md file for step-by-step deployment and verification instructions.

## Key Configuration Changes

### Reverse Proxy Environment Variables
- Added: `NB_PROXY_CONNECTION_READ_TIMEOUT=30s`
- Added: `NB_PROXY_CONNECTION_WRITE_TIMEOUT=30s`
- Added: `NB_PROXY_IDLE_TIMEOUT=60s`
- Kept: `NB_PROXY_CERTIFICATE_DIRECTORY=/certs`
- Kept: `NB_PROXY_ALLOW_INSECURE=true` (for initial setup)

### Certificate Storage
- Changed from: `emptyDir: {}`
- Changed to: PersistentVolumeClaim `netbird-proxy-certs` (2Gi CSI)

### Volume Mounts
- `/certs` now mounts to persistent storage
- `/var/lib/netbird` mounts to existing proxy data PVC

## Monitoring Recommendations

1. Check reverse proxy pod logs for ACME certificate status
2. Monitor certificate expiration: `kubectl exec -n netbird <pod> -- ls -la /certs/`
3. Test connectivity after restart: Check logs for "SNI route lookup" success
4. Verify on-premise peer reconnection within 2 minutes of restart

## Rollback Instructions

If issues persist:
1. Keep the old `reverse-proxy.yaml` as `reverse-proxy-backup.yaml`
2. Revert with: `kubectl apply -f reverse-proxy-backup.yaml`
3. Delete new PVC: `kubectl delete pvc netbird-proxy-certs -n netbird`
