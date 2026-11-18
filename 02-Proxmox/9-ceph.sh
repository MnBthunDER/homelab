# Setup ceph on Proxmox video: https://www.youtube.com/watch?v=-qk_P9SKYK4
# Setup microceph on docker swarm: https://www.youtube.com/watch?v=nmas_zbcMeU
# Upgrade ceph squid to tentacle: https://pve.proxmox.com/wiki/Ceph_Squid_to_Tentacle

# Setup ceph on Proxmox
# Ensure each node has 1 additional drive being internal or external and do not need to be identical size

# 1. install ceph on each pve (default settings)
# 2. Ceph > OSD > Add the new disk
# 3. Ceph > Pools > Create new pool (default settings)

# Setup microceph on docker swarm

# Pending..

# Remove ceph
systemctl stop ceph-mon.target
systemctl stop ceph-mgr.target
systemctl stop ceph-mds.target
systemctl stop ceph-osd.target
rm -rf /etc/systemd/system/ceph*
killall -9 ceph-mon ceph-mgr ceph-mds
rm -rf /var/lib/ceph/mon/ /var/lib/ceph/mgr/ /var/lib/ceph/mds/
pveceph purge

ceph osd lspools

ceph osd pool delete .mgr .mgr --yes-i-really-really-mean-it

apt purge ceph-mon ceph-osd ceph-mgr ceph-mds
apt purge ceph-base ceph-mgr-modules-core
rm -rf /etc/ceph/*
rm -rf /etc/pve/ceph.conf
rm -rf /etc/pve/priv/ceph.*
