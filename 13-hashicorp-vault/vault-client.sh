# How To Setup Hashicorp Vault Creating And Accessing Secrets: https://www.youtube.com/watch?v=LEpk376fc-U
# Install Vault: https://developer.hashicorp.com/vault/install

## This instruction is for Vault Client Side Access ##
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
--2026-05-29 14:18:28--  https://apt.releases.hashicorp.com/gpg

# For Debian-based distributions, add the HashiCorp GPG key and repository (Website sample only works for Ubuntu):
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com trixie main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
# Or using the variable directly:
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=VERSION_CODENAME=).*' /etc/os-release) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Install Vault
sudo apt update && sudo apt install vault

# To unlock main vault, you need to enter the unseal key 3 times, follow by the root token to login:
export VAULT_ADDR=https://vault.company.com VAULT_SKIP_VERIFY=true
vault status
vault operator unseal
vault login


