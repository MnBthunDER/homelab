# Only configure this if closing your lid puts Proxmox into sleep mode
# Source: https://www.youtube.com/shorts/XF_jtcudrfM

nano /etc/systemd/logind.conf

    HandleLidSwitch=ignore
    LidSwitchIgnoreInhibited=no

    service systemd-logind restart

    reboot

# Laptop screen always off
# identify which is the built-in display
    ls /sys/class/drm/

    card0  card0-DP-1  card0-eDP-1  card0-HDMI-A-1  card0-HDMI-A-2  renderD128  version

# Your built-in display is likely card0-eDP-1 (since most modern laptops use eDP for internal screens). Let's disable it.

    nano /etc/default/grub
    GRUB_CMDLINE_LINUX_DEFAULT="quiet video=eDP-1:d"
    update-grub
    reboot
