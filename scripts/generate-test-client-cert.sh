#!/bin/bash
set -euo pipefail

output_dir="${1:-test-certs}"
password="${TEST_CLIENT_CERT_PASSWORD:-op-vnc-browser-test}"
tmp_dir="$(mktemp -d)"

cleanup() {
	rm -rf "$tmp_dir"
}
trap cleanup EXIT

mkdir -p "$output_dir"

ca_key="$tmp_dir/test-ca.key.pem"
ca_cert="$output_dir/test-ca.crt.pem"
client_key="$output_dir/client.key.pem"
client_csr="$tmp_dir/client.csr.pem"
client_cert="$output_dir/client.crt.pem"
client_p12="$output_dir/client.p12"
openssl_config="$tmp_dir/client-openssl.cnf"

cat > "$openssl_config" <<'EOF'
[ req ]
distinguished_name = dn
prompt = no

[ dn ]
CN = op-vnc-browser test client
O = op-vnc-browser
OU = Test Certificate

[ client_ext ]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = clientAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
EOF

openssl genrsa -out "$ca_key" 2048 >/dev/null 2>&1
openssl req -x509 -new -nodes -key "$ca_key" -sha256 -days 3650 \
	-subj "/CN=op-vnc-browser test CA/O=op-vnc-browser/OU=Test CA" \
	-out "$ca_cert" >/dev/null 2>&1

openssl genrsa -out "$client_key" 2048 >/dev/null 2>&1
openssl req -new -key "$client_key" -config "$openssl_config" -out "$client_csr" >/dev/null 2>&1
openssl x509 -req -in "$client_csr" -CA "$ca_cert" -CAkey "$ca_key" -CAcreateserial \
	-out "$client_cert" -days 825 -sha256 -extfile "$openssl_config" -extensions client_ext >/dev/null 2>&1

openssl pkcs12 -export \
	-inkey "$client_key" \
	-in "$client_cert" \
	-certfile "$ca_cert" \
	-name "op-vnc-browser test client" \
	-out "$client_p12" \
	-passout "pass:$password" >/dev/null 2>&1

cat <<EOF
Generated test client certificate bundle:
  P12: $client_p12
  Password: $password
  CA certificate: $ca_cert
  Client certificate: $client_cert

This certificate is for import and browser launch validation only.
For a real mTLS endpoint, trust the CA certificate or replace it with one issued by your environment.
EOF