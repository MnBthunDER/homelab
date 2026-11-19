# Follow 1-radius-local.sh local setup guide first before switching to OAuth2
# Secure Your WiFi with RADIUS: A Step-by-Step Guide (FreeRADIUS & Azure AD)
https://www.youtube.com/watch?v=80C8dxnPZGM

#GitHub
https://github.com/filip-lebiecki/wifi-radius/


# OAuth2 FreeRadius
vi /etc/freeradius/3.0/users
# comment out local users if found any

apt -y install ca-certificates curl libjson-pp-perl libwww-perl
cd /opt
git clone https://github.com/jimdigriz/freeradius-oauth2-perl.git

vi /etc/freeradius/3.0/proxy.conf
realm XXX.onmicrosoft.com {
    oauth2 {
        discovery = "https://login.microsoftonline.com/%{Realm}/v2.0"
        client_id = "CLIENT_ID_GOES_HERE"
        client_secret = "CLIENT_SECRET_GOES_HERE"
        cache_password = yes
    }
}

printf '\n$INCLUDE /opt/freeradius-oauth2-perl/dictionary\n' >> /etc/freeradius/3.0/dictionary
ln -s /opt/freeradius-oauth2-perl/module /etc/freeradius/3.0/mods-enabled/oauth2
ln -s /opt/freeradius-oauth2-perl/policy /etc/freeradius/3.0/policy.d/oauth2

vi /etc/freeradius/3.0/sites-enabled/default
# authorize section add oauth2 after ldap
# end of the authenticate
Auth-Type oauth2 {
        oauth2
}
# post-auth section add oauth2 after ldap

vi /etc/freeradius/3.0/sites-enabled/inner-tunnel
# authorize section add oauth2 after ldap
# end of the authenticate
Auth-Type oauth2 {
        oauth2
}
# post-auth section add oauth2 after ldap

freeradius -X

# Testing FreeRadius with eapoltest utility
radtest user@XXX.onmicrosoft.com password 127.0.0.1 0 testing123
cp eapol_test.conf eapol_test2.conf

vi eapol_test.conf
network={
        key_mgmt=WPA-EAP
        eap=TTLS
        identity="filip@XXX.onmicrosoft.com"
        password="USER_PASS_GOES_HERE"
        phase2="auth=PAP"
}

eapol_test -c eapol_test.conf -a 127.0.0.1 -p 1812 -s testing123

vi /opt/freeradius-oauth2-perl/module

[Reviewing-how-to-obtain-valid-certificate-successfully]

# Locate the Self-signed Snake Oil Certificate and check the content for expiry date - usually 10 years from creation
openssl x509 -in /etc/ssl/certs/ssl-cert-snakeoil.pem --text --noout

# Download it to your Windows machine
/etc/ssl/private/ssl-cert-snakeoil.key
# On Windows, rename the file to crt and install on Trusted Root Certification Authorities
ssl-cert-snakeoil.crt

# Make the bootstrap script executable
# cd /etc/freeradius/3.0/certs
# chmod +x bootstrap

# Run the bootstrap script
# ./bootstrap

# Import ssl-cert-snakeoil.crt to your Windows machine and import it:
Open mmc.exe

Add Certificates snap-in → Computer account → Local computer

Navigate to Trusted Root Certification Authorities → Certificates

Right-click → All Tasks → Import

Select ssl-cert-snakeoil.crt → Finish