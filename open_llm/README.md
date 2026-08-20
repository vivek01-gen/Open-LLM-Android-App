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