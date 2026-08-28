# Open LLM

An offline-first Flutter Android chat client for quantized GGUF models served by
`llama-server`. The app stores chats, messages, models, settings, MCP allowlists,
and terminal history in SQLite on-device.

## Run

```bash
flutter pub get
flutter run
```

Start a local server separately, for example:

```bash
llama-server -m /path/to/model.gguf --host 127.0.0.1 --port 8080
```

The endpoint is configurable from Settings. Termux:API is disabled by default
and every command requires an explicit confirmation.

## Device-aware model catalog

After onboarding, Open LLM scans Android device RAM, CPU cores, and available
app-private storage. The tier is determined by RAM:

- Tier 1 (Low): under 4 GiB RAM, up to approximately 2B parameters, 2,048-token context
- Tier 2 (Mid): 4 GiB to under 8 GiB RAM, up to approximately 4B parameters, 4,096-token context
- Tier 3 (High): 8 GiB or more RAM, up to approximately 7B parameters, 8,192-token context

The catalog is bundled in the app and does not call a catalog API. Its current
direct Hugging Face sources are:

- TinyLlama 1.1B Chat:
  `TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf`
- Qwen2.5 1.5B Instruct:
  `bartowski/Qwen2.5-1.5B-Instruct-GGUF/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf`
- Gemma 2 2B IT:
  `bartowski/gemma-2-2b-it-GGUF/gemma-2-2b-it-Q4_K_M.gguf`
- Phi-3 Mini 4K 4B:
  `bartowski/Phi-3-mini-4k-instruct-GGUF/Phi-3-mini-4k-instruct-Q4_K_M.gguf`
- Mistral 7B Instruct:
  `TheBloke/Mistral-7B-Instruct-v0.2-GGUF/mistral-7b-instruct-v0.2.Q4_K_M.gguf`
- Llama 3.1 8B Instruct:
  `bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf`

Catalog downloads are user initiated, saved under app-private storage, checked
for the GGUF magic header and complete response length, and SHA-256 checked
when a catalog entry provides a checksum. If an app-private
`bin/llama-server` executable is present, the app starts it with device-tuned
threads, context size, and `--mmap`; otherwise it clearly tells the user to
start their local server manually.

## Privacy and security

App Lock, the network activity log, and Termux are opt-in. Clear All Data
deletes the SQLite database and downloaded model directory. The app requests no
broad shared-storage permission and makes no background network requests.