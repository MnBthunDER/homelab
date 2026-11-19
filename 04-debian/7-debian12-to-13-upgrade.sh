# Here's the full plan based on your answers. I'll break it into phases.
# Plan: Debian 12 → 13 Upgrade (3 Swarm Manager Nodes) + xterm.js Fix
# Phase 0: Pre-Flight Checks (on each VM)
# Run these on all 3 VMs and record results:
# 1. Confirm current OS version
cat /etc/os-release | grep PRETTY_NAME

PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"

# 2. Check free disk space (need ≥5GB)
df -h /

  Filesystem                     Size  Used Avail Use% Mounted on
  /dev/mapper/debian12--vg-root  6.1G  2.9G  2.9G  51% /

# 3. Check Docker version
docker version

  Client: Docker Engine - Community
  Version:           29.3.0
  API version:       1.54
  Go version:        go1.25.7
  Git commit:        5927d80
  Built:             Thu Mar  5 14:25:43 2026
  OS/Arch:           linux/amd64
  Context:           default

  Server: Docker Engine - Community
  Engine:
    Version:          29.3.0
    API version:      1.54 (minimum version 1.40)
    Go version:       go1.25.7
    Git commit:       83bca51
    Built:            Thu Mar  5 14:25:43 2026
    OS/Arch:          linux/amd64
    Experimental:     false
  containerd:
    Version:          v2.2.1
    GitCommit:        dea7da592f5d1d2b7755e3a161be07f43fad8f75
  runc:
    Version:          1.3.4
    GitCommit:        v1.3.4-0-gd6d73eb8
  docker-init:
    Version:          0.19.0
    GitCommit:        de40ad0

# 4. Check if serial port is configured (for xterm.js)
ls -l /dev/ttyS*
dmesg | grep ttyS

  crw-rw---- 1 root dialout 4, 64 Jun  2 17:08 /dev/ttyS0
  crw-rw---- 1 root dialout 4, 65 Jun  2 17:08 /dev/ttyS1
  crw-rw---- 1 root dialout 4, 66 Jun  2 17:08 /dev/ttyS2
  crw-rw---- 1 root dialout 4, 67 Jun  2 17:08 /dev/ttyS3

# To check Proxmox-side serial port config (from Proxmox host CLI, or Web UI → VM → Hardware):
# For each VM_ID, run on the Proxmox host
qm config <VM_ID> | grep -E "serial|vga|display"

# Look for:
# - serial0: socket — needed for xterm.js
# - vga: serial0 or display: serial0 — tells Proxmox to use serial terminal
# Phase 1: Fix xterm.js On Each VM (do before the OS upgrade)
# Do this for all 3 VMs (one at a time, at your convenience since you have noVNC as fallback):

# Step A — Add serial hardware (from Proxmox host):
# Only if serial0 is not already present
qm set <VM_ID> -serial0 socket

# Step B — Configure GRUB for serial console (inside each VM via noVNC or SSH):
nano /etc/default/grub
  # Change GRUB_CMDLINE_LINUX_DEFAULT to:
  GRUB_DEFAULT=0
  GRUB_TIMEOUT=5
  GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`
  GRUB_CMDLINE_LINUX_DEFAULT=""
  GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200 earlyprintk=ttyS0,115200 consoleblank=0"
  GRUB_TERMINAL_OUTPUT="gfxterm serial"
  GRUB_SERIAL_COMMAND="serial --speed=115200"

# Then run:
sudo update-grub

# Step C — Set display to serial0 (from Proxmox host):
# qm set <VM_ID> -display serial0
qm set <VM_ID> --serial0 socket

# Step D — Shut down and power on the VM (a soft reboot isn't enough — serial port attach requires full power cycle):
qm shutdown <VM_ID> && sleep 10 && qm start <VM_ID>
# Now xterm.js should work as a console option.

# Phase 2: OS Upgrade — Node-by-Node (3 managers, 1 at a time)
# With 3 managers, Swarm needs ≥2 managers up for quorum. Upgrade one at a time.
On each VM (sequence for Node A → Node B → Node C):
# 1. Drain the node from Swarm (on any operational manager node)
docker node update --availability drain <node-hostname>

# 2. SSH into the node being upgraded and update current Debian 12 fully
apt update && apt upgrade -y && apt full-upgrade -y
apt autoremove --purge -y

# Disable old source list
nano /etc/apt/sources.list
# Comment all

# 3. Switch APT sources from bookworm to trixie
cd /etc/apt/sources.list.d
nano debian.sources

Types: deb
URIs: https://deb.debian.org/debian
Suites: trixie trixie-updates
Components: main non-free-firmware
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: https://security.debian.org/debian-security
Suites: trixie-security
Components: main non-free-firmware
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

# 4. Update package lists and perform the upgrade
apt update -y ; apt full-upgrade -y                     # this will pull in the new kernel, systemd, OpenSSL, and all the other Debian 13 packages

# If you encounter GPG errors about missing keys, run:
sudo apt install debian-archive-keyring debian-keyring  # if GPG errors
sudo apt upgrade --without-new-pkgs -y                  # minimal upgrade first
sudo apt full-upgrade -y                                # the big one

# Keep local version of ssh keys and grub config if prompted, since you likely customized those. For other configs, usually safe to keep your current version if you've made changes.

# 5. Reboot
sudo reboot
# Key gotchas during apt full-upgrade:
# - /usr merge: Trixie completes the /usr merge (/bin, /sbin, /lib become symlinks to /usr/ counterparts). This is handled automatically but don't interrupt it.
# - Systemd 252 → 257: Docker/Cri will restart. That's fine.
# - Config file prompts: Usually keep your current version for configs you've customized.
# - Third-party repos (Docker's own repo, NodeSource, etc.): These may need updating from bookworm to trixie in their source entries, or may not support Trixie yet. Docker's official repo does support Trixie.
# After reboot — verify and re-activate in Swarm:
# Verify the release
cat /etc/os-release    # Should say "Debian GNU/Linux 13 (trixie)"
docker version         # Docker should still be intact

# On another manager node, re-enable the upgraded node
docker node update --availability active <node-hostname>
# Wait for the node to fully rejoin and stabilize before moving to the next node.
# Phase 3: Post-Upgrade Cleanup (after all 3 are done)
# On each VM:
sudo apt autoremove --purge -y
sudo apt clean
docker system df            # check Docker disk usage
# Risks & Things to Watch For
# Risk	Mitigation
# Docker Engine compatibility with Trixie	Debian 13 point releases are well-established (13.4). Docker CE has official packages for trixie. If Docker's repo lacks Trixie support, temporarily pin to Bookworm Docker version.
# Kernel 6.1 → 6.12 LTS	Major kernel jump. Check that Docker and your storage drivers (overlay2) work. Overlay2 is well-supported on 6.12.
# OpenSSL 3.0 → 3.5	Could affect apps that link against OpenSSL. Test after upgrade.
# Third-party Docker images have baked-in OS assumptions	If you run custom Dockerfiles based on Debian 12, those are unaffected (they're containers). Only the host OS changes.
# Swarm raft log / etcd store	Intact as long as ≥2 managers stay up during the process.
# Rough Timeline (per node, assuming decent hardware)
# Step
# xterm.js fix (per VM)
apt update && apt upgrade
apt full-upgrade
# Reboot + verify
# Total per node
# With 3 nodes done sequentially: ~1-2.5 hours total.