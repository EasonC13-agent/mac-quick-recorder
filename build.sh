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
    -o "${APP}/Contents/MacOS/VoiceClip-arm64" \
    -framework Cocoa \
    -framework AVFoundation \
    -framework Carbon \
    -target arm64-apple-macos13.0

swiftc VoiceClip.swift \
    -parse-as-library \
    -o "${APP}/Contents/MacOS/VoiceClip-x86" \
    -framework Cocoa \
    -framework AVFoundation \
    -framework Carbon \
    -target x86_64-apple-macos13.0

lipo -create \
    "${APP}/Contents/MacOS/VoiceClip-arm64" \
    "${APP}/Contents/MacOS/VoiceClip-x86" \
    -output "${APP}/Contents/MacOS/VoiceClip"

rm "${APP}/Contents/MacOS/VoiceClip-arm64" "${APP}/Contents/MacOS/VoiceClip-x86"

echo "✅ Built $APP"
echo "Run: open $APP"
