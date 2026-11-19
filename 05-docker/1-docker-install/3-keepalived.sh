apt update && apt install -y keepalived

nano /etc/keepalived/keepalived.conf

#swm1
vrrp_instance VI_1 {
    state MASTER
    interface ens18
    virtual_router_id 51
    priority 150  # Highest priority for master node
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass your_password_here
    }
    unicast_peer {
        10.1.30.12
        10.1.30.13
    }
    virtual_ipaddress {
        10.1.30.10
    }
}

#swm2
vrrp_instance VI_1 {
    state BACKUP
    interface ens18
    virtual_router_id 51
    priority 140  # Backup 1
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass your_password_here
    }
    unicast_peer {
        10.1.30.11
        10.1.30.13
    }
    virtual_ipaddress {
        10.1.30.10
    }
}

#swm3
vrrp_instance VI_1 {
    state BACKUP
    interface ens18
    virtual_router_id 51
    priority 130  # Backup 2
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass your_password_here
    }
    unicast_peer {
        10.1.30.11
        10.1.30.12
    }
    virtual_ipaddress {
        10.1.30.10
    }
}

systemctl start keepalived
systemctl enable keepalived
