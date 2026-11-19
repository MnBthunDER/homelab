# Best practice is to setup the clusters on fresh install!

https://www.youtube.com/watch?v=hSOFshCkSys

# Datacenter > Cluster > Create Cluster (Primary node)
# Datacenter > Cluster > Join Cluster (Remaining nodes)

# Health check post cluster created
pvecm status

# Check cluster nodes
pvecm nodes

# Leave cluster node
    pvecm delnode

# Proxmox HA and Clusters new features on 9.2
https://www.youtube.com/watch?v=tENhNnVwWyU


# Check and Fix PROXMOX Cluster HA post HAOS Install

ha-manager status

quorum OK
master pve2 (active, Fri Mar  7 15:17:24 2025)
lrm pve1 (old timestamp - dead?, Fri Mar  7 14:49:57 2025) # The HAOS Install have paused the HA on the installation host
lrm pve2 (active, Fri Mar  7 15:17:23 2025)
lrm pve3 (active, Fri Mar  7 15:17:25 2025)
service vm:10011 (pve2, started)
service vm:30011 (pve3, started)
service vm:30012 (pve2, started)
service vm:30013 (pve3, started

systemctl status pve-ha-lrm
○ pve-ha-lrm.service - PVE Local HA Resource Manager Daemon
     Loaded: loaded (/lib/systemd/system/pve-ha-lrm.service; disabled; preset: enabled)
     Active: inactive (dead)

systemctl status pve-ha-crm
○ pve-ha-crm.service - PVE Cluster HA Resource Manager Daemon
     Loaded: loaded (/lib/systemd/system/pve-ha-crm.service; disabled; preset: enabled)
     Active: inactive (dead)

# If either of these services is inactive or failed, try restarting them:
systemctl restart pve-ha-lrm
systemctl restart pve-ha-crm

# Enable Services to Start on Boot Run:
systemctl enable pve-ha-lrm
systemctl enable pve-ha-crm

ha-manager status
    quorum OK
    master pve2 (active, Fri Mar  7 15:20:54 2025)
    lrm pve1 (idle, Fri Mar  7 15:21:00 2025) # Back to normal again :)
    lrm pve2 (active, Fri Mar  7 15:20:52 2025)
    lrm pve3 (active, Fri Mar  7 15:20:54 2025)
    service vm:10011 (pve2, started)
    service vm:30011 (pve3, started)
    service vm:30012 (pve2, started)
    service vm:30013 (pve3, started)

# Monitor Logs for Any Issues
journalctl -u pve-ha-lrm -u pve-ha-crm --since "10 minutes ago"
Mar 07 15:19:24 pve1 systemd[1]: Starting pve-ha-crm.service - PVE Cluster HA Resource Manager Daemon...
Mar 07 15:19:24 pve1 pve-ha-crm[7995]: starting server
Mar 07 15:19:24 pve1 pve-ha-crm[7995]: status change startup => wait_for_quorum
Mar 07 15:19:24 pve1 systemd[1]: Started pve-ha-crm.service - PVE Cluster HA Resource Manager Daemon.
Mar 07 15:19:24 pve1 systemd[1]: Starting pve-ha-lrm.service - PVE Local HA Resource Manager Daemon...
Mar 07 15:19:24 pve1 pve-ha-lrm[7997]: starting server
Mar 07 15:19:24 pve1 pve-ha-lrm[7997]: status change startup => wait_for_agent_lock
Mar 07 15:19:24 pve1 systemd[1]: Started pve-ha-lrm.service - PVE Local HA Resource Manager Daemon.
Mar 07 15:19:28 pve1 systemd[1]: Stopping pve-ha-crm.service - PVE Cluster HA Resource Manager Daemon...
Mar 07 15:19:29 pve1 pve-ha-crm[7995]: received signal TERM
Mar 07 15:19:29 pve1 pve-ha-crm[7995]: server received shutdown request
Mar 07 15:19:29 pve1 pve-ha-crm[7995]: status change wait_for_quorum => slave
Mar 07 15:19:29 pve1 pve-ha-crm[7995]: server stopped
Mar 07 15:19:30 pve1 systemd[1]: pve-ha-crm.service: Deactivated successfully.
Mar 07 15:19:30 pve1 systemd[1]: Stopped pve-ha-crm.service - PVE Cluster HA Resource Manager Daemon.
Mar 07 15:19:30 pve1 systemd[1]: Starting pve-ha-crm.service - PVE Cluster HA Resource Manager Daemon...
Mar 07 15:19:30 pve1 pve-ha-crm[8029]: starting server
Mar 07 15:19:30 pve1 pve-ha-crm[8029]: status change startup => wait_for_quorum
Mar 07 15:19:30 pve1 systemd[1]: Started pve-ha-crm.service - PVE Cluster HA Resource Manager Daemon.
Mar 07 15:19:35 pve1 pve-ha-crm[8029]: status change wait_for_quorum => slave