# Hermes Agent — Docker Swarm Homelab

How this stack is built, and the full troubleshooting history behind it.
Keep this next to `docker-compose.yaml` — future-you will thank present-you.

## Stack overview

- **Stack name:** `hermes-agent` (services are `hermes-agent_hermes-agent`,
  `hermes-agent_hermes-webui` — note the prefix, not `hermes_...`)
- **Services:** `hermes-agent` (`nousresearch/hermes-agent:latest`: gateway
  `:8642` + unified dashboard `:9119`) and `hermes-webui`
  (`ghcr.io/nesquena/hermes-webui:latest`, chat UI `:8787`)
- **State:** NAS binds — `/mnt/nas-nfs/hermes/hermes-home` is the single
  Hermes home (`.env`, `config.yaml`, `auth.json`, sessions, skills);
  `/mnt/nas-nfs/hermes/hermes-workspace` is the WebUI workspace.
  The NAS path **must exist on every Swarm node** (or pin placement).
- **Network:** overlay `hermes-net`; all three ports published ingress
  (all nodes, all interfaces) — LAN-only by policy, gated by passwords/keys.

## Deploy procedure

```bash
set -a; source .env; set +a
docker stack deploy -c docker-compose.yaml hermes-agent
docker service ps hermes-agent_hermes-agent hermes-agent_hermes-webui --no-trunc
docker service logs hermes-agent_hermes-agent -f
```

Prefer `stack deploy` (rolling update) over `stack rm` + redeploy.
Never delete anything under `/mnt/nas-nfs`.

## Secrets (Docker Swarm)

Swarm secrets (see `docker secret ls` on a manager):

| Secret                  | Consumed as                  | By            |
|-------------------------|------------------------------|---------------|
| `HERMES_API_SERVER_KEY` | `API_SERVER_KEY`             | agent + webui |
| `HERMES_WEBUI_PASSWORD` | `HERMES_WEBUI_PASSWORD`      | webui         |

Neither image implements `*_FILE` env support, so each service mounts the
secret as a file and exports it in its startup wrapper (`$$` escapes Compose
interpolation):

- **Agent** exports in `entrypoint:` (NOT `command:`) — the image's stage2
  hook runs *before* CMD and generates a random key into `.env` if it can't
  see one, which would then shadow the secret at runtime (Hermes loads `.env`
  with override semantics). Entrypoint export makes the hook log
  `API_SERVER_KEY provided via container environment — skipping generation`
  and execs the stock dispatcher as PID 1 (`/init` + s6 intact).
- **WebUI** exports in `command:` before the stock `/hermeswebui_init.bash`
  (which takes no args and ends in `python server.py`), preserving its
  root-init → `hermeswebui` → server chain, including env propagation.

Rules learned the hard way:

- Create with `printf`, never `echo` (trailing `\n` becomes part of the
  secret and silently breaks logins):
  `printf '%s' '<value>' | docker secret create NAME -`
- Secrets are **immutable**: rotate via v2 name → repoint service →
  redeploy → `docker secret rm` old.
- Nothing secret in compose `environment:` (lands in `service inspect`).

## Troubleshooting history

### 1. Dashboard refused `0.0.0.0:9119` bind (auth gate)

`Refusing to bind dashboard to 0.0.0.0 — no auth providers are registered.`
Fail-closed by design: non-loopback bind requires `dashboard.basic_auth`
(or OAuth/OIDC). Fix = `dashboard.basic_auth.username` + real scrypt
`password_hash` in production `config.yaml` (generate in-container:
`python -c "from plugins.dashboard_auth.basic import hash_password; ..."`),
plus `HERMES_DASHBOARD_BASIC_AUTH_SECRET` in `.env` for stable sessions.
Healthy sign: `HERMES_DASHBOARD_READY port=9119` in agent logs.

### 2. `config.yaml` indent break at line 88

`expected <block end>, but found '<block mapping start>' ... line 88`.
Cause: a pasted `fallback_providers:` dict at column 0 split the `model:`
block, orphaning template keys below it. Fix: 2-space indent throughout,
`fallback_providers:` as a **top-level list** (`- provider: ...`), one
`provider:`/`base_url:` pair in `model:` (template `auto`/openrouter
defaults commented out).

### 3. `config.yaml` UTF-8 decode failure (`0x97`)

`'utf-8' codec can't decode byte 0x97` — a UTF-8 em-dash mangled to
Windows-1252 by a clipboard/editor round-trip. Fixed by sanitizing the file
to pure ASCII (all non-ASCII lived in comments). Lesson: transfer the file
binary-safe (`scp`/`rsync`, or edit on the host with nano/vim — never
Windows Notepad paste), and pre-verify:
`python3 -c "open('config.yaml',encoding='utf-8').read();print('UTF-8 OK')"`.

### 4. `config predates version 12` warning

Old schema; loads but won't auto-migrate. Resolve via `hermes setup`
regen or set `_config_version: 12` after reviewing the changelog.

### 5. Nous Portal "No access token found" (WebUI + gateway)

Two facts: (a) Nous OAuth is **terminal-first by design** (WebUI deliberately
has no login button — it only detects a login in `auth.json`), and (b) there
are two Nous routes: `nous` = OAuth login (Portal account, no paid key) vs
`nous-api` = `NOUS_API_KEY` (paid). Fix in the **agent** container:
`hermes auth add nous --type oauth` (`hermes auth` alone opens the
credential-pool menu — wrong place), approve the device-code URL in a
browser, verify `auth.json` mtime in the live NAS home, then
`docker service update --force hermes-agent_hermes-agent` (gateway reads
auth at boot). `hermes portal info` confirms.

### 6. Nous tokens expire hourly — normal

`expires_at` ≈ `obtained_at` + 1h is by design (short-lived JWT). The
refresh token in `auth.json` (+ `shared/nous_auth.json`) renews silently —
no re-login needed. Re-authenticate only on refresh failure
(`invalid_grant`/`relogin_required`, or "No access token" *despite*
`auth.json` existing). Redacted check (names only, never values):
`python3 -c "import json;a=json.load(open('auth.json'));print(list(a.get('providers',{}).keys()))"`.

### 7. Auth "lost" after stack recreate

`stack rm`/`deploy` never deletes bind data, so loss = new/empty home.
Causes in order: (a) home **path** changed between deploys (a new path is a
fresh login — compare `auth.json` mtimes across candidate dirs);
(b) task landed on a **node without the NAS mount** (Docker creates an
empty local dir — check `service ps` node + mount, or pin placement with
`node.labels.hermes == true`); (c) two writers on one home (fixed by the
single-writer layout); (d) server-side token revocation. Survival rules:
stable home path, NAS on all nodes (or pin), deploy-over-rm, and keep
backups of `auth.json` + `.env` + `config.yaml`.

### 8. Gateway 401s after secrets migration (split-brain)

`API server rejected invalid API key ... /health/detailed` every 30s =
WebUI probe presenting a different key than the gateway checks. Sequence
was: (a) stale `API_SERVER_KEY=` line in NAS `.env` shadowed the new
secret (delete just that line, preserving owner/mode via `grep -v` +
`cat >`, never `sed -i`/`mv` on NFS); then (b) the stage2 hook regenerated
a random key because the export ran post-hook — fixed by moving the agent
export to `entrypoint:`; verify via the "skipping generation" log line,
then a 2-cycle count:
`sleep 150; docker service logs hermes-agent_hermes-agent --since 3m 2>&1 | grep -c 'rejected invalid API key'` → expect `0`.

### 9. Network audit dispositions (LAN-only posture)

- `0.0.0.0:8787` is **intentional**: Swarm has no per-service loopback
  publish, and ingress delivers to the container's overlay IP — binding
  `127.0.0.1` would lock out even SSH tunnels, not "restrict to LAN".
  Control = secret-backed password, not the bind address.
- `GPG_KEY` in env is a **false positive**: public build key baked into the
  official `python:3.12-slim` base image, not a secret.
- `10.0.0.0/8` chatter is Swarm overlay (probes, mesh forwarding) — benign.
- `127.0.0.1`-only listeners are unreachable remotely; identify strays
  with `ss -tlnp`.
- The dead `replicas: 0` dashboard service was removed (it never ran).

## Deferred / known-open items

- Host-level firewall segmentation (note: plain UFW `deny` doesn't reliably
  block ingress-published ports; verify from an untrusted host; never block
  tcp 2377, tcp/udp 7946, udp 4789, or NFS 2049).
- Real dashboard `:9119` password hash (placeholder = nobody can log in).
- Telegram/messaging allowlists (`No env user allowlists` warning).
- Gateway's unsandboxed-terminal warning → consider `terminal.backend: docker`.
- `Auxiliary openrouter/nous unhealthy` log noise (side tasks only).

## References

- https://dev.to/dalenguyen/free-model-providers-to-use-with-hermes-agent-13l9
- https://github.com/nesquena/hermes-webui/blob/master/docs/docker.md
- Official guide: https://hermes-agent.nousresearch.com/docs/user-guide/docker
