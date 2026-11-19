# Update the OS and Docker Application
apt update -y && apt upgrade -y

# Prior to OS upgrades
# Also called dist-upgrade in apt-get terminology.
# Upgrades all packages and can add/remove dependencies as needed to satisfy updates.
# Useful for major upgrades (like kernel updates, libraries that require removing old packages).
apt update && apt upgrade -y && apt full-upgrade -y
apt autoremove --purge -y