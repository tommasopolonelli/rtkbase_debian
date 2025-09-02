#!/bin/sh

# sign_user_binaries.sh — Signs all executables owned by UID 1000 for IMA appraisal

set -e

KEY_PATH="/etc/keys/ima_privkey.pem"
CERT_PATH="/etc/keys/ima_x509.der"
TARGET_UID=1000

echo "[*] Starting IMA signing of user-owned executables (UID=$TARGET_UID)..."

# Check prerequisites
if ! command -v evmctl >/dev/null 2>&1; then
    echo "[!] evmctl is not installed. Aborting."
    exit 1
fi

if [ ! -f "$KEY_PATH" ] || [ ! -f "$CERT_PATH" ]; then
    echo "[!] IMA key or cert not found at $KEY_PATH or $CERT_PATH. Aborting."
    exit 1
fi

# Find and sign executables owned by UID 1000
find / -xdev -type f -uid "$TARGET_UID" -perm /111 2>/dev/null | while read -r file; do
    # Only sign ELF binaries
    if file "$file" | grep -q "ELF"; then
        echo "[+] Signing: $file"
        evmctl ima_sign --key "$KEY_PATH" --cert "$CERT_PATH" "$file" || {
            echo "[!] Failed to sign: $file"
        }
    fi
done

echo "[*] Finished signing user-owned executables."
