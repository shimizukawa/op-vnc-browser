#!/bin/bash
set -euo pipefail

if [[ -z "${OP_CERT_P12_REF:-}" ]]; then
	echo 'OP_CERT_P12_REF is required in the environment' >&2
	exit 64
fi

if [[ -z "${OP_CERT_PASSWORD_REF:-}" ]]; then
	echo 'OP_CERT_PASSWORD_REF is required in the environment' >&2
	exit 64
fi

read -srp '1Password service account token: ' service_account_token
echo

if [[ -z "$service_account_token" ]]; then
	echo '1Password service account token is required' >&2
	exit 64
fi

OP_SERVICE_ACCOUNT_TOKEN="$service_account_token" \
	bash scripts/configure-browser-cert-env.sh "$OP_CERT_P12_REF" "$OP_CERT_PASSWORD_REF"

unset service_account_token

echo 'Browser certificate launcher configured.'