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

if [[ -z "${OP_BROWSER_TMP_PARENT:-}" ]]; then
	echo 'OP_BROWSER_TMP_PARENT is required in the environment' >&2
	exit 64
fi

if [[ ! -d "${OP_BROWSER_TMP_PARENT}" || ! -w "${OP_BROWSER_TMP_PARENT}" ]]; then
	echo "OP_BROWSER_TMP_PARENT is not writable: ${OP_BROWSER_TMP_PARENT}" >&2
	exit 64
fi

read -srp '1Password service account token: ' service_account_token
echo

if [[ -z "$service_account_token" ]]; then
	echo '1Password service account token is required' >&2
	exit 64
fi

state_dir="${OP_BROWSER_TMP_PARENT}/materialized-${UID}"
password_path="$state_dir/client-cert.password"
p12_path="$state_dir/client-cert.p12"

mkdir -p "$state_dir"
chmod 700 "$state_dir"
rm -f "$p12_path" "$password_path"

OP_SERVICE_ACCOUNT_TOKEN="$service_account_token" \
	op read --out-file "$p12_path" "$OP_CERT_P12_REF"

p12_password="$(OP_SERVICE_ACCOUNT_TOKEN="$service_account_token" op read "$OP_CERT_PASSWORD_REF")"
printf '%s' "$p12_password" > "$password_path"
chmod 600 "$p12_path" "$password_path"

bash scripts/configure-browser-cert-env.sh "$p12_path" "$password_path"

unset p12_password
unset service_account_token

echo 'Browser certificate launcher configured.'