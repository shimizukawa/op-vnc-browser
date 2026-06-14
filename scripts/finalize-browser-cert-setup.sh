#!/bin/bash
set -euo pipefail

if [[ -z "${OP_CERTS:-}" ]]; then
	echo 'OP_CERTS is required in the environment' >&2
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
rm -rf "$state_dir"
mkdir -p "$state_dir/certs"
chmod 700 "$state_dir"
chmod 700 "$state_dir/certs"

parse_certs() {
	python3 - <<'PY'
import json
import os
import sys

raw = os.environ.get("OP_CERTS", "")
try:
    certs = json.loads(raw)
except json.JSONDecodeError as exc:
    print(f"OP_CERTS must be valid JSON: {exc}", file=sys.stderr)
    raise SystemExit(64)

if not isinstance(certs, list) or not certs:
    print("OP_CERTS must be a non-empty JSON array", file=sys.stderr)
    raise SystemExit(64)

for index, cert in enumerate(certs):
    if not isinstance(cert, dict):
        print(f"OP_CERTS[{index}] must be an object", file=sys.stderr)
        raise SystemExit(64)
    p12_ref = cert.get("p12_ref")
    password_ref = cert.get("password_ref")
    if not isinstance(p12_ref, str) or not p12_ref:
        print(f"OP_CERTS[{index}].p12_ref is required", file=sys.stderr)
        raise SystemExit(64)
    if not isinstance(password_ref, str) or not password_ref:
        print(f"OP_CERTS[{index}].password_ref is required", file=sys.stderr)
        raise SystemExit(64)
    print(f"{index}\t{p12_ref}\t{password_ref}")
PY
}

cert_specs_file="$state_dir/cert-specs.tsv"
if ! parse_certs > "$cert_specs_file"; then
	exit 64
fi

while IFS= read -r cert_spec; do
	IFS=$'\t' read -r cert_index p12_ref password_ref <<< "$cert_spec"
	cert_dir="$state_dir/certs/cert-$(printf '%04d' "$cert_index")"
	p12_path="$cert_dir/client-cert.p12"
	password_path="$cert_dir/client-cert.password"

	mkdir -p "$cert_dir"
	chmod 700 "$cert_dir"

	OP_SERVICE_ACCOUNT_TOKEN="$service_account_token" \
		op read --out-file "$p12_path" "$p12_ref"

	p12_password="$(OP_SERVICE_ACCOUNT_TOKEN="$service_account_token" op read "$password_ref")"
	printf '%s' "$p12_password" > "$password_path"
	chmod 600 "$p12_path" "$password_path"
	unset p12_password
done < "$cert_specs_file"

bash scripts/configure-browser-cert-env.sh "$state_dir"
rm -f "$cert_specs_file"

unset service_account_token

echo 'Browser certificate launcher configured.'