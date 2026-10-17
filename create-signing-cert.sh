#!/bin/zsh
# Creates a self-signed "SpaceNames Local Signing" code-signing identity in the login keychain.
# build.sh signs with it so the Accessibility approval survives rebuilds.
# macOS asks for your login password once to trust the certificate for code signing.
set -euo pipefail
IDENTITY="SpaceNames Local Signing"
KEYCHAIN=~/Library/Keychains/login.keychain-db

if security find-identity -v -p codesigning | grep -q "\"$IDENTITY\""; then
  echo "'$IDENTITY' already exists."
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
umask 077

cat > "$TMP/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $IDENTITY
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
EOF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$TMP/cert.cnf" \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
PASS=$(openssl rand -hex 16)
# -legacy is needed with OpenSSL 3 so macOS can read the .p12; LibreSSL doesn't know the flag.
LEGACY=()
openssl version | grep -q '^OpenSSL 3' && LEGACY=(-legacy)
openssl pkcs12 -export "${LEGACY[@]}" -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -name "$IDENTITY" -out "$TMP/cert.p12" -passout "pass:$PASS"

security import "$TMP/cert.p12" -k "$KEYCHAIN" -P "$PASS" -T /usr/bin/codesign
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem"
security find-identity -v -p codesigning | grep "\"$IDENTITY\""
