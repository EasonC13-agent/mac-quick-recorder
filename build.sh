#!/bin/bash
set -e
cd "$(dirname "$0")"

APP="VoiceClip.app"
rm -rf "$APP"

mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/"
cp AppIcon.icns "$APP/Contents/Resources/"

swiftc VoiceClip.swift \
    -parse-as-library \
    -o "$APP/Contents/MacOS/VoiceClip" \
    -framework Cocoa \
    -framework AVFoundation \
    -framework Carbon \
    -target arm64-apple-macos13.0

echo "✅ Built $APP"
echo "Run: open $APP"
