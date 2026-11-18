# Video guide: https://www.youtube.com/watch?v=qWvcm5NzuCI

# Install InfluxDB on Ubuntu
apt update -y && apt upgrade -y
curl -LO https://download.influxdata.com/influxdb/releases/influxdb2_2.7.6-1_amd64.deb
dpkg -i influxdb2_2.7.6-1_amd64.deb
service influxdb start
service influxdb status

# Install Grafana on Ubuntu
apt update -y && apt upgrade -y
apt install -y apt-transport-https software-properties-common wget
mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | tee -a /etc/apt/sources.list.d/grafana.list
apt update
apt install grafana
grafana-server -v
systemctl start grafana-server
systemctl enable grafana-server

