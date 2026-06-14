#!/bin/bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
	echo "usage: $0 <staged-cert-root>" >&2
	exit 64
fi

staged_cert_root="$1"
config_dir="$HOME/.config/op-vnc-browser"
config_path="$config_dir/launcher.env"

if [[ ! -d "$staged_cert_root/certs" ]]; then
	echo "staged cert root is missing certs/: $staged_cert_root" >&2
	exit 64
fi

mkdir -p "$config_dir"
quote_shell() {
	printf "%q" "$1"
}

certs_json="$(
	python3 - "$staged_cert_root" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
certs = []
for cert_dir in sorted(root.joinpath("certs").glob("cert-*")):
    if not cert_dir.is_dir():
        continue
    p12_path = cert_dir / "client-cert.p12"
    password_path = cert_dir / "client-cert.password"
    if not p12_path.is_file() or not password_path.is_file():
        print(f"missing staged certificate files in {cert_dir}", file=sys.stderr)
        raise SystemExit(64)
    certs.append({
        "p12_path": str(p12_path),
        "password_path": str(password_path),
    })

if not certs:
    print(f"no staged certificates found in {root}/certs", file=sys.stderr)
    raise SystemExit(64)

print(json.dumps(certs))
PY
)"

{
	printf 'OP_CERTS_MATERIALIZED=%s\n' "$(quote_shell "$certs_json")"
} > "$config_path"

chmod 600 "$config_path"
echo "Wrote $config_path"