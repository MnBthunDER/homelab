# Prerequisites - Debian LXC
apt update && apt upgrade -y
apt install curl

# OpenCode CLI installation
curl -fsSL https://opencode.ai/install | bash

# OpenCode json files are stored in ~/.config/opencode/
nano ~/.config/opencode/opencode.json

# OpenCode Web UI
opencode web --hostname 0.0.0.0
opencode web
OPENCODE_SERVER_PASSWORD=secret opencode web

# OpenCode List Chat History or Cleanups
opencode session list
~/.local/share/opencode/storage/session_diff
    rm *.json
~/.local/share/opencode/opencode.db
    mv opencode.db opencode.db.bak