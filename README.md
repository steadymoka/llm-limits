# LLM Limits

A compact macOS menu bar app for tracking Claude and Codex usage limits.

See both providers at a glance, check when limits reset, and get back to work.
Built with SwiftUI, with a minimal, developer-friendly interface.

## Features

- **Both providers, one menu bar** — Separate Claude / Codex percentages with provider icons. Only providers with available usage data appear.
- **Detailed limits** — Claude session, weekly, and model-specific limits alongside the default Codex limits. Extra Codex model buckets, such as Spark, stay hidden.
- **Reset countdowns** — See the reset date and time, plus how long is left.
- **Automatic Codex detection** — Uses the installed, signed-in Codex CLI without copying tokens into the app.
- **Automatic refresh** — Updates every 5 minutes, with manual refresh in the popover.

## Requirements

- macOS 14.0+
- Xcode or Command Line Tools with Swift 5.9+ to build from source
- One or both of:
  - An active Claude subscription
  - A current [Codex CLI](https://learn.chatgpt.com/docs/codex/cli) signed in with ChatGPT

## Quick start

```bash
git clone https://github.com/steadymoka/llm-limits.git
cd llm-limits
./scripts/install.sh
```

The script builds a release binary, installs `LLM Limits.app` in `/Applications`,
and launches it. Open its menu bar item to view usage or access settings.

## Setup

### Codex

No app configuration is needed. Install the Codex CLI and sign in:

```bash
codex login
```

LLM Limits reads rate limits through the CLI's local app server. API-key billing
does not provide the ChatGPT subscription limits used by this app.

### Claude

1. Launch LLM Limits from the menu bar.
2. Open Settings.
3. In your browser, open `claude.ai`, then DevTools → Network.
4. Select a `claude.ai` request and copy its `Cookie` request header.
5. Paste it into Settings and save. The organization ID is resolved automatically.

Treat the cookie as a password: never share it in screenshots, issues, or commits.

## Update and relaunch

Quit LLM Limits using the power button at the bottom of its popover, then run
these commands from your local repository:

```bash
git pull --ff-only
./scripts/install.sh
```

The installer replaces the app bundle and launches the updated version. Your
saved settings remain in Application Support.

## Troubleshooting

- **Only one provider appears:** The menu bar shows successfully fetched usage, not installed apps alone. Check the other provider's section or Settings for a login or fetch error.
- **Codex is missing:** Ensure the Codex CLI is installed and signed in with ChatGPT, then refresh.
- **Claude stops updating:** Its session cookie may have expired. Save a fresh cookie in Settings.
- **Old UI after updating:** Fully quit the running app before reinstalling.

## Privacy and credentials

- Claude usage is read from `claude.ai/api/organizations/{orgId}/usage`.
- Claude credentials are stored in a local plaintext file at `~/Library/Application Support/llm-limits/.credentials`, not in macOS Keychain.
- Existing credentials from `~/Library/Application Support/cc-usage/` are migrated automatically.
- Codex credentials are never copied into LLM Limits; the installed Codex process handles its own cached login.

Usage requests require network access to the respective providers.

## Development

```bash
swift build
swift test
swift run LLMLimits
```

You can also open `Package.swift` in Xcode. Quit any installed copy first to avoid
running two menu bar instances.

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

LLM Limits is an independent project, not affiliated with Anthropic or OpenAI.
