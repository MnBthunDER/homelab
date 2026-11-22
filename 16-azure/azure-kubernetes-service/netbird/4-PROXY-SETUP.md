# NetBird Reverse Proxy Setup

## Reference
- https://netbird.io/knowledge-hub/netbird-only-private-services
- https://docs.netbird.io/selfhosted/maintenance/scaling/multiple-proxy-instances
- https://docs.netbird.io/selfhosted/migration/enable-reverse-proxy
- https://docs.netbird.io/manage/reverse-proxy/bring-your-own-proxy#private-services-net-bird-only-access

## Architecture

The reverse proxy has its own LoadBalancer IP and handles TLS directly. No NGINX ingress involvement.

```
Internet → Proxy LB (your-proxy-ip:443) → Reverse Proxy → WireGuard → NetBird Peer
                        ↕
                Management Server (gRPC ProxyService)
```

### Two LoadBalancers

|   Component   | LoadBalancer IP |    Port 80   |       Port 443       | Port 51820 |
|---------------|-----------------|--------------|----------------------|------------|
| NGINX Ingress | your-netbird-ip | HTTP         | HTTPS (cert-manager) |     —      |
| NetBird Proxy | your-proxy-ip   | ACME http-01 | HTTPS (ACME)         | WireGuard  |

## DNS Records

| Type  | Name                     | Content              |  IP / Target  |
|-------|--------------------------|----------------------|---------------|
| A     | netbird.company.com      | your-netbird-ip      | NGINX Ingress |
| A     | proxy.company.com        | your-proxy-ip        | Proxy LB      |
| A     | relay.company.com        | your-netbird-ip      | NGINX Ingress |
| CNAME | *.proxy.company.com      | proxy.company.com    | Proxy LB      |
| CNAME | *.company.com.au         | proxy.company.com    | Proxy LB      |

**Important**: `proxy.company.com` must point to the proxy LB IP (your-proxy-ip), NOT the ingress IP. The proxy handles its own TLS via ACME. No SSL passthrough ingress is needed.

**Warning**: The proxy LB IP changes on Service redeployment. After `helm upgrade` or if the Service is recreated, update the `proxy.company.com` A record to the new IP.

## Prerequisites

- Management server running with embedded IdP (v0.62+)
- Management ConfigMap `Relay.Addresses` must use `rels://` scheme (e.g. `"rels://relay.company.com:443"`)
- Management ConfigMap `Signal` must use struct format: `{"Proto": "https", "URI": "netbird.company.com:443"}`
- Port 80 and 443 accessible from the internet on the proxy LB IP
- The relay host `relay.company.com` must be configured in the Helm-managed relay ingress (see `values.yaml`)

## Proxy Token

Generated from the management server:

```
Token: nbx_YOURTOKEN
Token ID: YOURTOKENID
```

Manage tokens:
```bash
# List tokens
kubectl exec -n netbird <management-pod> -- /go/bin/netbird-mgmt token list

# Revoke a token
kubectl exec -n netbird <management-pod> -- /go/bin/netbird-mgmt token revoke <token-id>
```

## Deployment

Apply the manifest to deploy the reverse proxy:

```bash
kubectl apply -f proxy-setup.yaml -n netbird
```

After deployment, get the external IP:
```bash
kubectl get svc netbird-reverse-proxy -n netbird
```

Then update the DNS A record for `proxy.company.com` to point to the new external IP.

## Key Configuration Details

### Image Tag
Always pin the reverse-proxy image tag to match the management version:

```yaml
image: netbirdio/reverse-proxy:0.74.7   # Never use :latest
imagePullPolicy: IfNotPresent
```

Check available tags:
```bash
curl -s "https://hub.docker.com/v2/repositories/netbirdio/reverse-proxy/tags?page_size=50" | jq -r '.results[].name'
```

### Management Connection
The proxy connects to the management server via the internal ClusterIP gRPC service (port 33073) using `NB_PROXY_ALLOW_INSECURE=true`. This avoids routing through the public internet and doesn't require TLS for the internal connection.

### ACME Certificates (http-01)
The proxy uses Let's Encrypt ACME **http-01** challenges to provision certificates. This requires:
- Port 80 accessible from the internet on the proxy LB IP
- DNS resolving service domains to the proxy LB IP
- `NB_PROXY_ACME_ADDRESS=:80` handles the HTTP challenge server independently of the main TLS listener

### Rate Limits
Let's Encrypt rate limits: 50 certificates/week per registered domain, 5 duplicate certificates/week. If rate limited, wait for the retry window (check proxy logs for exact time).

```bash
# Check rate limit status
kubectl logs -n netbird -l app=netbird-reverse-proxy 2>&1 | grep "rateLimited"
```

### WireGuard
The proxy needs a fixed WireGuard port (51820) exposed for peer-to-peer tunnels. This only works in single-account deployments (which we use with `SingleAccountModeDomain`).

### Lazy Connection Manager
NetBird 0.74.7+ enables the lazy connection manager by default. Peers only establish WireGuard tunnels when traffic is sent. After a proxy restart, the first request to a service may be slow (~20-30s) while the lazy connection establishes the tunnel.

## Verification

After deployment, verify in the NetBird dashboard:
1. Navigate to **Reverse Proxy** > **Services**
2. Click **Add Service**
3. The domain selector should show `proxy.company.com` with a **Cluster** badge

```bash
# Quick health check
PROXY=$(kubectl get pods -n netbird -l app=netbird-reverse-proxy -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n netbird "$PROXY" -- wget -q -O- http://localhost:8080/healthz | jq .
```

Expected output:
```json
{
  "status": "ok",
  "checks": { "all_clients_healthy": true, "initial_sync_complete": true, "management_connected": true },
  "clients": {
    "d9cemftcs81c73evs2og": {
      "healthy": true,
      "management_connected": true,
      "signal_connected": true,
      "relays_connected": 1,
      "peers_total": 2,
      "peers_connected": 0
    }
  }
}
```

Note: `peers_connected` starts at 0 until the first request triggers the lazy connection.

## Environment Variables Reference

|             Variable             |                  Value                 |                        Description                       |
|----------------------------------|----------------------------------------|----------------------------------------------------------|
| `NB_PROXY_DOMAIN`                | `proxy.company.com`                    | Base domain for services                                 |
| `NB_PROXY_TOKEN`                 | `nbx_...`                              | Access token for management server                       |
| `NB_PROXY_MANAGEMENT_ADDRESS`    | `http://netbird-management-grpc:33073` | Internal management gRPC endpoint                        |
| `NB_PROXY_ALLOW_INSECURE`        | `true`                                 | Allow insecure gRPC (safe on internal network)           |
| `NB_PROXY_ADDRESS`               | `:443`                                 | Main TLS listener address                                |
| `NB_PROXY_ACME_ADDRESS`          | `:80`                                  | HTTP server for ACME http-01 challenges                  |
| `NB_PROXY_ACME_CERTIFICATES`     | `true`                                 | Enable automatic TLS certificates                        |
| `NB_PROXY_ACME_CHALLENGE_TYPE`   | `http-01`                              | ACME challenge type (port 80)                            |
| `NB_PROXY_CERTIFICATE_DIRECTORY` | `/certs`                               | Certificate storage directory                            |
| `NB_PROXY_LOG_LEVEL`             | `info`                                 | Log level                                                |
| `NB_PROXY_WG_PORT`               | `51820`                                | Fixed WireGuard port                                     |
| `NB_PROXY_PRIVATE`               | `true`                                 | Per-account inbound listeners (port 80/443 per account)  |
| `NB_PROXY_CERT_LOCK_METHOD`      | `k8s-lease`                            | Distributed cert lock via k8s leases                     |
| `NB_PROXY_HEALTH_ADDRESS`        | `0.0.0.0:8080`                         | Health check endpoint                                    |
| `NB_DISABLE_CUSTOM_ROUTING`      | `true`                                 | Bypass custom socket-mark dialer (needed for non-root)   |

## Security Context

The proxy container must run as **non-root** (uid 1000) to avoid the `nbnet.NewDialer()` custom socket-mark dialer which causes the embedded client's management connection to hang. With non-root:

- The gRPC `WithCustomDialer` falls back to a standard `net.Dialer{}` (correct behavior)
- `NET_BIND_SERVICE` capability needed to bind ports 80/443
- `NET_ADMIN` capability required for creating the WireGuard tunnel interface (via userspace TUN device)

```yaml
securityContext:
  runAsUser: 1000
  capabilities:
    add:
      - NET_BIND_SERVICE
      - NET_ADMIN
```

## TUN Device

The embedded netbird client needs `/dev/net/tun` for its WireGuard tunnel interface. Mount it as a hostPath volume:

```yaml
volumes:
  - name: tun-device
    hostPath:
      path: /dev/net/tun
volumeMounts:
  - name: tun-device
    mountPath: /dev/net/tun
```

## Relay Ingress

The relay domain `relay.company.com` is managed through Helm in `values.yaml`, NOT a standalone file. The relay ingress routes:

|          Host         |   Path   |        Backend        |
|-----------------------|----------|-----------------------|
| `netbird.company.com` | `/relay` | `netbird-relay:33080` |
| `relay.company.com`   | `/`      | `netbird-relay:33080` |

Verify after deployment:
```bash
kubectl describe ingress -n netbird netbird-relay | grep -E "Host:|/ "
```
