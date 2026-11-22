# NetBird Helm Chart for Kubernetes

https://github.com/netbirdio/helms/tree/main/charts/netbird

## Prerequisites
- Helm 3.x
- Kubernetes 1.19+
- NGINX Ingress Controller
- cert-manager (optional, for TLS)

## Key Architecture Notes

### Current Versions
|   Component   | Version |                    Notes                   |
|---------------|---------|--------------------------------------------|
| Chart         |  1.9.0  | Ships with management v0.46.0              |
| Management    |  0.74.7 | Overridden in values.yaml for embedded IdP |
| Dashboard     | v2.90.4 |                                            |
| Reverse Proxy |  0.74.7 | Pinned in `proxy-setup.yaml`               |
| Signal        |  latest | Pin in values.yaml if needed               |
| Relay         |  latest | Pin in values.yaml if needed               |

### Embedded IdP (Dex)
The management server v0.74.7 includes an embedded Dex server for local user management.
No external IdP (Auth0, etc.) is required.

### Critical Configuration Details

1. **Encryption key must be in config JSON**: The `EnsureEncryptionKey` function reads from the config struct, NOT env vars. The key goes in `DataStoreEncryptionKey` field directly in the config JSON.

2. **Config path**: Management server v0.74.7 defaults to `/etc/netbird/config.json`. The Helm chart hardcodes the configmap key as `management.json` mounted at `/etc/netbird/management.json`. Must use `--config=/etc/netbird/management.json` in podCommand args.

3. **Embedded IdP Issuer MUST include `/oauth2` suffix**: The management server routing only forwards `/oauth2*` paths to the Dex handler. If the issuer is `https://domain.com`, the well-known and keys endpoints won't be reachable. Use `https://domain.com/oauth2` so OIDC endpoints are served under `/oauth2/.well-known` and `/oauth2/keys`.

4. **HttpConfig is IGNORED when EmbeddedIdP is enabled**: The code explicitly warns and overrides it. Remove the `HttpConfig` section from the config when using embedded IdP.

5. **Dashboard redirect URIs**:
   - `AUTH_REDIRECT_URI` must be a relative path (e.g., `/nb-auth`), NOT a full URL. The dashboard prepends the base URL.
   - Register redirect URIs with Dex via `EmbeddedIdP.DashboardRedirectURIs` in the config.
   - The base URL is derived by stripping `/oauth2` from the issuer.

6. **Dashboard env vars for embedded IdP**:
   - `AUTH_AUTHORITY: https://domain.com/oauth2`
   - `AUTH_REDIRECT_URI: /nb-auth` (relative!)
   - `AUTH_SILENT_REDIRECT_URI: /nb-silent-auth` (relative!)
   - `USE_AUTH0: "false"`
   - `NETBIRD_TOKEN_SOURCE: accessToken`

### Relay Configuration
The relay address is `rels://relay.company.com:443`. This domain must be:
1. Added to the Helm-managed relay ingress (in `values.yaml`)
2. Pointed to the NGINX Ingress LB IP in DNS

### Reverse Proxy
The reverse proxy is deployed via `proxy-setup.yaml` (NOT managed by Helm).
It requires:
- `NET_ADMIN` + `NET_BIND_SERVICE` capabilities
- `/dev/net/tun` hostPath volume
- Image tag pinned to match management version

### Secrets
Generated secrets (store in Kubernetes Secret `netbird-secrets`):
- `datastoreEncryptionKey`: YOURDATASTOREENCRYPTIONKEY
- `relayPassword`: YOURRELAYPASSWORD

### Ingress Paths
Management ingress requires these paths:
- `/api` - Management REST API
- `/oauth2` - Embedded Dex OIDC endpoints (auth, token, device/code, keys, well-known)
- `/instance` - Instance setup status
- `/setup` - Setup endpoint (may 404 if instance already configured)

### Common Issues
- **CrashLoopBackOff with "DataStoreEncryptionKey is not set"**: Put the key directly in config JSON `DataStoreEncryptionKey` field
- **"failed to create embedded IDP service: issuer is required"**: Add `Issuer` field to `EmbeddedIdP` config
- **"unregistered redirect_uri"**: Register redirect URIs in `EmbeddedIdP.DashboardRedirectURIs`
- **Dashboard shows doubled URL in redirect**: Use relative paths for `AUTH_REDIRECT_URI`
- **Proxy ACME rate limited**: Multiple pod restarts triggered too many cert requests. Pin image tags and wait for rate limit window to reset. Check with: `kubectl logs -n netbird -l app=netbird-reverse-proxy 2>&1 | grep rateLimited`
- **Peers not connecting after upgrade**: Restart the reverse proxy and wait for lazy connections to establish. First request may be slow.
