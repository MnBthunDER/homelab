# Enable the PKI secrets engine at the path "pki":
vault secrets enable -path=pki pki
    Success! Enabled the pki secrets engine at: pki/

# Set the maximum lease TTL for the PKI secrets engine to 87600 hours (10 years):
vault secrets tune -max-lease-ttl=87600h pki
    Success! Tuned the secrets engine at: pki/

# Verify the configuration of the PKI secrets engine:
vault read sys/mounts/pki/tune
    Key                  Value
    ---                  -----
    default_lease_ttl    768h
    description          n/a
    force_no_cache       false
    max_lease_ttl        87600h

#generate the Root CA certificate
vault write pki/root/generate/internal \
    common_name="Company Root Certificate Authority" \
    issuer_name="Company" \
    ttl=87600h \
    key_type="ec"

# Copy the PEM file from UI and save it as ca.pem, then check the content of the certificate:
openssl x509 -in ca.pem -noout -text
openssl x509 -in ca.pem -noout -dates
    notBefore=May 29 08:10:28 2026 GMT
    notAfter=May 26 08:10:58 2036 GMT

# Follow the LinuxCloudHacks video guide to create the intermediate CA signing request and save it as pki_int.csr, then check the content of the CSR:

# Verify the certificate and intermediate chain with OpenSSL:
openssl verify -CAfile ca.pem ca_int.pem
ca_int.pem: OK

# Configure the URLs for this PKI engine
vault write pki/config/urls \
  issuing_certificates="https://vault.company.com/v1/pki/ca" \
  crl_distribution_points="https://vault.company.com/v1/pki/crl"

# Verify the configuration of the PKI secrets engine:
vault read pki/config/urls
    Key                              Value
    ---                              -----
    crl_distribution_points          [https://vault.company.com/v1/pki/crl]
    delta_crl_distribution_points    []
    enable_templating                false
    issuing_certificates             [https://vault.company.com/v1/pki/ca]
    ocsp_servers                     []

# Create the intermediate CA
vault secrets enable -path=pki_int pki
    Success! Enabled the pki secrets engine at: pki_int/

# Set its max TTL to 10 years
vault secrets tune -max-lease-ttl=87600h pki_int
    Success! Tuned the secrets engine at: pki_int/

# Now we create the Intermediate CA signing request (CSR).
vault write pki_int/intermediate/generate/internal \
    common_name="Company Intermediate Certificate Authority" \
    key_type="ec"

# Then continue follow LinuxCloudHacks video guides to extract the CSR and sign it with the Root CA.:

openssl verify -CAfile ca.pem ca_int.pem
ca_int.pem: OK


# Check the content of the CSR:
head -n 5 pki_int.csr
    -----BEGIN CERTIFICATE REQUEST-----
    MIIBV....................................
    .........................................
    .................................ZXJ0MB4X


# Sign the Intermediate CA with the Root CA
vault write -format=json pki/root/sign-intermediate \
  csr=@pki_int.csr \
  issuer_name="company-root-ca" \
  ttl="87600h" > pki_int_signed.json

# Extract the signed certificate:
jq -r '.data.certificate' pki_int_signed.json > pki_int.crt

# Now import it back into the intermediate engine:
vault write pki_int/intermediate/set-signed certificate=@pki_int.crt
    # WARNING! The following warnings were returned from Vault:

    # * This mount hasn't configured any authority information access (AIA)
    fields; this may make it harder for systems to find missing certificates
    in the chain or to validate revocation status of certificates. Consider
    updating /config/urls or the newly generated issuer with this information.

    Key                 Value
    ---                 -----
    existing_issuers    <nil>
    existing_keys       <nil>
    imported_issuers    [c00ba00e-00f0-0000-00df-00a0c0bc0000]
    imported_keys       <nil>
    mapping             map[c00ba00e-00f0-0000-00df-00a0c0bc0000:e00cd0a0-e000-0000-00bb-c0b00d0cdb00]

    What that warning means (simple)

    Vault is saying:

    “I issued/imported a CA, but I didn’t embed full chain discovery metadata (AIA).”

    This affects:

    automatic certificate chain fetching
    some strict enterprise clients
    OCSP/AIA lookup convenience
    For your use case (EAP-TLS via FreeRADIUS + UniFi):
    ❌ not critical
    ✔ can be ignored safely

# Check for the CA certificate and the issuer:
vault read pki_int/cert/ca
vault list pki_int/issuers

# Generated files sanity check and cleanup:
company-root-ca.crt # Store securely, this is the Root CA certificate
pki_int.crt  # Store securely, this is the Intermediate CA certificate
pki_int.csr  # Can be removed after signing, this is the Intermediate CA signing request
pki_int_csr.json  # Can be removed after signing, this contains the CSR response from Vault
pki_int_signed.json  # Can be removed after signing, this contains the signed certificate response from Vault

# create your first certificate role for Wi-Fi devices.
vault write pki_int/roles/wifi-device \
  allow_any_name=true \
  client_flag=true \
  server_flag=false \
  key_type=ec \
  key_bits=256 \
  max_ttl="87600h"

# Now we issue your first Wi-Fi device certificate.
vault write -format=json pki_int/issue/wifi-device \
  common_name="mnbthunder-iphone.company.com" \
  ttl="87520h"

    {
    "request_id": "remove for security",
    "lease_id": "",
    "lease_duration": 0,
    "renewable": false,
    "data": {
        "authority_key_id": "remove for security",
        "ca_chain": [
        "-----BEGIN CERTIFICATE-----\nremove for security\n-----END CERTIFICATE-----"
        ],
        "certificate": "-----BEGIN CERTIFICATE-----\nremove for security\n-----END CERTIFICATE-----",
        "expiration": 2095107480,
        "issuing_ca": "-----BEGIN CERTIFICATE-----\nremove for security\n-----END CERTIFICATE-----",
        "private_key": "-----BEGIN EC PRIVATE KEY-----\nremove for security\n-----END EC PRIVATE KEY-----",
        "private_key_type": "ec",
        "serial_number": "remove for security"
    },
    "warnings": null,
    "mount_type": "pki"
    }

jq -r '.data.certificate' output.json > mnbthunder-iphone.crt
jq -r '.data.private_key' output.json > mnbthunder-iphone.key
jq -r '.data.ca_chain[0]' output.json > company-ca.crt

# extract CA chain
jq -r '.data.ca_chain[0]' output.json > company-ca.crt

# Verify all files exist
ls -l mnbthunder-iphone.* company-ca.crt
    -rwxrwxrwx 1 root root  956 May 29 16:59 mnbthunder-iphone.crt
    -rwxrwxrwx 1 root root  227 May 29 16:59 mnbthunder-iphone.key
    -rwxrwxrwx 1 root root 1326 May 29 17:00 company-ca.crt

openssl x509 -in mnbthunder-iphone.crt -noout -subject -issuer -dates
    subject=CN=mnbthunder-iphone.company.com
    issuer=CN=Company Issuing CA
    notBefore=May 29 06:58:39 2026 GMT
    notAfter=May 22 22:59:09 2036 GMT

# Check the content of the user certificate:
ls
ca_chain.pem    client.key    client.pem

# Create a pkcs12 file for it (Compatible with Windows, Android and macOS):
openssl pkcs12 -export -out client.p12 -inkey client.key -in client.pem -certfile ca_chain.pem
    Enter Export Password:
    Verifying - Enter Export Password:
