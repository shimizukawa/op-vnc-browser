#!/bin/bash
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
	echo "usage: $0 <op-cert-p12-ref> <op-cert-password-ref>" >&2
	exit 64
fi

config_dir="$HOME/.config/op-vnc-browser"
config_path="$config_dir/launcher.env"

mkdir -p "$config_dir"
cat > "$config_path" <<EOF
OP_CERT_P12_REF='$1'
OP_CERT_PASSWORD_REF='$2'
EOF

chmod 600 "$config_path"
echo "Wrote $config_path"