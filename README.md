# Kzu — Setup Guide

## Prerequisites

- **macOS 14+** (Sonoma) with **Xcode 15+**
- Physical iOS device for testing FamilyControls (Simulator not supported)
- Apple Developer account with **FamilyControls** capability enabled

## Quick Start

### 1. Install XcodeGen

```bash
brew install xcodegen
```

### 2. Generate the Xcode Project

```bash
cd /path/to/kzu
xcodegen generate
```

This reads `project.yml` and creates `Kzu.xcodeproj` with all 4 targets:
- **Kzu** — Main app
- **DeviceActivityMonitorExtension** — Background timer enforcement
- **ShieldConfigurationExtension** — Custom shield overlay UI
- **KzuTests** — Unit test bundle

### 3. Configure Signing

Open `Kzu.xcodeproj` in Xcode and:

1. Select the **Kzu** target → Signing & Capabilities
2. Set your **Development Team**
3. Repeat for both extension targets

> ⚠️ All 3 targets must use the **same Development Team**.

### 4. Enable FamilyControls

In the [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers):

1. Edit the App ID for `com.kzu.app`
2. Enable the **Family Controls** capability
3. Repeat for `com.kzu.app.DeviceActivityMonitor` and `com.kzu.app.ShieldConfiguration`

### 5. Configure App Group

In Xcode, ensure all 3 targets have:
- **App Groups** capability with `group.com.kzu.shared`

This is already set in the `.entitlements` files, but Xcode needs the capability registered in the portal.

### 6. Build & Run

```bash
# Build
xcodebuild -scheme Kzu -destination 'generic/platform=iOS' build

# Run tests (Simulator OK for logic tests)
xcodebuild test -scheme Kzu -destination 'platform=iOS Simulator,name=iPhone 16'

# Run on device
xcodebuild -scheme Kzu -destination 'id=YOUR_DEVICE_UDID' run
```

## Project Structure

```
kzu/
├── project.yml                    ← XcodeGen project spec
├── README.md                      ← This file
├── Kzu/                           ← Main app target
│   ├── App/                       ← Entry point + state machine
│   ├── Shield/                    ← FamilyControls / ManagedSettings
│   ├── ContentEngine/             ← Curriculum ingest + scoring
│   ├── Views/                     ← SwiftUI learning views
│   │   ├── K2/                    ←   K-2 Foundational
│   │   └── Upper/                 ←   3-8 Chapter Journey
│   ├── GameHub/                   ← SpriteKit mini-games
│   │   └── Games/                 ←   Zen Garden, Physics, Rhythm
│   ├── Dashboard/                 ← Parental Focus Growth
│   ├── Design/                    ← Neo-skeuomorphic design system
│   ├── Resources/                 ← Curriculum JSON files
│   └── Assets.xcassets/           ← Colors + app icon
├── DeviceActivityMonitorExtension/← Background timer extension
├── ShieldConfigurationExtension/  ← Custom shield overlay
├── KzuTests/                      ← Unit tests
└── Android/                       ← Android kiosk mode outline
```

## Testing on Device

FamilyControls requires a **physical device** with Screen Time enabled:

1. On the device: Settings → Screen Time → Turn On
2. Build and run Kzu on the device
3. When prompted, grant Screen Time authorization (act as parent)
4. Select apps to block during learning sessions
5. Tap "Begin Your Flow" to start a Pomodoro cycle

## Architecture Notes

- **Shields persist across app kill** — `ManagedSettingsStore` is system-level
- **Extension survives termination** — `DeviceActivityMonitor` runs as a separate process
- **App Group communication** — Extensions and main app share state via `UserDefaults(suiteName:)`
- **Darwin notifications** — Extension→App signaling uses `CFNotificationCenter`
