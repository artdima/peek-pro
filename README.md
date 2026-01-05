# Peek Pro

![status: work in progress](https://img.shields.io/badge/status-work%20in%20progress-orange)

A macOS app for the network calls recorded by [Peek](https://github.com/artdima/peek) —
live from a device running your Flutter app, or from a saved `.peek` session file.

Inspired by [Pulse Pro](https://github.com/kean/Pulse) — an independent app built for the Peek ecosystem.

## Requirements

- macOS 26 or later
- Xcode 26 to build

## Building

```sh
xcodebuild -project "Peek Pro.xcodeproj" -scheme "Peek Pro" -destination 'platform=macOS' build
```

## License

MIT — see [LICENSE](LICENSE).
