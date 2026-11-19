# Update network configurations	

    # Check interface name
    ip a

    # Edit network interfaces
    nano /etc/network/interfaces

    # The loopback network interface
    auto lo
    iface lo inet loopback

    # The primary network interface
    allow-hotplug ens18
    iface ens18 inet dhcp


# Setup static IP

    # Comment out the dhcp and allow-hotplug lines. Append the following configuration to set up/add new static IP on Debian Linux 10/11. Here is my sample config file:
    # The loopback network interface
    auto lo
    iface lo inet loopback
    
    # The primary network interface
    # allow-hotplug ens18
    # iface ens18 inet dhcp
    auto ens18
    iface ens18  inet static
        address 10.1.30.10
        netmask 255.255.255.0
        gateway 10.1.30.254
        dns-domain domain.com
        dns-nameservers 10.1.30.254 1.1.1.1 8.8.8.8

# Restart networking services
    systemctl restart networking.service

# Check networking services
    systemctl status networking.service