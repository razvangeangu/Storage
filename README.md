# Storage

A privacy-first, local macOS utility that shows what's using space on your Mac — with an expandable breakdown similar to System Settings, including System Data.

- **No network** — scanning and cleanup happen entirely on your Mac
- **No admin** — runs as a standard user; never asks for your password
- **Safe cleanup** — you choose what to delete; items move to Trash

## Download

Get the latest release from [GitHub Releases](https://github.com/razvangeangu/Storage/releases/latest).

1. Download `storage-macos-vX.Y.Z.zip`
2. Unzip and drag `Storage.app` to Applications
3. First launch: right-click the app → **Open** (Gatekeeper)

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

## Terminal scan (no GUI)

If Terminal.app has **Full Disk Access** (System Settings → Privacy & Security), this script mirrors the app’s scan from the command line — useful on locked-down Macs where the GUI app hits privacy prompts:

```bash
./Scripts/scan-storage.sh           # full scan (Containers, Application Support, …)
./Scripts/scan-storage.sh --safe      # skip TCC-sensitive folders (app default)
./Scripts/scan-storage.sh --top 30    # show more largest items

# Drill into a path from the "Top" list (copy the expand: line, or run manually):
./Scripts/scan-storage.sh --path ~/Developer/others --level 1   # immediate children
./Scripts/scan-storage.sh --path ~/Developer/others --level 3   # down to 3 folder levels
```

## Requirements

- macOS 15 or later
- Standard user account (no administrator privileges required)
