# Source: https://pve.proxmox.com/wiki/Upgrade_from_8_to_9
pve8to9 --full

# FAIL: systemd-boot meta-package installed. This will cause problems on upgrades of other boot-related packages. Remove 'systemd-boot' See https://pve.proxmox.com/wiki/Upgrade_from_8_to_9#sd-boot-warning for more information.
apt remove systemd-boot
ceph osd set noout

# WARN: Removable bootloader found at '/boot/efi/EFI/BOOT/BOOTX64.efi', but GRUB packages not set up to update it!
# Run the following command:
echo 'grub-efi-amd64 grub2/force_efi_extra_removable boolean true' | debconf-set-selections -v -u

# Then reinstall GRUB with 
apt install --reinstall grub-efi-amd64

# WARN: The matching CPU microcode package 'intel-microcode' could not be found! Consider installing it to receive the latest security and bug fixes for your CPU.
# Ensure you enable the 'non-free-firmware' component in the apt sources and run:
nano /etc/apt/sources.list

deb http://deb.debian.org/debian bookworm main contrib non-free-firmware
deb http://deb.debian.org/debian-security bookworm-security main contrib non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free-firmware

apt update
apt install intel-microcode

apt dist-upgrade
pveversion
#Output OK: pve-manager/8.4.14/b502d23c55afcba1 (running kernel: 6.8.12-16-pve)

ceph --version
#Output OK: ceph version 19.2.3 (116fa4d1a2c5227d907163f1d05a062467c99f57) squid (stable)

sed -i 's/bookworm/trixie/g' /etc/apt/sources.list
sed -i 's/bookworm/trixie/g' /etc/apt/sources.list.d/pve-enterprise.list

cat > /etc/apt/sources.list.d/proxmox.sources << EOF
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF

apt update
apt policy

rm /etc/apt/sources.list.d/pve-install-repo.list
rm /etc/apt/sources.list.d/pvetest-for-beta.list

apt update
Hit:1 http://deb.debian.org/debian trixie InRelease
Hit:2 http://deb.debian.org/debian trixie-updates InRelease  
Hit:3 http://deb.debian.org/debian-security trixie-security InRelease
Hit:4 http://download.proxmox.com/debian/pve trixie InRelease
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
630 packages can be upgraded. Run 'apt list --upgradable' to see them.
root@pve2:~# apt policy
Package files:
 100 /var/lib/dpkg/status
     release a=now
 500 http://download.proxmox.com/debian/pve trixie/pve-no-subscription amd64 Packages
     release o=Proxmox,a=stable,n=trixie,l=Proxmox Debian Repository,c=pve-no-subscription,b=amd64
     origin download.proxmox.com
 500 http://deb.debian.org/debian-security trixie-security/non-free-firmware amd64 Packages
     release v=13,o=Debian,a=stable-security,n=trixie-security,l=Debian-Security,c=non-free-firmware,b=amd64
     origin deb.debian.org
 500 http://deb.debian.org/debian-security trixie-security/main amd64 Packages
     release v=13,o=Debian,a=stable-security,n=trixie-security,l=Debian-Security,c=main,b=amd64
     origin deb.debian.org
 500 http://deb.debian.org/debian trixie-updates/main amd64 Packages
     release v=13-updates,o=Debian,a=stable-updates,n=trixie-updates,l=Debian,c=main,b=amd64
     origin deb.debian.org
 500 http://deb.debian.org/debian trixie/non-free-firmware amd64 Packages
     release v=13.2,o=Debian,a=stable,n=trixie,l=Debian,c=non-free-firmware,b=amd64
     origin deb.debian.org
 500 http://deb.debian.org/debian trixie/contrib amd64 Packages
     release v=13.2,o=Debian,a=stable,n=trixie,l=Debian,c=contrib,b=amd64
     origin deb.debian.org
 500 http://deb.debian.org/debian trixie/main amd64 Packages
     release v=13.2,o=Debian,a=stable,n=trixie,l=Debian,c=main,b=amd64
     origin deb.debian.org
Pinned packages:


cat > /etc/apt/sources.list.d/ceph.sources << EOF
Types: deb
URIs: http://download.proxmox.com/debian/ceph-squid
Suites: trixie
Components: no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF

apt update
pve8to9 --full

grep -R "bookworm" /etc/apt/
/etc/apt/sources.list.d/ceph.list:deb http://download.proxmox.com/debian/ceph-squid bookworm no-subscription

sed -i 's/bookworm/trixie/' /etc/apt/sources.list.d/ceph.list
pve8to9 --full

apt dist-upgrade

nano /etc/systemd/logind.conf

    HandleLidSwitch=ignore
    LidSwitchIgnoreInhibited=no

    service systemd-logind restart

    reboot

ceph osd unset noout
pve8to9 --full