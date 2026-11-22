# NetBird Frequenly Used Commands

## Apply Manifests

```bash
# Apply after Helm upgrade (Helm doesn't manage these)
kubectl apply -f cluster-issuer.yaml
kubectl apply -f proxy-setup.yaml -n netbird
```

## Pod Status

```bash
kubectl get pods -n netbird -o wide
kubectl get pods -n cert-manager -o wide
kubectl get pods -n ingress-nginx -o wide
```

## Restart All Deployments

```bash
# Restart all deployments in a namespace and wait for ready
kubectl rollout restart deployment -n netbird && kubectl rollout status deployment -n netbird --timeout=300s
kubectl rollout restart deployment -n cert-manager && kubectl rollout status deployment -n cert-manager --timeout=300s
kubectl rollout restart deployment -n ingress-nginx && kubectl rollout status deployment -n ingress-nginx --timeout=300s
```

## Logs

```bash
# Management server
kubectl logs -n netbird -l app.kubernetes.io/name=netbird-management --tail=100

# Reverse proxy (general)
kubectl logs -n netbird -l app=netbird-reverse-proxy --tail=100

# Reverse proxy (embedded client only)
kubectl logs -n netbird -l app=netbird-reverse-proxy --tail=50 2>&1 | grep -E "embedded|Engine|connected|failed ready|Relay|relay|failed"

# Signal server
kubectl logs -n netbird -l app.kubernetes.io/name=netbird-signal --tail=50

# Relay server
kubectl logs -n netbird -l app.kubernetes.io/name=netbird-relay --tail=50

# Dashboard
kubectl logs -n netbird -l app.kubernetes.io/name=netbird-dashboard --tail=50

# Cert-manager (rate limit check)
kubectl logs -n cert-manager -l app.kubernetes.io/component=controller --tail=100 2>/dev/null \
  | grep -iE 'rate|limit|429|too many|retry|reset' \
  || echo "No rate limit messages found"

# NGINX ingress controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50
```

## Health Checks

```bash
# Reverse proxy health endpoint
PROXY_POD=$(kubectl get pods -n netbird -l app=netbird-reverse-proxy -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n netbird "$PROXY_POD" -- wget -q -O- http://localhost:8080/healthz | jq .

# Quick proxy health summary
kubectl exec -n netbird "$PROXY_POD" -- wget -q -O- http://localhost:8080/healthz 2>&1 \
  | python3 -c "import sys,json; h=json.load(sys.stdin); print(f\"Healthy: {h['checks']['all_clients_healthy']}, Mgmt: {h['checks']['management_connected']}, Sync: {h['checks']['initial_sync_complete']}, Peers: {h['clients'][list(h['clients'].keys())[0]]['peers_connected']}\")"

# Test a proxied endpoint (replace with your domain)
curl -skI https://your-service.company.com.au/ | head -5
```

## Ingresses

```bash
kubectl get ingress -n netbird
kubectl describe ingress -n netbird netbird-relay | grep -E "Host:|/ "
```

## Relay Connectivity Check

```bash
# Verify relay ingress routes
kubectl describe ingress -n netbird netbird-relay
# Expected: both netbird.company.com/relay AND relay.company.com/ → netbird-relay:33080

# Check relay pod logs for connected peers
kubectl logs -n netbird -l app.kubernetes.io/name=netbird-relay --tail=20
```

## Management Config

```bash
# View live management config
kubectl get configmap -n netbird netbird-management -o jsonpath='{.data.management\.json}' | jq .

# Update relay addresses (e.g. if domain changes)
kubectl get configmap -n netbird netbird-management -o json | python3 -c "
import sys, json
cm = json.load(sys.stdin)
config = json.loads(cm['data']['management.json'])
config['Relay']['Addresses'] = ['rels://relay.company.com:443']
cm['data']['management.json'] = json.dumps(config)
print(json.dumps(cm))
" | kubectl apply -f -
```

## Proxy Token Management

```bash
# List tokens
MANAGEMENT_POD=$(kubectl get pods -n netbird -l app.kubernetes.io/name=netbird-management -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n netbird "$MANAGEMENT_POD" -- /go/bin/netbird-mgmt token list

# Revoke a token
kubectl exec -n netbird "$MANAGEMENT_POD" -- /go/bin/netbird-mgmt token revoke <token-id>
```

## Services & Endpoints

```bash
kubectl get svc -n netbird
kubectl get endpoints -n netbird
```

## NetBird Peer Management (on DMZ peers)

```bash
# Restart netbird service on Linux peer
systemctl restart netbird

# Check peer status
netbird status

# View WireGuard interface
wg show
```

## ACME Certificate Info

```bash
# Check ACME rate limit status in proxy logs
kubectl logs -n netbird -l app=netbird-reverse-proxy 2>&1 | grep "rateLimited"

# View TLS secrets
kubectl get secret -n netbird | grep tls

# Check certificate expiry
kubectl get certificate -n netbird 2>/dev/null
```

## Common Troubleshooting

### Proxy has 0 peers connected
```bash
# Check proxy health
kubectl exec -n netbird $(kubectl get pods -n netbird -l app=netbird-reverse-proxy -o jsonpath='{.items[0].metadata.name}') -- wget -q -O- http://localhost:8080/healthz | jq .

# If peers_connected is 0 but management/signal/relay are connected:
# 1. The lazy connection manager won't connect until the first request
# 2. Access a proxied URL to trigger the connection
# 3. Wait ~20-30s for the tunnel to establish
```

### ACME Rate Limited
```bash
# Check retry time
kubectl logs -n netbird -l app=netbird-reverse-proxy 2>&1 | grep "retry after"
# The proxy will auto-recover when the rate limit window resets
```
