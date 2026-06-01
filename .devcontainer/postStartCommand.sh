#!/bin/bash
set -euo pipefail

# cd /workspaces/op-vnc-browser

bash .devcontainer/setup-browser-menu.sh

if [[ -n "${OP_CERT_P12_REF:-}" && -n "${OP_CERT_PASSWORD_REF:-}" ]]; then
	bash scripts/configure-browser-cert-env.sh "$OP_CERT_P12_REF" "$OP_CERT_PASSWORD_REF"
fi