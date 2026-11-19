# Check SSH Configuration (PermitRootLogin)
# By default, SSH may not allow root login over SSH. Check your SSH configuration file:

    nano /etc/ssh/sshd_config
    
    #Look for the following line:
    PermitRootLogin prohibit-password
    
    #Change it to:
    PermitRootLogin yes
    
    #Save and restart SSH:
    systemctl restart ssh

    # Check SSH services
    systemctl status ssh

    # enable on boot
    systemctl enable ssh

