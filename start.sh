#!/usr/bin/env bash
set -e

export PATH="/home/runner/flutter/bin:/home/runner/flutter/bin/cache/dart-sdk/bin:$PATH"
export BOT=true
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
export FLUTTER_ROOT=/home/runner/flutter

echo "=== Дыхание — Flutter Web ==="
echo "Flutter: $(flutter --version 2>&1 | head -1)"
echo "Starting dev server on port 5000..."

flutter run \
  -d web-server \
  --web-port 5000 \
  --web-hostname 0.0.0.0 \
  --no-pub \
  --no-enable-impeller
