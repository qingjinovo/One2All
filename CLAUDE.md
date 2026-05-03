# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

One2All is a cross-platform (Windows/macOS/Linux/Android/iOS) device interconnection app for **peer-to-peer messaging and clipboard synchronization**. Devices pair via a 6-digit code, then communicate directly over WebRTC data channels — the signaling server only facilitates connection setup, not data relay.

## Build & Run Commands

### Flutter App
```bash
flutter pub get                  # Install dependencies
flutter run                      # Run on connected device/emulator
flutter run -d windows           # Run on Windows desktop
flutter run -d chrome            # Run on web
flutter analyze                  # Static analysis (0 issues as of 2026-05-02)
flutter test                     # Run tests (currently empty)
dart run build_runner build      # Generate code (json_serializable — currently unused)
```

### Signaling Server
```bash
cd server
dart pub get
dart run bin/server.dart [port]  # Defaults to ws://0.0.0.0:8080
# Or compile and run:
dart compile exe bin/server.dart -o bin/server.exe
./bin/server.exe
```

### Quick Start (Tested 2026-05-02)
```bash
# 1. Start signaling server
cd server && dart run bin/server.dart

# 2. In another terminal, run Flutter app
flutter run -d windows

# 3. App connects to ws://localhost:8080 automatically
```

## Architecture

### Two Components
- **`lib/`** — Flutter client app (Provider-based state management)
- **`server/`** — Standalone Dart WebSocket signaling server

### Service Layer (callback-driven)
Four services injected via `MultiProvider` in `main.dart`. All use **mutable single-subscriber callback fields** (not streams/ChangeNotifier):

| Service | File | Role |
|---|---|---|
| `SignalingService` | `lib/services/signaling_service.dart` | WebSocket to server; auto-reconnect with exponential backoff; ping/pong keep-alive every 30s |
| `WebRTCService` | `lib/services/webrtc_service.dart` | RTCPeerConnection per peer; data channels; SDP/ICE exchange |
| `MessageService` | `lib/services/message_service.dart` | Send/receive text & clipboard messages over data channels; persist history to SharedPreferences as JSON |
| `ClipboardService` | `lib/services/clipboard_service.dart` | Polls clipboard every 2s; syncs changes to all connected peers |

### Data Flow
1. Device connects to signaling server via WebSocket, registers with UUID + name + type
2. User pairs devices using 6-digit code (signaling server forwards pairRequest/pairResponse)
3. WebRTC data channel established (STUN via Google public servers)
4. All messages/clipboard data flow peer-to-peer over data channels
5. Message history persisted locally in SharedPreferences

### Models (`lib/models/`)
All models (`Device`, `Message`, `SignalMessage`) are value objects with hand-written `toJson()`/`fromJson()`, `copyWith()`, and `==`/`hashCode` overrides. Note: `json_serializable` and `build_runner` are in dev_dependencies but are not actually used — serialization is manual.

### Screens (`lib/screens/`)
`HomeScreen` → device list. `PairingScreen` → 6-digit code pairing. `ChatScreen` → 1:1 messaging. `SettingsScreen` → server URL, device name, clipboard toggle. Navigation uses imperative `Navigator.push`.

## Code Style

- Linter: `flutter_lints` with `prefer_const_constructors` and `prefer_const_declarations` enabled, `avoid_print` disabled
- SDK constraint: `>=3.0.0 <4.0.0` (Dart 3.x required)
- Material 3 theming with `colorSchemeSeed: Colors.blue`
- Use `.withValues(alpha: x)` instead of deprecated `.withOpacity(x)`

## Platform Notes

- Flutter SDK path on this machine: `C:\SDK\flutter\`
- Use `powershell.exe -Command "C:\SDK\flutter\bin\flutter.bat ..."` if `flutter` is not in PATH
- WebRTC (`flutter_webrtc`) requires native platform setup for each target
- `file_picker` has plugin warnings on Linux/macOS/Windows (non-critical, package maintainer issue)

## Incomplete/TODO Items

- File transfer is stubbed (`_attachFile` in ChatScreen shows "coming soon")
- Pairing code-to-device-ID mapping has a TODO (currently uses code directly as device ID)
- `ChatScreen` line ~140: `// TODO: use actual device ID` for message ownership
