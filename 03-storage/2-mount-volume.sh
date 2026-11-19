# Create share folder and enable NFS permission IP range based

# On your linux OS
############## NFS ######################

# Create a mount point
mkdir -p /mnt/Movies

# Install NFS client
apt update
apt install -y nfs-common

# Mount the NFS share during boot
nano /etc/fstab
10.1.10.10:/volume1/Movies /mnt/Movies nfs4 defaults,_netdev 0 0 # Synology Media share
10.1.30.27:/srv/dockerdata /mnt/nas-nfs nfs defaults 0 0 # Docker Swarm data share

# Mount the NFS share
mount -a

# On your PVE Host
############## CIFS ######################

# Install CIFS utilities for SMB share
apt update
apt install -y cifs-utils

# Create SMB credentials file
nano /root/.smbcred

# Add the following lines to the file
username=yourusername
password=yourpassword

# Secure the credentials file
chmod 600 /root/.smbcred

# Add SMB share to fstab for mounting
nano /etc/fstab

# Mount CIFS share on demand for use in LXCs (Read Only)
//10.1.10.10/media /mnt/media cifs credentials=/root/.smbcred,vers=3.1.1,iocharset=utf8,serverino,_netdev,x-systemd.automount,nofail 0 0

# Mount CIFS share on demand for use in LXCs (Read & Write)
//10.1.10.10/workspace /mnt/workspace cifs credentials=/root/.smbcred,vers=3.1.1,iocharset=utf8,serverino,_netdev,x-systemd.automount,nofail,uid=100000,gid=100000,file_mode=0777,dir_mode=0777 0 0

# Mount CIFS shared on demand for use in Docker VM (Read & Write)
//10.1.10.10/workspace /mnt/workspace cifs credentials=/root/.smbcred,vers=3.1.1,iocharset=utf8,serverino,_netdev,x-systemd.automount,nofail,uid=1000,gid=1000 0 0

# Reload systemd to apply changes
systemctl daemon-reload

# Mount the NFS / CIFS share
umount /mnt/media
umount /mnt/workspace
mount -a

# Ensure your LXCs is offline, then add the new mount points to the LXC config file
nano /etc/pve/lxc/40015.conf
mp0: /mnt/workspace,mp=/mnt/workspace

nano /etc/pve/lxc/40011.conf
mp0: /mnt/media,mp=/mnt/media


# Start LXCs to apply new mounts

# Docker Swarm NFS Mount
/srv/dockerdata