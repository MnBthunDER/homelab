https://www.youtube.com/watch?v=bI2G2CTW144

# Create using ipsec vpn remote access wizard, then switch to custom 
    # enable peerid for additional security / multi dialup tunnel support
    # minimum DH Group requirement set to 14

# Phase1
fw1 # config vpn ipsec phase1-interface

fw1 (phase1-interface) # show
config vpn ipsec phase1-interface
    edit "ipsec-ra-mgmt"
        set type dynamic
        set interface "wan2"
        set mode aggressive
        set peertype one
        set net-device disable
        set mode-cfg enable
        set ipv4-dns-server1 1.1.1.1
        set proposal aes128-sha256 aes256-sha256 aes128-sha1 aes256-sha1
        set dhgrp 14
        set xauthtype auto
        set authusrgrp "mgmt"
        set peerid "management"
        set ipv4-start-ip 10.212.134.100
        set ipv4-end-ip 10.212.134.110
        set ipv4-split-include "ipsec-ra-mgmt_split"
        set domain "domain.local"
        set psksecret ENC *****************************
    next
end       
 
# Phase2
fw1 (phase2-interface) # show
config vpn ipsec phase2-interface
    edit "ipsec-ra-mgmt"
        set phase1name "ipsec-ra-mgmt"
        set proposal aes128-sha1 aes256-sha1 aes128-sha256 aes256-sha256 aes128gcm aes256gcm chacha20poly1305
        set dhgrp 14
    next
end

# review firewall policy to allow traffic as required