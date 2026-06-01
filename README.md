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
