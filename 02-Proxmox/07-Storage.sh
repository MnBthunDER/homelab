# Login to Synology
    # Control Panel > File Services > NFS > enable NFS under File services (NFSv4)
    # Create a new Shared Folder
    # Disable Recycle Bin
    # Edit the newly created shared folder > NFS Permissions
    # Create NFS rule
    #   #Hostname or IP try with a /32 then connect via Promox to test, if it doesnt work, you may need to switch it to /24 or even /16 in order for it to work.

       Hostname or IP: 10.1.0.0/16
       Priviledge: Read/Write
       Squash: No mapping
       Security: sys
       Enable asynchronous: Yes

# Save


# Login to Proxmox UI
    # Datacenter > Storage > Add > NFS

        ID: nas-nfs
        Server: hostname or IP
        Export: Directory you just enabled from Synology should be selectable
        Content: VZDump backup file, Disk image, ISO image, Container, Container template
        NFS Version: 4


# Pre-requisite cli check Proxmox mount and take note of the nfs info:
    nano /etc/pve/storage.cfg

            nfs: nas-nfs
            export /volume1/nas-nfs
            path /mnt/pve/nas-nfs
            server nas1
            content backup,vztmpl,images,iso,rootdir
            options vers=4
            prune-backups keep-all=1
