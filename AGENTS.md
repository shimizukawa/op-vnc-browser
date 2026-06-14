# Agent guidance for `op-vnc-browser`

## Build, test, and lint commands

- This repository is Bash-script driven (no `package.json`, Makefile, or CI test runner).
- Primary setup flow (interactive, expected during development):
  - `bash setup`
- Rebuild browser/menu launchers only:
  - `bash .devcontainer/setup-browser-menu.sh`
- Generate a single test client certificate bundle:
  - `./scripts/generate-test-client-cert.sh`
- Quick certificate import validation (single check):
  - `openssl pkcs12 -in /run/op-vnc-browser/materialized-$(id -u)/client-cert.p12 -passin file:/run/op-vnc-browser/materialized-$(id -u)/client-cert.password -info -noout`
- There is no dedicated lint command in-repo; for shell syntax-only checks use:
  - `bash -n scripts/finalize-browser-cert-setup.sh`

## High-level architecture

- `setup` is the entrypoint: it runs:
  1. `scripts/finalize-browser-cert-setup.sh`
  2. `.devcontainer/setup-browser-menu.sh`
- `scripts/finalize-browser-cert-setup.sh`:
  - requires `OP_CERTS` and `OP_BROWSER_TMP_PARENT`
  - prompts for `OP_SERVICE_ACCOUNT_TOKEN`
  - materializes every cert/password pair under `${OP_BROWSER_TMP_PARENT}/materialized-${UID}`
  - writes only staged file paths to `~/.config/op-vnc-browser/launcher.env` via `scripts/configure-browser-cert-env.sh`
- `.devcontainer/setup-browser-menu.sh`:
  - installs wrapper launchers in `~/.local/bin`
  - writes Fluxbox menu entries
  - points browser launch commands to `.devcontainer/launch-browser-with-op-cert.sh`
- `.devcontainer/launch-browser-with-op-cert.sh`:
  - loads `launcher.env` if present
  - creates ephemeral browser profile/NSS DB under `OP_BROWSER_TMP_PARENT`
  - imports every staged client cert with `certutil` + `pk12util`
  - launches Firefox/Chrome with Japanese locale defaults
- `.devcontainer/devcontainer.json` defines the required tmpfs mount at `/run/op-vnc-browser` and sets `OP_BROWSER_TMP_PARENT` accordingly.

## Key repository conventions

- Do not introduce fallback paths for browser temp state. Use `OP_BROWSER_TMP_PARENT` (expected: `/run/op-vnc-browser`) and fail clearly if missing/unwritable.
- Treat P12/PFX as binary data: use `op read --out-file ...`; do not use shell redirection from stdout for binary attachments.
- Fluxbox menu apps do not inherit ad-hoc shell exports reliably. Persist staged cert paths via `bash setup` (or `scripts/configure-browser-cert-env.sh`) so launcher env is available.
- Cert/password artifacts are intentionally ephemeral on tmpfs. After container restart/rebuild, rerun `bash setup` before debugging browser launch/import.
- Follow existing shell style:
  - `#!/bin/bash` + `set -euo pipefail`
  - explicit argument/env validation
  - exit code `64` for usage/configuration errors in these scripts
  - strict file permissions for secret material (`chmod 600` files, `700` state dirs)
