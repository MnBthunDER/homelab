# Homelab HA — Extend NetBird Reverse Proxy into On-Premise Proxmox

## Objective

Replace the single-LXC nginx-proxy-manager with an HA `netbirdio/reverse-proxy:0.74.7` service on the existing 3-node Docker Swarm, providing zero-downtime rolling upgrades and node-level failure tolerance.

## Architecture

```
Cloudflare DNS
  ├── *.company.com.au → Azure LB (YOUR-NETBIRD-IP) → AKS NetBird proxy (unchanged)
  └── *.company.com    → keepalived VIP (192.168.x.100) → Docker Swarm (new)

Both proxies register to the same cluster (same NB_PROXY_TOKEN / NB_PROXY_DOMAIN).
Management distributes routes to both. DNS determines which proxy receives traffic.

Proxmox Cluster (3 nodes)
┌──────────────────────────────────────────────────────────────────┐
│  Node 1                Node 2                Node 3              │
│  ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐ │
│  │ Docker VM 1     │   │ Docker VM 2     │   │ Docker VM 3     │ │
│  │ ┌─────────────┐ │   │ ┌─────────────┐ │   │ ┌─────────────┐ │ │
│  │ │ netbirdio/  │ │   │ │ netbirdio/  │ │   │ │netbirdio/   │ │ │
│  │ │reverse-proxy│ │   │ │reverse-proxy│ │   │ │reverse-proxy│ │ │
│  │ │ replica 1   │ │   │ │ replica 2   │ │   │ │replica 3    │ │ │
│  │ └─────────────┘ │   │ └─────────────┘ │   │ └─────────────┘ │ │
│  │ keepalived      │   │ keepalived      │   │ keepalived      │ │
│  └─────────────────┘   └─────────────────┘   └─────────────────┘ │
│                                                                  │
│  ─────────── NFS share: /opt/netbird-certs ────────────          │
│  ──────── keepalived VIP: 192.168.x.100 ──────────────           │
└──────────────────────────────────────────────────────────────────┘

Each Docker VM has a trunk port → VLANs 10/20/30 for local service access.
```

## Traffic Flows

|             Flow              |                            Path                               |   Handled by    |
|-------------------------------|---------------------------------------------------------------|-----------------|
| External → `*.company.com.au` | Cloudflare → Azure LB → AKS proxy → WireGuard → services      | AKS (unchanged) |
| External → `*.company.com`    | Cloudflare → keepalived VIP → healthy Swarm replica → service | Homelab (new)   |
| Internal → `*.company.com`    | LAN client → keepalived VIP → healthy Swarm replica → service | Homelab (new)   |
| Failover → `*.company.com`    | Cloudflared tunnel (already exists)                           | Independent     |

## ACME Cert Strategy

Shared NFS /certs volume across all 3 Docker VMs:

```
192.168.x.10:/export/netbird-certs  →  /opt/netbird-certs  (on each Docker VM)
                                          └── mounted into container as /certs
```

- All replicas read/write the same `/certs` directory
- `NB_PROXY_CERT_LOCK_METHOD` defaults to file lock — only one replica handles ACME at a time
- Other replicas see the cert already on disk and skip ACME
- If file lock briefly fails, worst case: one replica gets rate-limited, retries later

|       Domain       |            Let's Encrypt reaches           |             ACME handled by             |
|--------------------|--------------------------------------------|-----------------------------------------|
| `*.company.com.au` | Azure LB                                   | AKS proxy (unchanged)                   |
| `*.company.com`    | keepalived VIP → any healthy Swarm replica | Homelab replica that gets the file lock |

## Key Env Differences from AKS


| Variable                      | AKS                                         | Homelab Swarm                          | Reason                                   |
| :---------------------------- | :------------------------------------------ | :------------------------------------- | :--------------------------------------- |
| `NB_PROXY_PRIVATE`            | `true`                                      | **`false`**                            | Accept LAN clients without NetBird agent |
| `NB_PROXY_MANAGEMENT_ADDRESS` | `http://netbird-mgmt...svc.cluster.local:33073` | **`https://netbird.company.com:443`** | External via NGINX ingress               |
| `NB_PROXY_ALLOW_INSECURE`     | `true`                                      | **omit**                               | Let's Encrypt cert is trusted            |
| `NB_PROXY_CERT_LOCK_METHOD`   | `k8s-lease`                                 | **omit** (`file` default)              | No k8s API; file lock on shared NFS      |
| Network                       | container bridge + LB                       | **host**                               | Shares VM's NetBird routes               |

## Implementation Steps

### Phase 1 — NFS Cert Share

On one Proxmox node (or a utility VM), export a small NFS share:

```bash
# On the NFS server (e.g., a Proxmox node or utility VM)
apt install nfs-kernel-server
mkdir -p /export/netbird-certs
chown nobody:nogroup /export/netbird-certs
chmod 775 /export/netbird-certs

# /etc/exports
/export/netbird-certs 192.168.0.0/16(rw,sync,no_subtree_check,no_root_squash)

exportfs -a
systemctl restart nfs-kernel-server
```

On each Docker VM:

```bash
apt install nfs-common
mkdir -p /opt/netbird-certs
echo "192.168.x.10:/export/netbird-certs /opt/netbird-certs nfs defaults 0 0" >> /etc/fstab
mount -a
```

### Phase 2 — Docker Swarm Service

Create the compose file:

```yaml
# /opt/netbird-proxy/docker-compose.yml
services:
  reverse-proxy:
    image: netbirdio/reverse-proxy:0.74.7
    network_mode: host
    cap_add:
      - NET_BIND_SERVICE
      - NET_ADMIN
    volumes:
      - /opt/netbird-certs:/certs
      - /dev/net/tun:/dev/net/tun
    environment:
      - NB_PROXY_DOMAIN=proxy.company.com
      - NB_PROXY_TOKEN=nbx_YOURTOKEN
      - NB_PROXY_MANAGEMENT_ADDRESS=https://netbird.company.com:443
      - NB_PROXY_PRIVATE=false
      - NB_PROXY_ADDRESS=:443
      - NB_PROXY_ACME_CERTIFICATES=true
      - NB_PROXY_ACME_CHALLENGE_TYPE=http-01
      - NB_PROXY_ACME_ADDRESS=:80
      - NB_PROXY_CERTIFICATE_DIRECTORY=/certs
      - NB_PROXY_WG_PORT=51820
      - NB_PROXY_LOG_LEVEL=info
      - NB_PROXY_HEALTH_ADDRESS=0.0.0.0:8080
      - NB_DISABLE_CUSTOM_ROUTING=true
    deploy:
      mode: replicated
      replicas: 3
      update_config:
        parallelism: 1
        delay: 15s
        order: start-first
      restart_policy:
        condition: any

networks:
  host:
    external: true
```

Deploy:

```bash
mkdir -p /opt/netbird-proxy
docker stack deploy -c /opt/netbird-proxy/docker-compose.yml netbird-proxy
```

Verify:

```bash
docker service ls
docker service ps netbird-reverse-proxy
```

### Phase 3 — keepalived VIP

Each Docker VM runs keepalived with a health check against the proxy's `/healthz` endpoint.

```bash
# Install on each Docker VM
apt install keepalived
```

```
# /etc/keepalived/keepalived.conf — same on all 3 VMs
global_defs {
  enable_script_security
}

vrrp_script check_proxy {
  script "/usr/bin/curl -sf http://localhost:8080/healthz"
  interval 5
  fall 2
  rise 2
}

vrrp_instance proxy_vip {
  state BACKUP
  interface eth0
  virtual_router_id 51
  priority 100     # VM1=100, VM2=90, VM3=80
  advert_int 1
  authentication {
    auth_type PASS
    auth_pass supersecret
  }
  virtual_ipaddress {
    192.168.x.100/24
  }
  track_script {
    check_proxy
  }
}
```

```bash
systemctl enable --now keepalived
```

### Phase 4 — Verify

```bash
# Health check on any node
curl -f http://localhost:8080/healthz

# Check VIP
ip addr show | grep 192.168.x.100

# Verify cert directory shared
ls /opt/netbird-certs

# Check Swarm status
docker service ps netbird-reverse-proxy
```

### Phase 5 — Configure in NetBird Dashboard

For each `*.company.com` service:
1. Dashboard → **Reverse Proxy** → **Add Service**
2. Subdomain + base domain (`company.com`)
3. Add Target:
   - Type: **Host** → enter local LAN IP:port
   - Accessible through routing peers that have routes to the subnet
4. Configure authentication as needed

### Phase 6 — DNS change

- Point `*.company.com` Cloudflare DNS → keepalived VIP (`192.168.x.100`)
- Point internal DNS → same VIP

### Phase 7 — Cutover

1. Stop the old NPM LXC
2. Test one service at a time
3. Monitor logs:

```bash
docker service logs netbird-reverse-proxy --tail 20 -f
```

## Upgrades (zero downtime)

```bash
docker service update \
  --image netbirdio/reverse-proxy:NEWTAG \
  --update-parallelism 1 \
  --update-delay 15s \
  netbird-reverse-proxy
```

If the new version fails health checks, Swarm rolls back automatically. To force a rollback:

```bash
docker service rollback netbird-reverse-proxy
```

## Failover Scenarios

| Failure | Impact | Recovery |
|---------|--------|----------|
| Docker VM dies | ~5–10s | Swarm reschedules replica on another node |
| Proxy container crashes | ~5s | Swarm replaces it |
| Entire Proxmox node dies | ~10–15s | Swarm reschedules 1 replica to remaining VMs |
| AKS proxy dies | `*.company.com.au` affected | `*.company.com` still works via homelab |
| Homelab completely down | Both domains affected | Cloudflared tunnel failover (already in place) |
| Rolling upgrade (planned) | Zero | Swarm replaces 1 replica at a time, keepalived routes to healthy replicas |

## DNS Reference

| Record | Value | Notes |
|--------|-------|-------|
| `*.company.com.au` | `YOUR-NETBIRD-IP` (Azure LB) | Cloudflare → AKS |
| `*.company.com` (ext) | keepalived VIP or NAT | Cloudflare → Homelab Swarm |
| `*.company.com` (int) | `192.168.x.100` (keepalived VIP) | Internal DNS |

## Troubleshooting

### Proxy won't start

```bash
docker service logs netbird-reverse-proxy 2>&1 | grep -i error
```

Check per-replica:

```bash
docker service ps netbird-reverse-proxy --no-trunc
```

### Health check fails

```bash
curl -v http://localhost:8080/healthz
```

### ACME rate limited

```bash
docker service logs netbird-reverse-proxy 2>&1 | grep -i rateLimited
```

Rate limits reset 168h after the last failed attempt. Exact retry time is in the error message.

### WireGuard issues

```bash
ls -la /dev/net/tun
docker inspect $(docker ps -q) | jq '.[].HostConfig.CapAdd'
```

### VIP not working

```bash
ip addr show | grep 192.168.x.100
systemctl status keepalived
curl -sf http://localhost:8080/healthz
```

### Rolling upgrade stalled

```bash
docker service ps netbird-reverse-proxy
docker service rollback netbird-reverse-proxy
```
