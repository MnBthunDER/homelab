# Use NFS Share (from Synology NAS) to Jellyfin LXC: https://forum.proxmox.com/threads/use-nfs-share-from-synology-nas-to-jellyfin-lxc.143018/
# [Tutorial] Mounting NFS share to an unprivileged LXC: https://forum.proxmox.com/threads/tutorial-mounting-nfs-share-to-an-unprivileged-lxc.138506/
# Tutorial: Unprivileged LXCs - Mount CIFS shares: https://forum.proxmox.com/threads/tutorial-unprivileged-lxcs-mount-cifs-shares.101795/
# Proxmox CIFS Share Mount Wizard Script: https://gist.github.com/NorkzYT/14449b247dae9ac81ba4664564669299

##############################
#                            #
# On PVE                     #
#                            #
##############################

# Source: https://community-scripts.github.io/ProxmoxVE/scripts?id=jellyfin
# Run this command on PVE host to install Jellyfin in a container:
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/jellyfin.sh)"

##############################
#                            #
# On jellyfin LXC container  #
#                            #
##############################

# Source: https://forum.proxmox.com/threads/tutorial-unprivileged-lxcs-mount-cifs-shares.101795/
# Source: https://github.com/JamesTurland/JimsGarage/tree/main/LXC/NAS
# Create the group for the shared folder
groupadd -g 10000 lxc_shares
usermod -aG lxc_shares root

# Shutdown
# poweroff

##############################
#                            #
# On PVE                     #
#                            #
##############################

# Back to PVE host and create the NFS mount
mkdir -p /mnt/media

# Add the following line to the fstab file
{ echo '' ; echo '# Mount NFS share on demand with rwx permissions for use in LXCs ' ; echo '10.1.10.10:/volume1/media /mnt/media nfs defaults 0 0' ; } | tee -a /etc/fstab

# Check the fstab was added to the NFS mount
nano /etc/fstab

# Mount the NFS share
mount /mnt/media

# Restart the daemon   
systemctl daemon-reload

# Check the mount
cd /mnt/media
ls -ld

# Edit the config for the Jellyfin LXC on PVE host
cd /etc/pve/lxc
ls
nano 40011.conf

# Add permissions to the config file with read-only permission
{ echo 'mp0: /mnt/media,mp=/mnt/media' ; } | tee -a /etc/pve/lxc/40011.conf

##############################
#                            #
# On jellyfin LXC container  #
#                            #
##############################

# Go back to the Jellyfin LXC container
# Power On
cd /mnt/media
ls -ld
