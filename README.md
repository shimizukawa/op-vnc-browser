# op-vnc-browser
to use secure browse with op (1password) + vnc

## Setup 1password service account

1. Create service account in 1password

   - open https://<organization>.1password.com/developer-tools/infrastructure-secrets/serviceaccount
   - create new service account and copy the TOKEN.
   - save token into 1password as you wish.

2. Verify the setup manually when needed

   - start codespace
   - run `OP_SERVICE_ACCOUNT_TOKEN='<token>' op whoami` in terminal, you should see something like this:

     ```
     $ OP_SERVICE_ACCOUNT_TOKEN='<token>' op whoami
     URL:               https://<organization>.1password.com
     Integration ID:    <integration_id>
     User Type:         SERVICE_ACCOUNT
     ```

## Launch browser with client certificate in noVNC

1. Save the client certificate and password in 1Password

   - store the P12 or PFX file as a Document item
   - note the secret reference for the file, for example `op://Private/ClientCert/client.p12`
   - store the certificate password in a field and note its secret reference, for example `op://Private/ClientCert/password`

2. Run the final setup command after the Codespace starts

   ```bash
   export OP_CERT_P12_REF='op://Private/ClientCert/client.p12'
   export OP_CERT_PASSWORD_REF='op://Private/ClientCert/password'
   bash setup
   ```

   `OP_CERT_P12_REF` and `OP_CERT_PASSWORD_REF` are read from the environment. The command prompts only for the 1Password service account token with hidden input, materializes the certificate and password into `/run/op-vnc-browser`, writes only those volatile paths to `launcher.env`, and regenerates the browser launchers for the noVNC session.

3. Open the noVNC desktop and start Firefox or Chrome from the Fluxbox menu

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
