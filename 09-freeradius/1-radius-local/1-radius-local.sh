# [Working] Purge FreeRadius to start fresh
apt purge freeradius-common freeradius-config freeradius
rm -rf /etc/freeradius

# FreeRadius Setup with eapoltest utility
lsb_release -a
apt -y install freeradius freeradius-utils eapoltest
systemctl stop freeradius
nano /etc/freeradius/3.0/users
firstname.lastname   Cleartext-Password := "password"  # For testing, you can lookup convert the encrypted ones

# Client setup
nano /etc/freeradius/3.0/clients.conf

client unifi {
    ipaddr = 10.1.30.254                        # Originally I was trying to add the IPs of AP or Controller, but freeradius -X shows it was initiating from GW instead
    secret = sharedsecret
}

# Configure using tunneld reply
nano /etc/freeradius/3.0/mods-enabled/eap       # under the peap or ttls section:

peap {
    # ... other settings ...
    use_tunneled_reply = yes
}

# UniFi Network Controller
Settings > Profile > Radius > Create New
    Name: freeradius
    [Untick] Wired Networks                     # Managed by FortiGate rather than UniFi, checking this causes my traffic routed to the AP management interface instead
    [Untick] Wireless Networks                  # Managed by FortiGate rather than UniFi, checking this causes my traffic routed to the AP management interface instead
    IP Address:     freeradius ip
    Port:           1812
    Shared Secret:  testing123
    [Untick] Accounting Servers
    Add

# Start freeradius services in debug mode
freeradius -X

# [Working]Successfully connect with local account user config now.

