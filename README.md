# cc-usage

macOS menu bar app that monitors your [Claude](https://claude.ai) API usage in real-time.

## Features

- **Menu bar indicator** — Shows current usage percentage with color-coded status
- **Usage breakdown** — 5-hour session, weekly (all models), weekly (Sonnet), weekly (Claude Design)
- **Reset time** — Displays both absolute time and relative countdown
- **Auto refresh** — Polls every 5 minutes

## Requirements

- macOS 14.0+
- Swift 5.9+
- Active Claude Pro/Team subscription

## Install

```bash
./scripts/install.sh
```

This builds the app, creates `cc-usage.app` in `/Applications`, and launches it.

## Development

```bash
swift build
swift run
```

Or open with Xcode:

```bash
open Package.swift
```

## Setup

1. Launch the app (appears in menu bar)
2. Click the sparkle icon → Settings
3. Paste your session cookie:
   - Open [claude.ai](https://claude.ai) in browser
   - Open DevTools (F12) → Network tab
   - Click any request to claude.ai
   - Copy the `Cookie` header value
4. Click Save — the org ID is fetched automatically

## How It Works

The app reads usage data from `claude.ai/api/organizations/{orgId}/usage` using your session cookie. Credentials are stored locally in `~/Library/Application Support/cc-usage/`.

## Project Structure

```
ClaudeUsage/
├── ClaudeUsageApp.swift          # App entry, MenuBarExtra
├── Models/
│   └── UsageData.swift           # API response models
├── Services/
│   ├── KeychainService.swift     # Keychain helper (legacy)
│   └── UsageService.swift        # API client, polling, storage
└── Views/
    ├── SettingsView.swift         # Cookie input window
    ├── UsagePopoverView.swift     # Main popover UI
    └── Components/
        └── UsageRowView.swift     # Usage metric row
```

## License

MIT
