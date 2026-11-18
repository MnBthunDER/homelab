# Ensure hardware is healthy with latest firmware updates, and compatible with virtualization technology on BIOS
# Pre-requisite: Ensure your firewall and switches are prepared with the required LACP or vlan as required
# You cannot configure vlan on the initial install, we can do that after the install completes

https://www.youtube.com/watch?v=GoZaMgEgrHw

# Download Proxmox VE ISO Installer and create bootable ISO and install under normal dhcp network first (Not vlan aware on installation mode)
        Download link: https://www.proxmox.com/en/downloads
        Install Guide: https://www.youtube.com/watch?v=UzNHno-viRk
        Post-install Guide: https://www.youtube.com/watch?v=kqZNFD0JNBc

        # Upon successful install login with the ip showing on screen.
        https://127.0.0.1:8006/


# Post install prep works (optional)
# https://youtu.be/GoZaMgEgrHw
# https://www.youtube.com/watch?v=gHBSrENzeqk&t=146s
# https://www.youtube.com/watch?v=bxR8bjJWcCU


# Proxmox VE Helper-Scripts
https://community-scripts.github.io/ProxmoxVE/scripts