# op-vnc-browser
to use secure browse with op (1password) + vnc

## Prepare the 1Password items for the client certificate

1. Prepare the 1Password item names you will use

   - choose a vault name, item name, and password field name before setup
   - secret references used in this README follow the form `op://<vault>/<item>/<field-or-file>`
   - example naming used below:
     - vault: `<vault>` such as `Private`
     - item: `<item>` such as `ClientCert`
     - P12 file name inside the Document item: `<file>` such as `client.p12`
     - password field name: `<field>` such as `password`

2. Save the client certificate and password in 1Password

   - store the P12 or PFX file as a Document item
   - note the secret reference for the file as `op://<vault>/<item>/<file>`
   - store the certificate password in a field and note its secret reference as `op://<vault>/<item>/<field>`
   - example:
     - `op://Private/ClientCert/client.p12`
     - `op://Private/ClientCert/password`

## Setup 1password service account

1. Create service account in 1password

   - open https://<organization>.1password.com/developer-tools/infrastructure-secrets/serviceaccount
   - create new service account and copy the TOKEN.
   - save token into 1password as you wish.

## Launch browser with client certificate in noVNC

1. Start the Codespace and run the final setup command

   - start codespace
   - run `bash setup` after setting `OP_CERTS`
   - enter the service account token when prompted
   - if setup succeeds, the token can access the required 1Password items and set up the client certificates

   ```bash
   $ export OP_CERTS='[
     {"p12_ref":"op://<vault>/<item1>/<file>","password_ref":"op://<vault>/<item1>/<field>"},
     {"p12_ref":"op://<vault>/<item2>/<file>","password_ref":"op://<vault>/<item2>/<field>"}
   ]'
   $ bash setup
   1Password service account token:
   Browser certificate launcher configured.
   ```

   `OP_CERTS` is read from the environment as JSON. Each entry must provide `p12_ref` and `password_ref`. The command prompts only for the 1Password service account token with hidden input, materializes each certificate pair into `/run/op-vnc-browser`, writes the staged paths as `OP_CERTS_MATERIALIZED` in `launcher.env`, and regenerates the browser launchers for the noVNC session.

2. Open the noVNC desktop and start Firefox or Chrome from the Fluxbox menu

After `bash setup`, the launcher reads the materialized certificate and password from `/run/op-vnc-browser`, creates a temporary NSS database, and starts the browser with an ephemeral profile. When the browser exits, the temporary profile is removed automatically. The staged certificate files also disappear when the container stops because they live on tmpfs.

This devcontainer mounts a dedicated tmpfs at `/run/op-vnc-browser` and the launcher requires that path for ephemeral browser state. It does not fall back to `/tmp` or `/dev/shm`. After changing [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json), rebuild or recreate the Codespace/container so the mount exists before testing.

## Create a test client certificate and store it in 1Password

1. Generate a test P12 bundle in the Codespace

   ```bash
   chmod +x scripts/generate-test-client-cert.sh
   ./scripts/generate-test-client-cert.sh
   ```

   This creates `test-certs/client.p12` with the default password `op-vnc-browser-test`.

2. Save the bundle in 1Password

   - open 1Password and create a new Document item named as you like, for example `ClientCert`
   - upload `test-certs/client.p12`
   - add a text field named as you like, for example `password`, with value `op-vnc-browser-test`
   - note the two secret references in the form `op://<vault>/<item>/<field-or-file>`, for example:
     - `op://Private/ClientCert/client.p12`
     - `op://Private/ClientCert/password`

3. Point the launcher at the stored secrets

   ```bash
   export OP_CERTS='[
     {"p12_ref":"op://<vault>/<item>/<file>","password_ref":"op://<vault>/<item>/<field>"}
   ]'
   bash setup
   ```

4. Validate import before opening noVNC if you want a quick CLI check

   ```bash
   workdir=/run/op-vnc-browser/manual-check
   mkdir -p "$workdir"
   cp /run/op-vnc-browser/materialized-$(id -u)/client-cert.p12 "$workdir/client.p12"
   openssl pkcs12 -in "$workdir/client.p12" -passin file:/run/op-vnc-browser/materialized-$(id -u)/client-cert.password -info -noout
   rm -rf "$workdir"
   ```

This test certificate has `extendedKeyUsage = clientAuth`, so it is suitable for validating the browser import path. It is not trusted by real services unless they trust the generated test CA.

If `openssl pkcs12` reports ASN.1 errors after using shell redirection, the file was likely corrupted while writing binary data through stdout. Use `op read --out-file ...` for P12 and other binary attachments.

If Firefox launched from the noVNC menu does not see the certificate while Chrome or terminal commands do, the usual cause is that Fluxbox does not inherit environment variables exported later in a shell. Persist the references with `bash setup` or `scripts/configure-browser-cert-env.sh` so menu-launched browsers can read them.

If the browser does not start at all after a rebuild or container restart, rerun `bash setup` so the certificate is materialized again in `/run/op-vnc-browser`.
