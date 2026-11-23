sudo apt update && sudo apt upgrade -y
sudo apt-get install podman slirp4netns -y
sudo apt install curl -y

curl -O https://fw-download.ubnt.com/data/unifi-os-server/f5e2-linux-x64-5.1.21-a400c9c6-8328-4634-b223-ebfcf742720a.21-x64

chmod +x ./f5e2-linux-x64-5.1.21-a400c9c6-8328-4634-b223-ebfcf742720a.21-x64
sudo ./f5e2-linux-x64-5.1.21-a400c9c6-8328-4634-b223-ebfcf742720a.21-x64

