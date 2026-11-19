# Machine UUID (Universally Unique Identifier)
# Ensure /var/lib/dbus/machine-id is Also Cleared
# In some cases, Debian reads the UUID from another location:
#	• Debian stores a machine's UUID in /etc/machine-id.
#	• To regenerate a new UUID:
rm -f /etc/machine-id
rm -f /var/lib/dbus/machine-id
dbus-uuidgen --ensure
systemd-machine-id-setup





# Then restart the system.
reboot

# Verify the new UUID:
cat /etc/machine-id

# Force Generating a New UUID
# Try these steps:
# Manually Generate a New UUID
# uuidgen | tee /etc/machine-id