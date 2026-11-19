# Another source to check: https://www.youtube.com/watch?v=rhvRs84rN9I&list=WL&index=8&t=53s

# LXC solutions
umount /home
e2fsck -f /dev/debian12-vg/home
resize2fs /dev/debian12-vg/home 5G
lvreduce -L 5G /dev/debian12-vg/home
resize2fs /dev/debian12-vg/home
lvextend -l +100%FREE /dev/debian12-vg/var
resize2fs /dev/debian12-vg/var

# Step-by-Step: Expand LXC Container Disk (e.g., Jellyfin)
pct shutdown 30019
pct resize 30019 rootfs +10G
pct start 30019


# VM solutions (Resize disk increment on Proxmox on the VM 1st, then resize the partition and filesystem inside the VM)
# 0. safety - backup current VM

# 1. grow sda1 into the new 1G (sda1 is last: 262144-..., free after it)
growpart /dev/sda 1
fdisk -l /dev/sda
lsblk

# 2. grow ext4 online - no umount needed
resize2fs /dev/sda1
df -hT /; lsblk -f
If growpart errors on backup GPT not on end:
apt-get update && apt-get install -y gdisk
sgdisk -e /dev/sda
partprobe /dev/sda
growpart /dev/sda 1
resize2fs /dev/sda1