# Pre-requisite check Synology nfs mount is active and take note of the nfs info:
# Check NFS Permission and make sure the required IPs are added
# Video: https://www.youtube.com/watch?v=eKAQiYu4NyI&t=616s
# Swarm: https://www.youtube.com/watch?v=ivEQ3rFe-sg

    cat /etc/exports
    /volume1/nas-nfs        ip/mask (rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100)admin@NAS1:/volume1/nas-nfs$

# Testing
# Login to Portainer
# Volume + Add NFS volume
    Name: swm1-nfs-volume
    Driver: local
    NFS Settings
        Address: %storage-ip%
        Use NFS volume: Yes
        NFS Version: NFS4
        Mount Point: /volume1/nas-nfs/
        Options: rw,noatime,rsize=8192,wsize=8192,tcp,timeo=14 # Leave as default
        Node: All

# To test mount point from Portainer to nas-nsf
    Create an ubuntu container
    Commands & logging
        Enable Console Ineractive & TTY
    Volumes
        Container: /nfs
        volume: nas-nfs - local

# Deploy the container and open the console
    ls

# Navigate to  nfs directory and create test file
    cd /nfs
    touch test.txt


# Portainer stacks yaml volumes mappings:
    container: /unifi/data
    type: bind
    host: /mnt/nas-nfs/unifi-controller/data

    container: /unifi/cert
    type: bind
    host: /mnt/nas-nfs/unifi-controller/cert

    container: /unifi/log
    type: bind
    host: /mnt/nas-nfs/unifi-controller/log



# Check Ownership & Permissions
# If you're setting PGID=1000 and PUID=1000 on yaml scripts, ensure that the /mnt/nas-nfs/unifi/unifi-db directory is owned by UID/GID 1000:1000 (or the same as the user running the container). Run:

    ls -l /mnt/nas-nfs/unifi
    ls -ld /mnt/nas-nfs/unifi/unifi-db
    If the owner is not 1000:1000, change it:
























# Still testing below did not work.

# Prepare Docker Swarm nodes mount path

    # Check if there's existing mount
        mount | grep nas-nfs

    # install nfs-common services
        apt update && apt install -y nfs-common

    # If not found execute mount pointing to the PVE Storage at Datacentre / Cluster
        mkdir -p /mnt/nas-nfs
        mount -t nfs 10.1.10.10:/volume1/nas-nfs/docker /mnt/nas-nfs

    # Make the mount persistent
        nano /etc/fstab
        10.1.10.10:/volume1/nas-nfs/docker /mnt/nas-nfs nfs defaults,_netdev 0 0
        reboot

    # Check if data from NAS is now showing on all nodes
        cd /mnt/nas-nfs


# For Docker Swarm, refer to Volume + Add NFS volume and repeat the same steps for each nodes pointing to the same NFS mount point

docker volume create --driver - local --name unifi-controller type=nfs4 --opt device=/volume1/nas-nfs/docker/unifi-controller/data --opt o=addr=10.1.10.10,rw,noatime,rsize=8192,wsize=8192,tcp,timeo=14

    mount 10.1.10.10:/volume1/nas-nfs/docker/unifi-controller/data /var/lib/docker/volumes/swm1-nas-nfs-unifi-controller/_data

# To remove volume
docker volume rm unifi-controller