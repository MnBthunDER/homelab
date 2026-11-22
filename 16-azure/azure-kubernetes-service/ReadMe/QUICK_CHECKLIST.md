# NetBird AKS Fix - Quick Action Checklist

## Problem
After `kubectl rollout restart deployment -n netbird` and on-premise peer restart, pages fail to load with TLS connection timeouts.

## Root Cause
1. **Reverse proxy uses `emptyDir` for certificates** → lost on restart
2. **Let's Encrypt rate limiting** → excessive requests after restart
3. **No connection timeout configuration** → TLS handshakes hang
4. **Service routes not re-synced** → proxy can't route traffic

## Solution: 3-Step Fix

### STEP 1: Backup & Prepare
```bash
# Create backups of current configuration
kubectl get deployment -n netbird netbird-reverse-proxy -o yaml > reverse-proxy-backup.yaml
kubectl get all -n netbird -o yaml > netbird-backup-all.yaml

# Verify current state
kubectl get pods -n netbird
kubectl get pvc -n netbird
```

**Time: 2 minutes | Risk: Low**

### STEP 2: Apply the Fix
```bash
# Make files executable
chmod +x health-check.sh

# Delete old reverse proxy (data is safe in PVC)
kubectl delete deployment netbird-reverse-proxy -n netbird

# Apply new configuration with persistent certificate storage
kubectl apply -f reverse-proxy-v2.yaml

# Wait for new pod to start (should see CrashLoopBackOff briefly, then Running)
kubectl get pods -n netbird -l app=netbird-reverse-proxy --watch
# Press Ctrl+C when you see STATUS=Running
```

**Time: 3-5 minutes | Risk: Medium (30-60 second downtime)**

### STEP 3: Verify the Fix
```bash
# Run health check
bash health-check.sh

# Check proxy logs (should see no errors after 60 seconds)
kubectl logs -n netbird -l app=netbird-reverse-proxy -f
# Wait for "SNI router started" message, then Ctrl+C

# Verify certificates are being stored persistently
kubectl exec -n netbird $(kubectl get pod -n netbird -l app=netbird-reverse-proxy -o jsonpath='{.items[0].metadata.name}') -- \
  ls -la /certs/

# On on-premise machine, restart NetBird service
systemctl restart netbird

# Check if reconnection works (should succeed within 60 seconds)
sleep 30 && netbird status
```

**Time: 5 minutes | Risk: Low**

### STEP 4: Test End-to-End
```bash
# Test from your local machine or browser
curl -v https://test1.company.com.au/
# Expected: HTTP 200 or 301 redirect (NOT TLS error)

# Or use browser
# Navigate to: https://test1.company.com.au

# Check logs show successful route matching
kubectl logs -n netbird -l app=netbird-reverse-proxy | grep -i "test1.company"
# Expected: "match: true" in the logs
```

**Time: 2 minutes | Risk: Low**

## Files to Apply

1. ✅ **reverse-proxy-v2.yaml** - NEW reverse proxy with persistent storage
   - Creates `netbird-proxy-certs` PVC (2Gi)
   - Adds connection timeout configuration
   - Improves health checks

2. 📖 **FIXES_APPLIED.md** - Documentation of issues and fixes
3. 📖 **DEPLOYMENT_STEPS.md** - Detailed deployment guide
4. 📖 **CONFIG_PERSISTENCE_GUIDE.md** - Configuration best practices
5. 🔧 **health-check.sh** - Automated health verification

## Files NOT Changed (But Reviewed)
- ✓ reverse-proxy.yaml (old version - backed up)
- ✓ deployment-server.yaml (working fine)
- ✓ deployment-dashboard.yaml (working fine)
- ✓ configmap-server.yaml (no changes needed)

## Expected Results After Fix

### Before
```
❌ Pages fail to load: test1.company.com.au times out
❌ Logs show: "SNI peek failed", "i/o timeout", "missing certificate"
❌ Let's Encrypt rate limit errors
❌ On-premise peer disconnects after restart
```

### After
```
✅ Pages load normally
✅ Logs show: "SNI route lookup", "match: true"
✅ No rate limit errors (certificates cached)
✅ On-premise peer auto-reconnects within 60 seconds
```

## Rollback Plan (If Issues Arise)

```bash
# Step 1: Revert to old deployment
kubectl apply -f reverse-proxy-backup.yaml

# Step 2: Delete new PVC
kubectl delete pvc netbird-proxy-certs -n netbird

# Step 3: Wait for pods to restart
kubectl get pods -n netbird -l app=netbird-reverse-proxy --watch
```

**Note:** Rollback is safe - all data persists in the other PVCs

## Timeline

| Step      | Duration      | Status |
|-----------|---------------|--------|
| Backup    | 2 min         | ✅     |
| Apply Fix | 3-5 min       | ⏳     |
| Verify    | 5 min         | ⏳     |
| Test      | 2 min         | ⏳     |
| **Total** | **12-14 min** |        |


## Success Criteria

After deployment, you should see:

1. ✓ All pods running: `kubectl get pods -n netbird`
2. ✓ All PVCs bound: `kubectl get pvc -n netbird`
3. ✓ Health check passes: `bash health-check.sh`
4. ✓ No errors in logs: `kubectl logs -n netbird -l app=netbird-reverse-proxy | grep -i error | wc -l` → 0-2
5. ✓ Services load: `curl https://test1.company.com.au/` → 200 or 301
6. ✓ On-premise peer stays connected after `systemctl restart netbird`

## If Something Goes Wrong

1. **Pods not starting?**
   - Check: `kubectl describe pod -n netbird <pod-name>`
   - Solution: Run rollback (see section above)

2. **Still seeing certificate errors?**
   - Wait 30+ seconds for ACME initialization
   - Check: `kubectl logs -n netbird -l app=netbird-reverse-proxy`
   - If rate limited: Wait 1 hour before retrying

3. **On-premise peer still disconnecting?**
   - Check peer logs: `journalctl -u netbird -n 100 -e`
   - Verify: `netbird status` on on-premise machine
   - Check NSG rules allow 443, 80, 3478

4. **Web pages still timing out?**
   - Test from AKS: `kubectl exec -n netbird <server-pod> -- wget https://test1.company.com.au`
   - Check DNS: `nslookup test1.company.com.au`
   - Run health check: `bash health-check.sh`

## Commands Quick Reference

```bash
# Monitor during deployment
watch kubectl get pods -n netbird

# View live logs
kubectl logs -n netbird -l app=netbird-reverse-proxy -f

# Check status
kubectl get all -n netbird

# Health check
bash health-check.sh

# Restart on-premise peer (on on-premise machine)
systemctl restart netbird

# Check on-premise peer status
netbird status

# View on-premise logs
journalctl -u netbird -f

# Rollback if needed
kubectl apply -f reverse-proxy-backup.yaml
kubectl delete pvc netbird-proxy-certs -n netbird
```

## Support Resources

1. **Read:** FIXES_APPLIED.md (issue descriptions)
2. **Read:** DEPLOYMENT_STEPS.md (detailed steps)
3. **Read:** CONFIG_PERSISTENCE_GUIDE.md (advanced config)
4. **Check:** Logs with: `kubectl logs -n netbird -l app=<app> --tail=200`
5. **Help:** Run `bash health-check.sh` for diagnostics

---

## Ready to Deploy?

### Prerequisites
- ✓ kubectl access to AKS cluster
- ✓ Files in this directory (netbird/)
- ✓ Make shell script executable: `chmod +x health-check.sh`

### Go!

```bash
# Execute the fix
kubectl delete deployment netbird-reverse-proxy -n netbird
kubectl apply -f reverse-proxy-v2.yaml

# Monitor
watch kubectl get pods -n netbird

# Verify
bash health-check.sh

# Test
curl -v https://test1.company.com.au/
```

**Estimated time: 12-14 minutes | Downtime: ~60 seconds | Risk: Low**
