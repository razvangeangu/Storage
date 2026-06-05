# Storage

A privacy-first, local macOS utility that shows what's using space on your Mac — with an expandable breakdown similar to System Settings, including System Data.

- **No network** — scanning and cleanup happen entirely on your Mac
- **No admin** — runs as a standard user; never asks for your password
- **Optional Full Disk Access** — unlocks deeper System Data visibility (not admin elevation)
- **Safe cleanup** — you choose what to delete; items move to Trash

## Download

Get the latest release from [GitHub Releases](https://github.com/razvangeangu/Storage/releases/latest).

1. Download `storage-macos-vX.Y.Z.zip`
2. Unzip and drag `Storage.app` to Applications
3. First launch: right-click the app → **Open** (Gatekeeper)
4. Optional: grant **Full Disk Access** in System Settings → Privacy & Security for System Data breakdown

## Build from source

```bash
open Storage.xcodeproj
# or
xcodebuild -scheme Storage -configuration Debug build
```

## Release build

```bash
./Scripts/release-macos.sh 1.0.0
```

## Requirements

- macOS 15 or later
- Standard user account (no administrator privileges required)
