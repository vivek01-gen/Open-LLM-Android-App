# Android Release Signing — Open LLM

This guide explains how to generate a release keystore and configure GitHub
repository secrets so the CI workflow can sign the release APK.

## Why signing matters

The release APK must be signed with a valid keystore (v2/v3 signature scheme)
otherwise real Android devices reject it with "App not installed" on fresh
install. The CI workflow (`flutter build apk --release`) previously had no
release signing config, so the APK was either unsigned or signed with the debug
key — both of which fail installation on many devices.

## Step 1: Generate the release keystore

Run this on any machine with the Android SDK build-tools installed:

```bash
keytool -genkey -v -keystore release-keystore.jks \
  -alias openllm-release \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

You will be prompted for:
- **Keystore password** → note this as `KEYSTORE_PASSWORD`
- **Key alias** → note this as `KEY_ALIAS` (default above: `openllm-release`)
- **Key password** → note this as `KEY_PASSWORD` (can be same as keystore password)

The output file `release-keystore.jks` is your signing keystore.

## Step 2: Encode the keystore as base64

```bash
base64 -w 0 release-keystore.jks > keystore.base64
cat keystore.base64
```

Copy the entire base64 string — this is `KEYSTORE_BASE64`.

## Step 3: Add GitHub repository secrets

In your GitHub repository, go to **Settings → Secrets and variables → Actions**,
and add the following repository secrets (the user adds these — do not commit
them):

| Secret name | Value |
|---|---|
| `KEYSTORE_BASE64` | The base64-encoded keystore from Step 2 |
| `KEYSTORE_PASSWORD` | The keystore password from Step 1 |
| `KEY_ALIAS` | The key alias from Step 1 (e.g. `openllm-release`) |
| `KEY_PASSWORD` | The key password from Step 1 |

## Step 4: CI workflow

The workflow `.github/workflows/build.yml` already:

1. Decodes `KEYSTORE_BASE64` into `open_llm/android/app/release-keystore.jks`
   (only when the secret is set)
2. Writes `open_llm/android/key.properties` from the other three secrets
3. Builds the release APKs with `flutter build apk --release --split-per-abi`
   (one APK per ABI — arm64-v8a, armeabi-v7a, x86_64)
4. Verifies each APK's signature with `apksigner`
5. Uploads all split APKs as workflow artifacts

If the secrets are **not** set, the `Decode keystore` step is skipped, and
`build.gradle` falls back to the debug signing config so the CI build does not
break — the resulting APK just won't install on real devices without manual
resigning.

## Security

Never commit `release-keystore.jks`, `*.keystore`, `*.jks`, or
`key.properties` to the repository. They are already covered by `.gitignore`:

- `*.jks`
- `*.keystore`
- `**/key.properties`
- `**/release-keystore.jks`

## Local release build (optional)

To sign locally, create `open_llm/android/key.properties`:

```
storePassword=<KEYSTORE_PASSWORD>
keyPassword=<KEY_PASSWORD>
keyAlias=<KEY_ALIAS>
storeFile=release-keystore.jks
```

and place `release-keystore.jks` next to it, then run:

```bash
cd open_llm
flutter build apk --release
```
