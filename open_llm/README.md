# Open LLM

Offline-first Flutter Android chat client for quantized GGUF models. Runs AI entirely on your phone against a local `llama.cpp`-compatible endpoint (a bundled `llama-server`, or one you run yourself) — no account, no cloud, no telemetry.

## Features

- **Fully offline local AI**: chat streams from a local endpoint you control (default `http://127.0.0.1:8080`). Nothing leaves the device.
- **Bundled, device-aware model catalog**: after onboarding the app scans RAM, CPU cores, and free app-private storage, then recommends GGUF models that fit your device (tiers: up to ~2B / ~4B / ~7B parameters). Catalog links are bundled in the app — no remote catalog API.
- **Model integrity**: downloads are user-initiated, checked for the GGUF magic header and complete response length, and SHA-256 verified when the catalog entry provides a checksum.
- **Custom models**: import a `.gguf` via the system file picker, or paste a direct download URL. Saved to app-private storage only.
- **SQLite on-device storage**: chats, messages, models, settings, MCP allowlist, terminal history, and network activity log — all in app-private internal storage, never on public shared storage.
- **App Lock**: optional device authentication (biometric, PIN, pattern, or password) via `local_auth`; locks chats on resume.
- **Network activity log**: last 50 explicit local network requests, opt-in.
- **Optional Termux integration**: disabled by default. Even when enabled, **every** command requires an explicit per-command tap confirmation before it is sent to Termux:API — nothing runs silently.
- **MCP allowlist**: explicitly added server URLs only; adding a URL does not connect to or trust it.
- **Clear All Data**: wipes the SQLite database, downloaded models, and all settings irreversibly.

## Tech stack

| Layer | Choice |
|---|---|
| UI | Flutter (Material 3) |
| Language | Dart SDK `>=3.3.0 <4.0.0` (null-safe) |
| State management | Provider (`ChangeNotifier`) |
| Local database | SQLite via `sqflite` (app-private storage) |
| HTTP client | `http` — localhost-only llama.cpp-compatible endpoint |
| Device info | `device_info_plus` |
| Biometrics / App Lock | `local_auth` |
| File picking | `file_picker` |
| URL launching | `url_launcher` |
| Formatting | `intl` |
| Checksums | `crypto`, `convert` (SHA-256) |
| Android | Gradle, Kotlin, compileSdk 36, minSdk 24, Java 17, ProGuard + resource shrinking in release |
| Lints | `flutter_lints` (`analysis_options.yaml`) |
| CI | GitHub Actions (Flutter 3.24.5, JDK 17) — release APKs signed via keystore secrets, split per ABI, signature-verified with `apksigner` |

## Architecture

```text
+----------------------+       +-------------------------------+
|   Flutter UI layer   |       |   AppState (Provider +        |
|  Chats · Model Hub   |<=====>|  ChangeNotifier)              |
|  Settings · Lock     |       |  + SQLite (sqflite): chats    |
+----------------------+       |  + messages, models, settings |
         |                     |  + MCP allowlist, terminal    |
         | HTTP (loopback)     |  + history, network logs      |
         v                     +-------------------------------+
+----------------------+                    | ^
|  llama-server        |====================+ |
|  (local, 127.0.0.1)  |                    | | MethodChannel
|  started via         |                    | v
|  ModelServerService  |              +----------------+
|  or started manually |              | Native Android |
+----------------------+              | (Kotlin)       |
                                      |  • model_server |
                                      |  • device       |
                                      |  • termux       |
                                      +----------------+

Data flow: pick a model → app validates GGUF header + SHA-256 → stored in app-private `models/` →
ModelServerService starts llama-server (device-tuned threads/context) over a MethodChannel →
LlamaService streams chat completions over http://127.0.0.1:8080 → UI renders streamed tokens.
All network traffic stays on loopback.
```

## Security

- **Data stays local**: chats, models, and settings live in app-private internal storage; no cloud sync, no analytics, no crash reporting.
- **No broad shared-storage permission**: file-picker access is granted per-selection by the user; downloads go to app-private storage only.
- **Endpoint lockdown**: `LlamaService` only accepts `http` endpoints on `localhost`, `127.0.0.1`, or `::1`.
- **App Lock**: optional device authentication unlocks the app on resume when enabled.
- **Termux confirm gate**: Termux:API is off by default; every command needs an explicit per-command tap confirmation before execution.
- **Model integrity**: GGUF magic-header check, complete-length check, and SHA-256 verification when a catalog checksum exists.
- **MCP allowlist**: server URLs are allowlisted only; adding a URL never connects or trusts it.
- **Release signing**: CI signs release APKs (v2/v3 signature scheme) from GitHub secrets, so fresh installs don't hit "App not installed". Keystore and passwords are never committed — see `ANDROID_SIGNING.md` and `.gitignore` (`*.jks`, `*.keystore`, `**/key.properties`).

## Build & CI

### Prerequisites

- Flutter 3.24.5 (stable channel)
- Android SDK: compileSdk 36, build-tools 35.0.0
- JDK 17

### Local development

```bash
cd open_llm
flutter pub get
flutter analyze      # verify no compile or lint errors
flutter run          # debug build on a connected device/emulator
```

### Release APK (split per ABI)

```bash
flutter build apk --release --split-per-abi
```

Outputs (one per ABI) under `build/app/outputs/flutter-apk/`:

- `app-arm64-v8a-release.apk` — install this on modern phones (recommended)
- `app-armeabi-v7a-release.apk`
- `app-x86_64-release.apk`

### Signing a release build locally

1. Generate a keystore:

```bash
keytool -genkey -v -keystore release-keystore.jks \
  -alias openllm-release -keyalg RSA -keysize 2048 -validity 10000
```

2. Create `open_llm/android/key.properties` (**do not commit** — covered by `.gitignore`):

```
storePassword=<KEYSTORE_PASSWORD>
keyPassword=<KEY_PASSWORD>
keyAlias=<KEY_ALIAS>
storeFile=release-keystore.jks
```

3. Place `release-keystore.jks` next to it, then run the release build above.

Full GitHub Actions secret setup (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`) is in `ANDROID_SIGNING.md`. If no keystore is configured, Gradle falls back to the debug signing config so CI never breaks — but that APK will not install on real devices without resigning.

### Reproducible builds

`pubspec.lock` is committed so CI installs exactly the same dependency versions. Regenerate it only when dependencies change:

```bash
cd open_llm && flutter pub get   # updates pubspec.lock
git add open_llm/pubspec.lock
```

## Changelog

### Unreleased
- Release signing: `signingConfigs.release` reads `key.properties`/CI secrets; `build.gradle` falls back to debug signing when no keystore exists so CI never breaks
- CI now builds `flutter build apk --release --split-per-abi`, verifies every APK with `apksigner`, and uploads all split APKs as artifacts
- `pubspec.lock` generated by `flutter pub get` (CI runs it); not git-ignored so it can be committed for reproducible builds — generate once Flutter is available locally
- `analysis_options.yaml` with `flutter_lints`; release builds run ProGuard + resource shrinking
- Settings screen: active GGUF model dropdown value is validated against the catalog and falls back to the first model, fixing a crash when the persisted model is missing
- ProGuard rules added for `MainActivity`/MethodChannel bridge and sqflite so release minify does not strip platform-channel code

### 1.0.0 (initial release)
- Dart null-safety and `sqflite` parameter type fixes merged (`database_service.dart`, `app_state.dart`, callers)
- Android Gradle wrapper aligned to the offline toolchain (JDK 17, compileSdk 36)
- Initial SQLite-backed local chat, bundled GGUF model catalog, App Lock, optional Termux integration

## Known limitations

- **Image/video attachments (v2)**: `Message.attachmentPath` exists as a placeholder, but only text messages are handled — image/video support is planned for v2.
- **MCP servers (list-only)**: the allowlist UI (add/delete URLs) works, but no active MCP client connections yet — adding a URL does not connect.
- **Termux integration**: optional and off by default; requires Termux:API on the device; every command is manually confirmed before execution.
- **llama-server**: the app starts a bundled `bin/llama-server` if present; otherwise you must run a local `llama-server` yourself and set the endpoint in Settings.
- **Catalog models**: downloaded from third-party Hugging Face repositories; Open LLM does not guarantee their safety, license, availability, or outputs — review each model repository's license before use.
- **ARM64 first**: split-per-abi APKs cover arm64-v8a, armeabi-v7a, and x86_64; `arm64-v8a` covers nearly all modern phones.

## License

MIT License

Copyright (c) 2026 Open LLM contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
