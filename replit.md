# Дыхание — Ephemeral P2P Messenger

A Flutter web app for an ephemeral chat where messages disappear after a countdown timer.

## Stack

- **Flutter 3.24.5** (installed at `/home/runner/flutter`)
- **Dart 3.5.4**
- Single-file app: `lib/main.dart`

## How to run

The workflow `Start application` runs `bash start.sh`, which:
1. Launches `flutter run -d web-server --web-port 5000 --web-hostname 0.0.0.0`
2. Serves the app on port 5000 (Flutter dev server)

On first start, Flutter takes ~30–60 seconds to compile before the preview appears.

## Key setup notes

- Flutter SDK is installed at `/home/runner/flutter` (not via a Replit module — downloaded manually as a tarball)
- `flutter_tools` package dependencies are pre-resolved offline: `/home/runner/flutter/packages/flutter_tools/.dart_tool/package_config.json`
- `pub.dev` is not reachable from this environment — run `dart pub get --offline` for dependency changes
- `cupertino_icons` removed from `pubspec.yaml` (not used in code, requires network to download)
- `Color.withValues()` replaced with `Color.withOpacity()` for Flutter 3.24.5 compatibility (withValues was added in 3.27+)
- Web support added via `flutter create . --platforms=web` (generates the `web/` folder)

## Project structure

```
lib/main.dart       — all app code (chat UI, disappearing messages)
web/                — Flutter web target files (index.html, manifest, icons)
start.sh            — workflow startup script
pubspec.yaml        — project dependencies
```

## User preferences

- Russian language UI
