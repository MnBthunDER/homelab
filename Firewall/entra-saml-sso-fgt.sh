# https://docs.fortinet.com/document/fortigate/7.6.3/administration-guide/33053/outbound-firewall-authentication-with-microsoft-entra-id-as-a-saml-idp

# https://docs.fortinet.com/document/fortigate/6.2.0/new-features/150646/configuring-single-sign-on-in-the-security-fabric

# Configuring single-sign-on in the Security Fabric 6.2.2
# https://www.youtube.com/watch?v=1ZsegrBG2HY

# On FortiOS 6.2 go to Dashboard > Settings > Enable FortiGate Telemetry
# Select Advanced Options under IdP certificate to reveal the hidden SAML SSO
# Service Provider is where the configurations resides

# 7.4.x
# https://www.youtube.com/watch?v=2oVkHLcJpuM (Spanish)
# https://www.youtube.com/watch?v=ByF3Ttni8Os (English)
# https://community.fortinet.com/t5/FortiGate/Troubleshooting-Tip-SAML-Authentication-fails-after-firmware/ta-p/407859

# Config System Global SAML Port
config system global
   set auth-ike-saml-port 1001
end

# Enable ike saml on WAN interface
config system interface
    edit "wan2"
        set ike-saml-server "sso-ipsec"
    next
end

# Enable EAP on Phase1
config vpn ipsec phase1-interface
    edit "ipsec-mgmt"
        set type dynamic
        set interface "wan2"
        set ike-version 2
        set peertype any
        set net-device disable
        set mode-cfg enable
        set ipv4-dns-server1 10.1.20.254
        set proposal aes128-sha256 aes256-sha256
        set dpd on-idle
        set dhgrp 14
        set eap enable
        set eap-identity send-request
        set authusrgrp "ipsec-entra-group"
        set assign-ip-from name
        set ipv4-split-include "ipsec-mgmt_split"
        set ipv4-name "ipsec-mgmt_range"
        set psksecret ENC *****************************
        set dpd-retryinterval 60
    next
end

fw1 (ipsec-entra) # end

fw1 # config vpn ipsec phase2-interface 

fw1 (phase2-interface) # show
config vpn ipsec phase2-interface
    edit "ipsec-mgmt"
        set phase1name "ipsec-mgmt"
        set proposal aes128-sha1 aes256-sha256
        set dhgrp 14
        set keepalive enable
    next
end

# Time sync
# https://community.fortinet.com/t5/FortiGate/Technical-Tip-Authentication-fails-with-clock-skew-errors-in/ta-p/222360

config system ntp
    set ntpsync enable
    set type custom
    config ntpserver
        edit 1
            set server "pool.ntp.org"
        next
    end
    set server-mode enable

# Rename Remote Certificate
config vpn certificate remote
    rename "REMOTE_Cert_1" to "ipsec-entra"
end

# Debug
diagnose debug application saml -1
diagnose debug enable

__samld_sp_Login_resp [847]: Clock skew tolerance: 15 
__samld_sp_login_resp [852]: Clock skew issue. 
samld_send_common_reply [91]: Code: 5, id: 563785, pid: 294, len: 53, data_len: 37 
samld_send_common_reply [99]: Attr: 22,12, 
samld_send_common_reply [99]: Attr: 23, 25, Undefined error. 
samld_send_common_reply [119]: Sent resp: 53, pid=294, job_id=563785