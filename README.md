# Open LLM - Local & Offline AI Chat Client for Android

Open LLM is a fully local, 100% offline AI chat application built with Flutter for Android. It enables users to run quantized open-source Large Language Models (in GGUF format) directly on their mobile devices using an embedded or locally hosted `llama-server`.

---

## Table of Contents
- [Project Overview](#project-overview)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Architecture](#architecture)
- [Security & Privacy](#security--privacy)
- [Setup & Build Instructions](#setup--build-instructions)
- [Project Activity Log](#project-activity-log)
- [Known Limitations](#known-limitations)
- [License](#license)

---

## Project Overview

The core objective of **Open LLM** is to deliver complete privacy, independence, and offline capability for mobile AI interactions. Unlike cloud-dependent AI applications, Open LLM keeps your chats, prompts, model files, settings, and histories strictly on your device.

- **100% Offline & Private:** Zero cloud endpoints, zero telemetry, zero data tracking.
- **Hardware-Aware Performance:** Automatically detects device RAM, CPU core count, and storage to recommend optimal model sizes (Tier 1 Low, Tier 2 Mid, Tier 3 High).
- **Embedded llama.cpp Server Integration:** Streams token-by-token responses directly from `llama-server`.

---

## Features

- **Onboarding & Device Scanner:** Automatically scans total system RAM, CPU cores, and storage space to classify device capability into performance tiers.
- **Model Hub & Direct Catalog Downloads:** Curated library of direct Hugging Face GGUF downloads (TinyLlama 1.1B, Qwen2.5 1.5B, Gemma 2 2B, Phi-3 Mini 4B, Mistral 7B, Llama 3.1 8B) with automatic magic header and SHA-256 integrity checks. Supports custom GGUF URLs or local file imports.
- **Real-Time Streaming Chat:** Instant, token-by-token streaming chat responses with system prompt customization and message history management.
- **Image & Video Screens:** Integrated media gallery and screen placeholders for future local image/video generation features.
- **Termux Integration & Safety Gate:** Opt-in Termux API integration with a mandatory **confirm-before-execute** gate for terminal commands.
- **Model Context Protocol (MCP) Allowlist:** Manage and restrict server connections via MCP server allowlists.
- **Terminal History & Network Logs:** View local command history and inspect local HTTP network activity.
- **App Lock & Privacy Controls:** Optional biometric or PIN lock via `local_auth` and one-tap "Clear All Data" wipe.

---

## Tech Stack

| Component | Technology / Library | Version / Requirement |
| :--- | :--- | :--- |
| **Framework** | Flutter / Dart SDK | Flutter 3.24.5 / Dart `>=3.3.0 <4.0.0` |
| **Local Inference** | `llama.cpp` / `llama-server` | GGUF quantized models (Q4_K_M recommended) |
| **Database** | `sqflite` | `^2.3.3+1` |
| **State Management** | `provider` | `^6.1.2` |
| **Hardware Info** | `device_info_plus` | `^10.1.2` |
| **Authentication** | `local_auth` | `^2.3.0` |
| **HTTP Client** | `http` | `^1.2.2` |
| **File Picker** | `file_picker` | `^8.1.2` |
| **Path Provider** | `path_provider` | `^2.1.4` |
| **Cryptography** | `crypto` / `convert` | `^3.0.3` / `^3.1.2` |
| **URL Launcher** | `url_launcher` | `^6.3.0` |
| **Formatting** | `intl` | `^0.19.0` |

---

## Architecture

Open LLM follows a clean state-driven architecture separating UI, service management, local inference, and SQLite persistence:

```
+-------------------------------------------------------------------------+
|                              Flutter UI                                 |
|  (Onboarding, ChatScreen, ModelHub, SettingsScreen, Media & Terminal)   |
+-----------------------------------+-------------------------------------+
                                    |
                                    v
+-------------------------------------------------------------------------+
|                        AppState (Provider)                              |
|       (Manages active model, streaming response, app settings)          |
+-----------------+---------------------------------+---------------------+
                  |                                 |
                  v                                 v
+-----------------------------------+     +-------------------------------+
|       LlamaService / HTTP         |     |        DatabaseService        |
|   (http://127.0.0.1:8080/completion)   |     |    (SQLite: sqflite)          |
+-----------------+-----------------+     +-------------------------------+
                  |                                 | Stores: Chats, Messages,
                  v                                 | Models, Settings, MCP
+-----------------------------------+               | Allowlist, History log
|       llama-server Process        |               v
|  (Loads GGUF Model from Storage)  |     +-------------------------------+
+-----------------------------------+     |  App-Private Storage (GGUF)   |
                                          +-------------------------------+
```

### Data Flow Overview:
1. **User Action:** User inputs a prompt in `ChatScreen`.
2. **State Management:** `AppState` formats the prompt and sends an HTTP POST stream request to the local `llama-server` endpoint (`http://127.0.0.1:8080/completion`).
3. **Local Inference:** `llama-server` executes token generation using the loaded GGUF model and streams chunks back over local HTTP.
4. **UI Stream:** `AppState` updates the streaming message in real time on screen.
5. **Persistence:** Complete messages, model configurations, and terminal history are persisted into local `sqflite` SQLite storage.

---

## Security & Privacy

- **100% Local Storage:** All chat logs, settings, and downloaded models are stored in app-private directories (`path_provider`). No data is ever written to public or shared external storage.
- **Minimal Permissions:** The app uses scoped storage and requests permissions only when initiating model downloads or importing GGUF files. Broad `MANAGE_EXTERNAL_STORAGE` is strictly avoided.
- **Termux Safety Gate:** Commands dispatched via Termux require explicit user review and interactive confirmation before execution.
- **Zero Telemetry:** Open LLM contains no analytics, tracking scripts, or background cloud synchronization calls.
- **Model Integrity Protection:** Downloaded GGUF model files undergo magic header validation (`GGUF`) and SHA-256 checksum verification before activation.
- **Optional App Lock:** Protect app access with device biometric authentication or PIN using Android `local_auth`.

---

## Setup & Build Instructions

### Local Development Setup

1. **Prerequisites:**
   - Flutter SDK `3.24.5`
   - Android SDK (API Level 21+)
   - Java Development Kit (JDK 17)

2. **Clone Repository:**
   ```bash
   git clone https://github.com/vivek01-gen/Open-LLM-Android-App.git
   cd Open-LLM-Android-App/open_llm
   ```

3. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

4. **Run Application:**
   ```bash
   flutter run
   ```

5. **Build Release APK:**
   ```bash
   flutter build apk --release
   ```
   The built APK will be located at:
   `open_llm/build/app/outputs/flutter-apk/app-release.apk`

---

### CI/CD Pipeline

The project uses GitHub Actions (`.github/workflows/build.yml`) for automated release builds:
- **Runner:** `ubuntu-latest`
- **Java:** JDK 17 (Temurin distribution)
- **Flutter:** Pinned version `3.24.5`
- **Gradle:** Pinned Gradle `8.7` with Android Gradle Plugin (AGP) `8.5.2`
- **Output Artifact:** `open-llm-release-apk` (`app-release.apk`)

---

## Project Activity Log

| Date | Activity / Change | Description |
| :--- | :--- | :--- |
| **2025-02-28** | **Initial Commit** | Created base project structure, offline Flutter chat UI, SQLite schema, and llama-server client. |
| **2025-02-28** | **Gradle & AGP Compatibility Fix** | Added missing Gradle wrapper (`8.7`), pinned AGP (`8.5.2`), and pinned Flutter `3.24.5` in CI workflow to fix build failures. |
| **2025-02-28** | **Dart Null-Safety & Type Fixes (PR #1)** | Resolved Dart type errors, `sqflite` parameter casting issues, and null-safety violations across app services. |
| **2025-02-28** | **v1.0.0 Documentation & Release** | Created comprehensive documentation, verified 52.5 MB release APK build, and prepared GitHub release release assets. |

---

## Known Limitations

1. **Image & Video Features:** The Image and Video screens are currently UI/gallery interfaces and do not support on-device generative image/video inference yet.
2. **Hardware Constraints:** Token generation speed and max context length depend directly on your device CPU cores and available RAM. Models larger than Tier recommendations may cause lag or out-of-memory crashes.
3. **Termux Integration:** Using Termux integration requires the separate installation of the external [Termux](https://f-droid.org/en/packages/com.termux/) app and `Termux:API` package.

---

## License

This project is licensed under the **MIT License**. See the `LICENSE` file for details.
