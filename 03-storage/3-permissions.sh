# Grant permission from file server

chown -R 1000:1000 /mnt/nas-nfs/unifi/unifi-db
chmod -R 775 /mnt/nas-nfs/unifi/unifi-db

chown -R 1000:1000 /mnt/nas-nfs/arr
chmod -R 775 /mnt/nas-nfs/arr

chown -R 1000:1000 /mnt/nas-nfs/authentik/custom-templates
chmod -R 755 /mnt/nas-nfs/authentik/custom-templates

chown -R 1000:1000 /mnt/nas-nfs/paperlessngx
chmod -R 775 /mnt/nas-nfs/paperlessngx
chown -R 1000:1000 /mnt/nas-nfs/paperlessngx/data
chown -R 1000:1000 /mnt/nas-nfs/paperlessngx/media
chown -R 1000:1000 /mnt/nas-nfs/paperlessngx/export
chown -R 1000:1000 /mnt/nas-nfs/paperlessngx/consume

