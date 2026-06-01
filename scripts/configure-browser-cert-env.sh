#!/bin/bash
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
	echo "usage: $0 <op-cert-p12-ref> <op-cert-password-ref>" >&2
	exit 64
fi

config_dir="$HOME/.config/op-vnc-browser"
config_path="$config_dir/launcher.env"

mkdir -p "$config_dir"
quote_shell() {
	printf "%q" "$1"
}

{
	printf 'OP_CERT_P12_REF=%s\n' "$(quote_shell "$1")"
	printf 'OP_CERT_PASSWORD_REF=%s\n' "$(quote_shell "$2")"
	if [[ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
		printf 'OP_SERVICE_ACCOUNT_TOKEN=%s\n' "$(quote_shell "$OP_SERVICE_ACCOUNT_TOKEN")"
	fi
	if [[ -n "${OP_CONNECT_HOST:-}" ]]; then
		printf 'OP_CONNECT_HOST=%s\n' "$(quote_shell "$OP_CONNECT_HOST")"
	fi
	if [[ -n "${OP_CONNECT_TOKEN:-}" ]]; then
		printf 'OP_CONNECT_TOKEN=%s\n' "$(quote_shell "$OP_CONNECT_TOKEN")"
	fi
} > "$config_path"

chmod 600 "$config_path"
echo "Wrote $config_path"