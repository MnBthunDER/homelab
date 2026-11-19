# Docker Vault Server Access via Portainer via sh:

/vault/config $ export VAULT_ADDR=https://127.0.0.1:8200 VAULT_SKIP_VERIFY=true
/vault/config $ vault status
Key                     Value
---                     -----
Seal Type               shamir
Initialized             true
Sealed                  true
Total Shares            5
Threshold               3
Unseal Progress         0/3
Unseal Nonce            n/a
Version                 2.0.1
Build Date              2026-05-19T17:20:48Z
Storage Type            raft
Removed From Cluster    false
HA Enabled              true

# To unlock main vault, you need to enter the unseal key 3 times, follow by the root token to login:
vault operator unseal
vault login
