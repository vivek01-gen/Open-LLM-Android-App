---
name: Flutter build environment
description: Flutter source projects can be authored here, but this workspace does not include the Flutter SDK for local compilation.
---

Flutter Android projects should include their own standard pubspec and Android shell, but runtime verification needs a Flutter-enabled machine or workspace. Do not claim `flutter run` or Dart compilation passed when the SDK is unavailable.

**Why:** The workspace is provisioned as a pnpm/TypeScript monorepo and does not expose `flutter` or `dart` on PATH.

**How to apply:** Keep the Flutter project self-contained under its app directory, document the verification limitation, and provide the source/archive for the user to run with Flutter.