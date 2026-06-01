# op-vnc-browser
to use secure browse with op (1password) + vnc

## Setup 1password service account

1. Create service account in 1password

   - open https://<organization>.1password.com/developer-tools/infrastructure-secrets/serviceaccount
   - create new service account and copy the TOKEN.
   - save token into 1password as you wish.

2. Store TOKEN in GitHub Codespaces secrets

   - open https://github.com/<org>/<repo>/settings/secrets/codespaces
   - click New repository secret
   - add OP_SERVICE_ACCOUNT_TOKEN as the name and paste the TOKEN as the value

3. Verify the setup

   - start codespace
   - type `op whoami` in terminal, you should see something like this:

     ```
     $ op whoami
     URL:               https://<organization>.1password.com
     Integration ID:    <integration_id>
     User Type:         SERVICE_ACCOUNT
     ```

## Launch browser with client certificate in noVNC

1. Save the client certificate and password in 1Password

   - store the P12 or PFX file as a Document item
   - note the secret reference for the file, for example `op://Private/ClientCert/client.p12`
   - store the certificate password in a field and note its secret reference, for example `op://Private/ClientCert/password`

2. Export the references inside the Codespace

   ```bash
   export OP_CERT_P12_REF='op://Private/ClientCert/client.p12'
   export OP_CERT_PASSWORD_REF='op://Private/ClientCert/password'
   export OP_SERVICE_ACCOUNT_TOKEN='your-service-account-token'
   ```

   If you launch the browser from the noVNC Fluxbox menu, also persist the references for the desktop session:

   ```bash
   chmod +x scripts/configure-browser-cert-env.sh
   ./scripts/configure-browser-cert-env.sh \
     'op://Private/ClientCert/client.p12' \
     'op://Private/ClientCert/password'
   ```

    `OP_SERVICE_ACCOUNT_TOKEN` is copied into the launcher config automatically when it is present in the shell.

3. Reinstall the browser launchers once

   ```bash
   bash .devcontainer/setup-browser-menu.sh
   ```

4. Open the noVNC desktop and start Firefox or Chrome from the Fluxbox menu

When `OP_CERT_P12_REF` and `OP_CERT_PASSWORD_REF` are set, the launcher creates a temporary NSS database, imports the certificate with `op read`, and starts the browser with an ephemeral profile. When the browser exits, the temporary profile and imported certificate are removed automatically.

This devcontainer mounts a dedicated tmpfs at `/run/op-vnc-browser` and the launcher requires that path for ephemeral browser state. It does not fall back to `/tmp` or `/dev/shm`. After changing [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json), rebuild or recreate the Codespace/container so the mount exists before testing.

## Create a test client certificate and store it in 1Password

1. Generate a test P12 bundle in the Codespace

   ```bash
   chmod +x scripts/generate-test-client-cert.sh
   ./scripts/generate-test-client-cert.sh
   ```

   This creates `test-certs/client.p12` with the default password `op-vnc-browser-test`.

2. Save the bundle in 1Password

   - open 1Password and create a new Document item named `ClientCert`
   - upload `test-certs/client.p12`
   - add a text field named `password` with value `op-vnc-browser-test`
   - note the two secret references, for example:
     - `op://Private/ClientCert/client.p12`
     - `op://Private/ClientCert/password`

3. Point the launcher at the stored secrets

   ```bash
   export OP_CERT_P12_REF='op://Private/ClientCert/client.p12'
   export OP_CERT_PASSWORD_REF='op://Private/ClientCert/password'
    export OP_SERVICE_ACCOUNT_TOKEN='your-service-account-token'
   ./scripts/configure-browser-cert-env.sh \
     "$OP_CERT_P12_REF" \
     "$OP_CERT_PASSWORD_REF"
   bash .devcontainer/setup-browser-menu.sh
   ```

4. Validate import before opening noVNC if you want a quick CLI check

   ```bash
   workdir=/run/op-vnc-browser/manual-check
   mkdir -p "$workdir"
   op read --out-file "$workdir/client.p12" "$OP_CERT_P12_REF"
   openssl pkcs12 -in "$workdir/client.p12" -passin 'pass:op-vnc-browser-test' -info -noout
   rm -rf "$workdir"
   ```

This test certificate has `extendedKeyUsage = clientAuth`, so it is suitable for validating the browser import path. It is not trusted by real services unless they trust the generated test CA.

If `openssl pkcs12` reports ASN.1 errors after using shell redirection, the file was likely corrupted while writing binary data through stdout. Use `op read --out-file ...` for P12 and other binary attachments.

If Firefox launched from the noVNC menu does not see the certificate while Chrome or terminal commands do, the usual cause is that Fluxbox does not inherit environment variables exported later in a shell. Persist the references with `scripts/configure-browser-cert-env.sh` so menu-launched browsers can read them.

If the browser does not start at all and `~/.xsession-errors` shows `No accounts configured for use with 1Password CLI`, the noVNC session is missing `OP_SERVICE_ACCOUNT_TOKEN`. Export it in the shell before running `scripts/configure-browser-cert-env.sh` so the launcher can authenticate.
