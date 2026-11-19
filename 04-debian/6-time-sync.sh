timedatectl status
timedatectl set-timezone Australia/Sydney

nano /etc/systemd/timesyncd.conf
NTP=10.1.30.254
FallbackNTP=pool.ntp.org

timedatectl set-ntp true