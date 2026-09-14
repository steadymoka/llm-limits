# LLM Limits

A compact macOS menu bar app for tracking Claude and Codex usage limits.

See both providers at a glance, check when limits reset, and get back to work.
Built with SwiftUI, with a minimal, developer-friendly interface.

## Features

- **Every account, one menu bar** — Separate Claude / Codex percentages with provider icons, one number per account with the active account first. Only providers with available usage data appear.
- **Multiple Claude accounts** — Accounts managed by Orca are discovered automatically, including the ones you are not currently signed in to, so you can see which account still has headroom before switching.
- **Honest freshness** — Each account shows where its numbers came from and how old they are (`LIVE` for a direct fetch, `ORCA 8m` for Orca's cached snapshot).
- **Detailed limits** — Claude session, weekly, and model-specific limits alongside the default Codex limits. Extra Codex model buckets, such as Spark, stay hidden.
- **Reset countdowns** — See the reset date and time, plus how long is left.
- **Automatic Codex detection** — Uses the installed, signed-in Codex CLI without copying tokens into the app.
- **Automatic refresh** — Updates every 5 minutes, with manual refresh in the popover.

## Requirements

- macOS 14.0+
- Xcode or Command Line Tools with Swift 5.9+ to build from source
- One or more of:
  - An active Claude subscription
  - Orca with one or more managed Claude accounts (`orca account add`)
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

Accounts come from two sources, and both can be used at once.

**Orca (no setup).** If Orca is installed with managed Claude accounts, LLM Limits
reads `orca account list --json` and shows every account — active and inactive —
with its session, weekly, and Fable weekly limits. Orca caches these values, so
each account displays the age of its snapshot. LLM Limits never launches Orca; if
Orca is closed, the last values it read stay on screen.

**Session cookie (optional, per account).** Registering a cookie upgrades that one
account to a direct `claude.ai` fetch, so its numbers are current on every refresh
instead of however old Orca's snapshot is. When the response includes them, the
Sonnet and Claude Design rows appear too:

1. Open Settings from the menu bar popover.
2. Press `쿠키` next to the account you want to upgrade (or `쿠키 추가`).
3. In your browser, open `claude.ai`, then DevTools → Network.
4. Select a `claude.ai` request and copy its `Cookie` request header.
5. Paste it and save. The organization ID is resolved automatically and matched
   against the account; if the cookie belongs to a different account, LLM Limits
   says so instead of binding it to the wrong one.

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
- **A Claude account is missing:** Confirm it is managed by Orca (`orca account list`) and that Orca is running, or register that account's cookie in Settings.
- **An account's numbers look stale:** The `ORCA 30m` badge is the age of Orca's own snapshot, which the CLI does not refresh on read. Register a cookie for that account to fetch it directly instead.
- **Codex is missing:** Ensure the Codex CLI is installed and signed in with ChatGPT, then refresh.
- **Claude stops updating:** Its session cookie may have expired. Save a fresh cookie in Settings.
- **Old UI after updating:** Fully quit the running app before reinstalling.

## Privacy and credentials

- Claude usage is read from `claude.ai/api/organizations/{orgId}/usage` for accounts with a registered cookie.
- Claude session cookies are stored in a local plaintext JSON file at `~/Library/Application Support/llm-limits/.credentials`, mode `0600`, not in macOS Keychain.
- Credentials from `~/Library/Application Support/cc-usage/` and from the earlier single-account format are migrated automatically on first read.
- Orca and Codex credentials are never copied into LLM Limits; each CLI handles its own cached login and LLM Limits only reads the usage numbers they report.

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
├── ClaudeUsageApp.swift          # 앱 진입점 + 메뉴바 라벨
├── Models/
│   ├── CodexUsageData.swift      # Codex app-server 응답
│   ├── OrcaSnapshot.swift        # orca account list --json 응답과 정규화
│   ├── ProviderAccount.swift     # 계정 신원(AccountKey)과 표시 모델(AccountCard)
│   ├── UsageData.swift           # claude.ai 응답
│   └── UsageRow.swift            # 소스 중립적인 한도 표시 행
├── Services/
│   ├── AccountRegistry.swift     # 소스별 결과를 계정 단위로 병합
│   ├── ClaudeUsageClient.swift   # 쿠키 기반 claude.ai 호출
│   ├── CodexUsageClient.swift
│   ├── CredentialsStore.swift    # 계정별 쿠키 저장(v2 JSON, 0600)
│   ├── KeychainService.swift
│   ├── ManagedProcess.swift      # 자식 프로세스 정리 + 실행 파일 탐색
│   ├── OrcaAccountsClient.swift  # Orca 계정/사용량 스냅샷
│   └── UsageService.swift
└── Views/
    ├── Components/
    │   ├── AccountSectionView.swift
    │   └── UsageRowView.swift
    ├── SettingsView.swift
    └── UsagePopoverView.swift
```

LLM Limits is an independent project, not affiliated with Anthropic or OpenAI.
