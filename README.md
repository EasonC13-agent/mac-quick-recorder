# VoiceClip 🎤

A lightweight macOS menu bar app for quick voice recording. Record, auto-convert to MP3, and paste directly into Discord (or anywhere).

## Features

- **Global hotkey** (default: `⇧V`) to start/stop recording
- **Menu bar indicator** with red recording icon
- Auto-converts to MP3 via ffmpeg (falls back to m4a)
- Copies audio file to clipboard for instant paste
- Customizable hotkey from menu bar

## Install

Download `VoiceClip.dmg` from [Releases](https://github.com/EasonC13-agent/mac-quick-recorder/releases), drag to Applications.

> Note: On first launch, macOS will ask for microphone permission. You may also need to allow it in System Settings > Privacy & Security.

## Requirements

- macOS 13.0+
- [ffmpeg](https://formulae.brew.sh/formula/ffmpeg) (optional, for MP3 conversion): `brew install ffmpeg`

## Build from Source

```bash
./build.sh
open VoiceClip.app
```

## License

MIT
