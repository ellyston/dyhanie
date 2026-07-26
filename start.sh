#!/usr/bin/env bash
set -e

export BOT=true
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
export FLUTTER_ROOT=/home/runner/flutter
export PATH="/home/runner/flutter/bin:/home/runner/flutter/bin/cache/dart-sdk/bin:$PATH"

FLUTTER_VERSION="3.24.5"
FLUTTER_DIR="/home/runner/flutter"

# Download Flutter SDK if not present
if [ ! -f "$FLUTTER_DIR/bin/flutter" ]; then
  echo "Flutter not found. Downloading Flutter $FLUTTER_VERSION..."
  cd /home/runner
  curl -sL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" -o flutter.tar.xz
  tar xf flutter.tar.xz
  rm flutter.tar.xz
  echo "Flutter downloaded."

  # Enable web support
  flutter config --enable-web --no-analytics

  # Resolve flutter_tools deps offline
  cd "$FLUTTER_DIR/packages/flutter_tools"
  dart pub get --offline
fi

cd /home/runner/workspace

echo "=== Дыхание — Flutter Web ==="
echo "Flutter: $(flutter --version 2>&1 | head -1)"
echo "Starting dev server on port 5000..."

flutter run \
  -d web-server \
  --web-port 5000 \
  --web-hostname 0.0.0.0 \
  --no-pub \
  --no-enable-impeller
