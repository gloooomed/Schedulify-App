#!/bin/bash
echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:`pwd`/flutter/bin"

echo "Configuring Dart Defines..."
# Vercel Environment Variable containing the base64 encoded dart_defines.json
if [ -n "$DART_DEFINES_BASE64" ]; then
    echo $DART_DEFINES_BASE64 | base64 --decode > dart_defines.json
else
    echo "Warning: DART_DEFINES_BASE64 environment variable is not set."
    # Create an empty or fallback JSON if needed, though the build might fail without keys
    echo "{}" > dart_defines.json
fi

echo "Building Flutter Web PWA..."
flutter config --enable-web
flutter pub get
flutter build web --release --dart-define-from-file=dart_defines.json --pwa-strategy=offline-first
