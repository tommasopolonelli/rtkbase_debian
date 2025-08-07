#!/bin/bash
set -euo pipefail

# === Paths ===
CA_GENKEY=ima-local-ca.genkey
SIGN_GENKEY=ima.genkey

# === Step 1: Create local IMA CA config ===
cat > "$CA_GENKEY" <<'EOF'
[ req ]
default_bits = 2048
distinguished_name = req_distinguished_name
prompt = no
string_mask = utf8only
x509_extensions = v3_ca

[ req_distinguished_name ]
O = IMA-CA
CN = IMA/EVM certificate signing key
emailAddress = ca@ima-ca

[ v3_ca ]
basicConstraints=CA:TRUE
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer
# keyUsage = cRLSign, keyCertSign
EOF

# === Step 2: Generate CA private key and self-signed certificate (DER) ===
openssl req -new -x509 -utf8 -sha1 -days 36500 -batch \
    -config "$CA_GENKEY" \
    -outform DER -out ima-local-ca.x509 \
    -keyout ima_local_ca.priv

# Convert to PEM for signing use
openssl x509 -inform DER -in ima-local-ca.x509 -out ima_local_ca.pem

echo "Local IMA CA created: ima_local_ca.pem (public), ima_local_ca.priv (private)"

# === Step 3: Create IMA signing key config ===
cat > "$SIGN_GENKEY" <<EOF
[ req ]
default_bits = 1024
distinguished_name = req_distinguished_name
prompt = no
string_mask = utf8only
x509_extensions = v3_usr

[ req_distinguished_name ]
O = $(hostname)
CN = $(whoami) signing key
emailAddress = $(whoami)@$(hostname)

[ v3_usr ]
basicConstraints=critical,CA:FALSE
keyUsage=digitalSignature
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid
EOF

# === Step 4: Generate IMA signing key and CSR ===
openssl req -new -nodes -utf8 -sha1 -batch \
    -config "$SIGN_GENKEY" \
    -out csr_ima.pem -keyout privkey_ima.pem

echo "IMA signing keypair generated (privkey_ima.pem + csr_ima.pem)"

# === Step 5: Sign the CSR with CA key to produce the IMA signing certificate ===
openssl x509 -req -in csr_ima.pem -days 36500 \
    -extfile "$SIGN_GENKEY" -extensions v3_usr \
    -CA ima_local_ca.pem -CAkey ima_local_ca.priv -CAcreateserial \
    -outform DER -out ima.der

echo "IMA signing cert signed by CA: ima.der"

# === Summary ===
echo
echo "🎉 DONE. Files created:"
echo "  - ima_local_ca.pem      → CA public cert (embed via CONFIG_SYSTEM_TRUSTED_KEYS)"
echo "  - ima_local_ca.priv     → CA private key (keep secure, used for signing)"
echo "  - privkey_ima.pem       → IMA signing private key (use with evmctl)"
echo "  - ima.der          → IMA signing certificate (load via CONFIG_IMA_LOAD_X509 or keyctl)"
