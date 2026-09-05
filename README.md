# LLM Limits

A compact macOS menu bar app for monitoring Claude and Codex usage limits in one place.

## Features

- **Claude + Codex** — Shows every available limit in separate, recognizable provider sections
- **Automatic Codex detection** — Reuses the signed-in Codex CLI through its local app server; no token copy/paste
- **Menu bar indicators** — Shows Claude / Codex usage separately with provider icons; only available providers appear
- **Reset time** — Displays both absolute reset time and a relative countdown
- **Usage breakdown** — Includes Claude model limits and the default Codex limits; additional Codex model buckets are hidden
- **Auto refresh** — Syncs every 5 minutes

## Requirements

- macOS 14.0+
- Swift 5.9+
- One or both of:
  - An active Claude subscription
  - A current [Codex CLI](https://learn.chatgpt.com/docs/codex/cli) signed in with ChatGPT

## Install

```bash
./scripts/install.sh
```

This builds the app, creates `LLM Limits.app` in `/Applications`, and launches it.

## Development

```bash
swift build
swift run LLMLimits
```

Or open the package with Xcode:

```bash
open Package.swift
```

## Setup

### Codex

No app configuration is needed. Install the Codex CLI and sign in:

```bash
codex login
```

LLM Limits detects the executable and asks its local app server for the same rate-limit snapshot shown by Codex `/status`. API-key billing does not expose the ChatGPT subscription limit view.

### Claude

1. Launch LLM Limits from the menu bar.
2. Open Settings.
3. In your browser, open `claude.ai`, then DevTools → Network.
4. Select a `claude.ai` request and copy its `Cookie` request header.
5. Paste it into Settings and save. The organization ID is resolved automatically.

## Data and credentials

- Claude usage is read from `claude.ai/api/organizations/{orgId}/usage`.
- Claude credentials stay in `~/Library/Application Support/llm-limits/`.
- Existing credentials from `~/Library/Application Support/cc-usage/` are migrated automatically.
- Codex credentials are never copied into LLM Limits; the installed Codex process handles its own cached login.

## Project structure

```text
ClaudeUsage/
├── ClaudeUsageApp.swift
├── Models/
│   ├── CodexUsageData.swift
│   └── UsageData.swift
├── Services/
│   ├── CodexUsageClient.swift
│   ├── KeychainService.swift
│   └── UsageService.swift
└── Views/
    ├── Components/UsageRowView.swift
    ├── SettingsView.swift
    └── UsagePopoverView.swift
```

## License

MIT
