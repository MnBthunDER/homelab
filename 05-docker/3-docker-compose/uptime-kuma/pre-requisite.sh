# Need to setup each docker nodes to allow connectivity to port 2375 which is required for uptime-kuma
# Source: https://medium.com/@ashwinvalento/monitoring-docker-containers-on-multiple-servers-using-single-uptime-kuma-dashboard-a960d85969b7

cd /etc/docker
nano /etc/docker/daemon.json

# working - Make sure your firewall is properly locked down before setting the below up, or use static ip for better protection

{
  "hosts": ["tcp://0.0.0.0:2375", "unix:///var/run/docker.sock"]
}

cd /etc/systemd/system/docker.service.d/
mkdir docker.service.d/ # if directory does not exist
nano override.conf

[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --config-file /etc/docker/daemon.json

systemctl daemon-reload

systemctl restart docker

systemctl status docker