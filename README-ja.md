# op-vnc-browser
op (1Password) と VNC を使って安全にブラウジングするための環境です。

## クライアント証明書用の 1Password アイテムを準備する

1. 1Password で使う item 名を先に決める

   - setup 前に vault 名、item 名、password field 名を決める
   - この README で使う secret reference は `op://<vault>/<item>/<field-or-file>` 形式
   - 以下では例として次の命名を使う:
     - vault: `<vault>` 例: `Private`
     - item: `<item>` 例: `ClientCert`
     - Document item 内の P12 ファイル名: `<file>` 例: `client.p12`
     - password field 名: `<field>` 例: `password`

2. クライアント証明書と password を 1Password に保存する

   - P12 または PFX ファイルを Document item として保存する
   - ファイルの secret reference を `op://<vault>/<item>/<file>` 形式で確認する
   - 証明書 password を field に保存し、その secret reference を `op://<vault>/<item>/<field>` 形式で確認する
   - 例:
     - `op://Private/ClientCert/client.p12`
     - `op://Private/ClientCert/password`

## 1Password の service account を準備する

1. 1Password で service account を作成する

   - https://<organization>.1password.com/developer-tools/infrastructure-secrets/serviceaccount を開く
   - 新しい service account を作成して TOKEN をコピーする
   - TOKEN は必要に応じて安全な場所へ保存する

## noVNC でクライアント証明書付きブラウザを起動する

1. Codespace を起動して最終セットアップを実行する

   - Codespace を起動する
   - `OP_CERTS` を設定したうえで `bash setup` を実行する
   - プロンプトが表示されたら service account token を入力する
   - setup が成功すれば、その token で必要な 1Password アイテムにアクセスし、クライアント証明書がセットアップされる

   ```bash
   $ export OP_CERTS='[
     {"p12_ref":"op://<vault>/<item1>/<file>","password_ref":"op://<vault>/<item1>/<field>"},
     {"p12_ref":"op://<vault>/<item2>/<file>","password_ref":"op://<vault>/<item2>/<field>"}
   ]'
   $ bash setup
   1Password service account token:
   Browser certificate launcher configured.
   ```

   `OP_CERTS` は JSON として環境変数から読み取られます。各要素には `p12_ref` と `password_ref` が必要です。このコマンドは 1Password の service account token だけを hidden input で受け取り、各証明書ペアを `/run/op-vnc-browser` に実体化し、`OP_CERTS_MATERIALIZED` として揮発パスを `launcher.env` に書き出したうえで、noVNC 用ブラウザランチャーを再生成します。

2. noVNC デスクトップから Firefox または Chrome を起動する

`bash setup` 実行後、launcher は `/run/op-vnc-browser` 上に実体化された証明書と password を読み取り、一時 NSS データベースを作って揮発プロファイルでブラウザを起動します。ブラウザ終了時には一時プロファイルは削除されます。実体化された証明書ファイルも tmpfs 上にあるため、コンテナ停止時に消えます。

この devcontainer は `/run/op-vnc-browser` に専用の tmpfs を mount しており、launcher はブラウザ用の揮発データを必ずそこに置きます。`/tmp` や `/dev/shm` には fallback しません。[.devcontainer/devcontainer.json](.devcontainer/devcontainer.json) を変更した場合は、テスト前に Codespace またはコンテナを rebuild / recreate してください。

## テスト用クライアント証明書を作成して 1Password に保存する

1. Codespace でテスト用 P12 bundle を生成する

   ```bash
   chmod +x scripts/generate-test-client-cert.sh
   ./scripts/generate-test-client-cert.sh
   ```

   これにより、デフォルト password `op-vnc-browser-test` 付きの `test-certs/client.p12` が作成されます。

2. bundle を 1Password に保存する

   - 1Password で新しい Document item を作成し、たとえば `ClientCert` のような名前を付ける
   - `test-certs/client.p12` をアップロードする
   - たとえば `password` という名前の text field を追加し、値に `op-vnc-browser-test` を設定する
   - `op://<vault>/<item>/<field-or-file>` 形式の secret reference を 2 つ確認する。例:
     - `op://Private/ClientCert/client.p12`
     - `op://Private/ClientCert/password`

3. 保存した secret reference を launcher に設定する

   ```bash
   export OP_CERTS='[
     {"p12_ref":"op://<vault>/<item>/<file>","password_ref":"op://<vault>/<item>/<field>"}
   ]'
   bash setup
   ```

4. noVNC を開く前に CLI で import を確認したい場合

   ```bash
   workdir=/run/op-vnc-browser/manual-check
   mkdir -p "$workdir"
   cp /run/op-vnc-browser/materialized-$(id -u)/client-cert.p12 "$workdir/client.p12"
   openssl pkcs12 -in "$workdir/client.p12" -passin file:/run/op-vnc-browser/materialized-$(id -u)/client-cert.password -info -noout
   rm -rf "$workdir"
   ```

このテスト証明書には `extendedKeyUsage = clientAuth` が入っているため、ブラウザへの import 経路を検証する用途には使えます。ただし、接続先が生成した test CA を信頼していない限り、実サービスの認証には使えません。

`openssl pkcs12` が shell のリダイレクト利用後に ASN.1 エラーを返す場合は、stdout 経由でバイナリを書いたためにファイルが壊れている可能性があります。P12 のようなバイナリ添付は `op read --out-file ...` を使ってください。

noVNC メニューから起動した Firefox が証明書を見つけられないのに、Chrome やターミナルでは見える場合、原因は Fluxbox があとから export した環境変数を引き継がないことです。`bash setup` または `scripts/configure-browser-cert-env.sh` で参照情報を永続化して、メニュー起動ブラウザが読めるようにしてください。

rebuild やコンテナ再起動のあとにブラウザが起動しなくなった場合は、`bash setup` を再実行して `/run/op-vnc-browser` に証明書を実体化し直してください。