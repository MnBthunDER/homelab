# https://www.youtube.com/watch?v=TY4mmgYN848

# After settinging the Enterprise Application in Azure AD, you can test the token retrieval using the following curl command. Make sure to replace the placeholders with your actual tenant ID, client ID, client secret, username, and password.
curl -X POST \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "grant_type=password" \
-d "client_id=entraid" \
-d "client_secret=entraid" \
-d "scope=https://graph.microsoft.com/.default" \
-d "username=user1@xxx.onmicrosoft.com" \
-d "password=xxx" \
"https://login.microsoftonline.com/xxx.onmicrosoft.com/oauth2/v2.0/token"

# Install FreeRADIUS and the REST module
sudo apt install freeradius freeradius-rest

# Navigate to the FreeRADIUS configuration directory and edit the REST module configuration
cd /etc/freeradius/3.0
vi mods-available/rest
:%d     # Empty the rest file

# Paste the following into the rest file
# Replace %tenantid% with your tenant ID
# Replace %clientid%  with your Client ID
# Replace %clientsecret% with your Client Secret

rest {
        connect_uri = "https://login.microsoftonline.com"

        authenticate {
            uri = "${..connect_uri}/%tenantid%/oauth2/v2.0/token"
            method = "post"
            body = post

            data = "grant_type=password&client_id=%clientid%&client_secret=%clientsecret%&scope=https://graph.microsoft.com/.default&username=%{User-Name}&password=%{User-Password}"
        }

        data_type = json
        tls {
            ca_file = /etc/ssl/certs/ca-certificates.crt
        }                 
}

:wq! # save and exit

# Debug logs from freeradius, make sure everything is working before proceed with next step
reboot now
sudo systemctl status freeradius.service
sudo journalctl -u freeradius.service -b

# link the config file to enable the module
ln -s /etc/freeradius/3.0/mods-available/rest /etc/freeradius/3.0/mods-enabled/

vi sites-enabled/default
:%d     # Empty the default file

# Paste the following into the default file

server default {
    # 1. Listen for Authentication (UDP 1812)
    listen {
        type = auth
        ipaddr = *
        port = 0
    }

    # 2. Listen for Accounting (UDP 1813)
    listen {
        type = acct
        ipaddr = *
        port = 0
    }

    # 3. The authorization Stage (Outer Tunnel Entry)
    authorize {
        preprocess

        # Route to REST ONLY if a cleartext password is found
        # This usually happens if the EAP tunnel is already established
        if (User-Password) {
            update control {
                Auth-Type := rest
            }
        }

        # Keep these to handle the initial EAP-TTLS negotiation
        files
        eap
    }

    # 4. The Authentication Stage (Inner Tunnel)
    authenticate {
        # This handles the EntraID call via the REST module
        Auth-Type rest {
            rest
        }

        # This handles the TLS handshake for the Outer Tunnel
        eap
    }

    # 5. Accounting (Log Wi-Fi session data)
    preacct {
        preprocess
        acct_unique
        files
    }

    accounting {
        detail
        -sql # The '-' means "don't fail if SQL is not configured"
        exec
    }

    # 6. Post-Authentication (Finalizing the session)
    post-auth {
        # Sync session state (Important for EAP-TTLS/PEAP)
        if (session-state:User-Name && reply:User-Name && request:User-Name && (reply:User-Name == request:User-Name)) {
            update reply {
                &User-Name !* ANY
            }
        }
        update reply{
            # &reply: += $session-state: # This did not work, below was the fix from AI
            Reply-Message := "OK"
        }

        # Cleanup EAP success/failure message
        remove_reply_message_if_eap

        # Error handling sub-section
        Post-Auth-Type REJECT {
            eap
            remove_reply_message_if_eap
        }
    }
}

:wq! # save and exit

# Debug logs from freeradius, make sure everything is working before proceed with next step
reboot now
sudo systemctl status freeradius.service
sudo journalctl -u freeradius.service -b

# Change the secret in clients.conf

vi clients.conf
:%d     # Empty the clients.conf file

client localhost {
    ipaddr = 127.0.0.1
    proto = *
    secret = testing123
    nas_type = other
    limit {
        max_connections = 16
        lifetime = 0
        idle_timeout = 900
    }
require_message_authenticator = true
}

client localhost_ipv6 {
    ipv6addr = ::1
    secret = testing123
}

client unifi {
    ipaddr = 192.168.1.0/24
    secret = SuperSecretRadiusKey
    require_message_authenticator = yes
}

:wq! # save and exit

# Debug logs from freeradius, make sure everything is working before proceed with next step
reboot now
sudo systemctl status freeradius.service
sudo journalctl -u freeradius.service -b

# Test the configuration from freeradius
radtest user1@xxx.onmicrosoft.com 'password' localhost 0 testing123
Sent Access-Request Id 237 from 0.0.0.0:51597 to 127.0.0.1:1812 length 127
        User-Name = "user1@xxx.onmicrosoft.com"
        User-Password = "password"
        NAS-IP-Address = 127.0.1.1
        NAS-Port = 0
        Message-Authenticator = 0x00
        Cleartext-Password = "password"
Received Access-Accept Id 237 from 127.0.0.1:1812 to 127.0.0.1:51597 length 42
        Message-Authenticator = 0x6dd2f4d5bfe817a5451042f1d8bb56ee
        Reply-Message = "OK"

# Debug logs from freeradius, make sure everything is working before proceed with next step
reboot now
sudo systemctl status freeradius.service
sudo journalctl -u freeradius.service -b

# Edit the eap configuration to use PEAP and MSCHAPv2 for inner authentication
vi mods-enabled/eap
:%d     # Empty the eap file

eap {
    # default_eap_type = peap
    default_eap_type = ttls
    timer_expire     = 60
    ignore_unknown_eap_types = no
    max_sessions = ${max_requests}
    tls-config tls-common {
        private_key_password = whatever
        private_key_file = ${certdir}/server.key
        certificate_file = ${certdir}/server.pem
        ca_file = ${certdir}/ca.pem
        ca_path = ${cadir}
        cipher_list = "DEFAULT"
        cipher_server_preference = no
        tls_min_version = "1.2"
        tls_max_version = "1.2"
        ecdh_curve = ""
        cache {
            enable = no
            lifetime = 24 # hours
            store {
                Tunnel-Private-Group-Id
            }
        }

        verify {
        }

        ocsp {
            enable = no
            override_cert_url = yes
            url = "http://127.0.0.1/ocsp/"
        }
    }

    tls {
        tls = tls-common
    }

ttls {
    tls = tls-common
    default_eap_type = pap
    copy_request_to_tunnel = yes
    use_tunneled_reply = yes
    virtual_server = "inner-tunnel"
}

        peap {
            tls = tls-common
            default_eap_type = mschapv2
            copy_request_to_tunnel = yes
            use_tunneled_reply = yes
            virtual_server = "inner-tunnel"
        }

        mschapv2 {
        }
}

# Debug logs from freeradius, make sure everything is working before proceed with next step
reboot now
sudo systemctl status freeradius.service
sudo journalctl -u freeradius.service -b

# The above command will fail because we have not set up the certificates yet. We will do that in the next step, but for now, let's check the logs to confirm that the error is related to the missing certificate.
May 22 05:03:11 freeradius freeradius[631]: Unable to check file "/etc/freeradius/3.0/certs/server.key": No such file or directory
May 22 05:03:11 freeradius freeradius[631]: /etc/freeradius/3.0/mods-enabled/eap[6]: Failed parsing configuration item "private_key_file"

# Edit the inner-tunnel file to use the rest module for authentication
vi sites-enabled/inner-tunnel
:%d     # Empty the inner-tunnel file

server inner-tunnel {
listen {
        ipaddr = 127.0.0.1
        port = 18120
        type = auth
}

authorize {
    filter_username
    suffix

    # If the TTLS tunnel provides a password use REST
    if (User-Password) {
        update control {
            Auth-Type := REST
        }
    }

    # Process EAP (the TTLS handshake itself)
    eap

    # Fallback modules
    files
    pap
}

authenticate {
    Auth-Type REST {
        rest
    }
        Auth-Type PAP {
                pap
        }

        Auth-Type CHAP {
                chap
        }

        Auth-Type MS-CHAP {
                mschap
        }

        mschap
        eap
}

session {
}

post-auth {
        -sql
            update reply {
                User-Name !* ANY
                Message-Authenticator !* ANY
                EAP-Message !* ANY
                Proxy-State !* ANY
                MS-MPPE-Encryption-Type !* ANY
                MS-MPPE-Encryption-Policy !* ANY
                MS-MPPE-Send-Key !* ANY
                MS-MPPE-Recv-Key !* ANY
            }
        
            update {
                    &outer.session-state: += &reply:
            }
        
        Post-Auth-Type REJECT {
            -sql
            attr_filter.access_reject

            update outer.session-state {
                    &Module-Failure-Message := &request:Module-Failure
            }
        }
}

pre-proxy {
}

post-proxy {
        eap
    }
}

# Debug logs from freeradius, make sure everything is working before proceed with next step
reboot now
sudo systemctl status freeradius.service
sudo journalctl -u freeradius.service -b

# The above command will fail because we have not set up the certificates yet. We will do that in the next step, but for now, let's check the logs to confirm that the error is related to the missing certificate.
May 22 05:03:11 freeradius freeradius[631]: Unable to check file "/etc/freeradius/3.0/certs/server.key": No such file or directory
May 22 05:03:11 freeradius freeradius[631]: /etc/freeradius/3.0/mods-enabled/eap[6]: Failed parsing configuration item "private_key_file"

# Generate the certificates using the provided Makefile
cd /etc/freeradius/3.0/certs
make
# Check if ca.pem, server.pem, and server.key are generated
ls

# Secure it
chown -R freerad:freerad /etc/freeradius/3.0/certs
chmod -R 640 /etc/freeradius/3.0/certs/*.pem

# Debug logs from freeradius, make sure everything is working and that's it!
reboot now
[  OK  ] Started freeradius.service - FreeRADIUS multi-protocol policy server.


sudo systemctl status freeradius.service
● freeradius.service - FreeRADIUS multi-protocol policy server
     Loaded: loaded (/usr/lib/systemd/system/freeradius.service; enabled; preset: enabled)
     Active: active (running) since Fri 2026-05-22 07:59:19 UTC; 17h ago
 Invocation: 1a0914c53a0c4c1e91b279889bf50e2f
       Docs: man:radiusd(8)
             man:radiusd.conf(5)
             http://wiki.freeradius.org/
             http://networkradius.com/doc/
    Process: 581 ExecStartPre=/usr/sbin/freeradius $FREERADIUS_OPTIONS -Cx -lstdout (code=exited, status=0/SUCCESS)
   Main PID: 617 (freeradius)
     Status: "Processing requests"
      Tasks: 6 (limit: 2294)
     Memory: 66.2M (max: 2G, available: 1.6G, peak: 68.4M)
        CPU: 937ms
     CGroup: /system.slice/freeradius.service
             └─617 /usr/sbin/freeradius -f

May 22 07:59:19 freeradius freeradius[581]: Compiling Auth-Type PAP for attr Auth-Type
May 22 07:59:19 freeradius freeradius[581]: Compiling Auth-Type CHAP for attr Auth-Type
May 22 07:59:19 freeradius freeradius[581]: Compiling Auth-Type MS-CHAP for attr Auth-Type
May 22 07:59:19 freeradius freeradius[581]: Ignoring "sql" (see raddb/mods-available/README.rst)
May 22 07:59:19 freeradius freeradius[581]: Compiling Post-Auth-Type REJECT for attr Post-Auth-Type
May 22 07:59:19 freeradius freeradius[581]: Compiling Auth-Type rest for attr Auth-Type
May 22 07:59:19 freeradius freeradius[581]: Compiling Post-Auth-Type REJECT for attr Post-Auth-Type
May 22 07:59:19 freeradius freeradius[581]: radiusd: #### Skipping IP addresses and Ports ####
May 22 07:59:19 freeradius freeradius[581]: Configuration appears to be OK
May 22 07:59:19 freeradius systemd[1]: Started freeradius.service - FreeRADIUS multi-protocol policy server.

sudo journalctl -u freeradius.service -b
May 22 07:59:19 freeradius systemd[1]: Starting freeradius.service - FreeRADIUS multi-protocol policy server...
May 22 07:59:19 freeradius freeradius[581]: FreeRADIUS Version 3.2.7
May 22 07:59:19 freeradius freeradius[581]: Copyright (C) 1999-2023 The FreeRADIUS server project and contributors
May 22 07:59:19 freeradius freeradius[581]: There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A
May 22 07:59:19 freeradius freeradius[581]: PARTICULAR PURPOSE
May 22 07:59:19 freeradius freeradius[581]: You may redistribute copies of FreeRADIUS under the terms of the
May 22 07:59:19 freeradius freeradius[581]: GNU General Public License
May 22 07:59:19 freeradius freeradius[581]: For more information about these matters, see the file named COPYRIGHT
May 22 07:59:19 freeradius freeradius[581]: Starting - reading configuration files ...
May 22 07:59:19 freeradius freeradius[581]: Shared secret for client localhost is short, and likely can be broken by an attacker.
May 22 07:59:19 freeradius freeradius[581]: Shared secret for client localhost_ipv6 is short, and likely can be broken by an attacker.
May 22 07:59:19 freeradius freeradius[581]: Debug state unknown (cap_sys_ptrace capability not set)
May 22 07:59:19 freeradius freeradius[581]: Configuration version: 636c-e88b-2b33-b37c
May 22 07:59:19 freeradius freeradius[581]: Creating attribute Unix-Group
May 22 07:59:19 freeradius freeradius[581]: rlm_detail (auth_log): 'User-Password' suppressed, will not appear in detail output
May 22 07:59:19 freeradius freeradius[581]: rlm_rest: libcurl version: libcurl/8.14.1 OpenSSL/3.5.6 zlib/1.3.1 brotli/1.1.0 zstd/1.5.7 libidn2/2.3.8 libpsl/0.21.2 libssh2/1.11.1 nghttp2/1.64.0 nghttp3/1.8.0 librtmp/2.3 OpenLDAP/2.6.10
May 22 07:59:19 freeradius freeradius[581]: rlm_rest (rest): Initialising connection pool
May 22 07:59:19 freeradius freeradius[581]: tls: Using cached TLS configuration from previous invocation
May 22 07:59:19 freeradius freeradius[581]: tls: Using cached TLS configuration from previous invocation
May 22 07:59:19 freeradius freeradius[581]: rlm_mschap (mschap): using internal authentication
May 22 07:59:19 freeradius freeradius[581]: Compiling Auth-Type REST for attr Auth-Type
May 22 07:59:19 freeradius freeradius[581]: Compiling Auth-Type PAP for attr Auth-Type
May 22 07:59:19 freeradius freeradius[581]: Compiling Auth-Type CHAP for attr Auth-Type
May 22 07:59:19 freeradius freeradius[581]: Compiling Auth-Type MS-CHAP for attr Auth-Type
May 22 07:59:19 freeradius freeradius[581]: Ignoring "sql" (see raddb/mods-available/README.rst)
May 22 07:59:19 freeradius freeradius[581]: Compiling Post-Auth-Type REJECT for attr Post-Auth-Type
May 22 07:59:19 freeradius freeradius[581]: Compiling Auth-Type rest for attr Auth-Type
May 22 07:59:19 freeradius freeradius[581]: Compiling Post-Auth-Type REJECT for attr Post-Auth-Type
May 22 07:59:19 freeradius freeradius[581]: radiusd: #### Skipping IP addresses and Ports ####
May 22 07:59:19 freeradius freeradius[581]: Configuration appears to be OK
May 22 07:59:19 freeradius systemd[1]: Started freeradius.service - FreeRADIUS multi-protocol policy server.