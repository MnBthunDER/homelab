# Storage permission pre-requisites
chmod 600 /mnt/nas-nfs/mosquitto/certs/*
chown 1883:1883 /mnt/nas-nfs/mosquitto/certs/*

openssl s_client -host 65q8.company.com -port 36669 -showcerts

# Initial pairing can be done via MQTT explorer 
# TV should present you with YYYY details
# Topic:
/remoteapp/tv/ui_service/XX:XX:XX:XX:XX/actions/gettvstate

#Pairing
# Topic:
/remoteapp/tv/ui_service/XX:XX:XX:XX:XX:XX$normal/actions/authenticationcode

#Payload JSON
{"authNum":"YYYY"}