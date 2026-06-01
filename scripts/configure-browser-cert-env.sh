#!/bin/bash
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
	echo "usage: $0 <staged-p12-path> <staged-password-path>" >&2
	exit 64
fi

config_dir="$HOME/.config/op-vnc-browser"
config_path="$config_dir/launcher.env"

mkdir -p "$config_dir"
quote_shell() {
	printf "%q" "$1"
}

{
	printf 'OP_CERT_P12_PATH=%s\n' "$(quote_shell "$1")"
	printf 'OP_CERT_PASSWORD_PATH=%s\n' "$(quote_shell "$2")"
} > "$config_path"

chmod 600 "$config_path"
echo "Wrote $config_path"