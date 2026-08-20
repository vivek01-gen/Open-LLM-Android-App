# Open LLM

An offline-first Flutter Android app for chatting with quantized GGUF models through a local llama.cpp server.

## Run & Operate

- `pnpm --filter @workspace/api-server run dev` — run the API server (port 5000)
- `pnpm run typecheck` — full typecheck across all packages
- `pnpm run build` — typecheck + build all packages
- `pnpm --filter @workspace/api-spec run codegen` — regenerate API hooks and Zod schemas from the OpenAPI spec
- `pnpm --filter @workspace/db run push` — push DB schema changes (dev only)
- Required env: `DATABASE_URL` — Postgres connection string
- Flutter app source: `open_llm/`; run with `flutter pub get && flutter run` in a Flutter-enabled environment.

## Stack

- pnpm workspaces, Node.js 24, TypeScript 5.9
- API: Express 5
- DB: PostgreSQL + Drizzle ORM
- Validation: Zod (`zod/v4`), `drizzle-zod`
- API codegen: Orval (from OpenAPI spec)
- Build: esbuild (CJS bundle)

## Where things live

- `open_llm/lib/main.dart` — Material 3 screens and navigation
- `open_llm/lib/services/` — SQLite persistence, llama-server streaming client, app state, and Termux bridge
- `open_llm/lib/models/` — local chat/model/history records
- `open_llm/lib/theme/` — light and dark theme tokens
- `open_llm/android/` — Android app shell and optional Termux:API method channel

## Architecture decisions

- The app is local-only by design: the only network client is configurable llama-server and direct model downloads.
- SQLite is the source of truth for chats, messages, models, settings, MCP allowlists, and terminal history.
- Termux execution is opt-in and every command is gated by a confirm dialog before the native bridge is called.

## Product

On first launch, users review privacy, choose permissions, import/download GGUF models, chat with streaming responses from llama-server, and configure the endpoint, theme, MCP allowlist, and optional Termux integration.

## User preferences

The core app must function completely with Termux disabled and must not add cloud sync, accounts, analytics, or media generation.

## Gotchas

The Flutter SDK is not installed in this workspace, so Android runtime verification must be performed in a Flutter-enabled environment.

## Pointers

- See the `pnpm-workspace` skill for workspace structure, TypeScript setup, and package details
