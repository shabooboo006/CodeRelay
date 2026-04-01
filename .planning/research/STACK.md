# Technology Stack

**Project:** CodeRelay  
**Researched:** 2026-04-01  
**Scope:** Stack recommendation for a Codex-only macOS desktop app  
**Overall confidence:** HIGH

## Recommended Stack

CodeRelay should be a **native macOS app in Swift**, not a Tauri app. The product is narrow, macOS-specific, and its core jobs are local file control, Codex CLI lifecycle management, usage polling, warning notifications, and explicit account switching. CodexBar already proves the right architectural direction: SwiftUI views, AppKit control points, strict-concurrency Swift modules, and per-account `CODEX_HOME` handling. cc-switch proves the switching mechanic, but not the foundation.

For v1, optimize for **Codex CLI-first** switching and resume. Treat **Codex App restart/resume** as a later technical validation track, not as a design constraint that forces a more generic or more invasive foundation now.

### Foundation

| Technology | Version / Baseline | Purpose | Why |
|------------|--------------------|---------|-----|
| Xcode | `26.3+` | Primary Apple toolchain | Current stable Apple toolchain as of April 2026; use the current Xcode 26 line for macOS shipping work. |
| Swift | `6.3` toolchain, strict concurrency enabled | Main language | Current Swift.org install track is 6.3; use strict concurrency because CodexBar already follows that direction and CodeRelay is background-refresh heavy. |
| Deployment target | `macOS 15.0+` | App runtime baseline | Reasonable 2026 greenfield floor for a developer-only utility app; lowers compatibility drag while keeping native APIs modern. |
| App architecture | `SwiftUI + AppKit bridge` | Desktop UI and system integration | SwiftUI for settings/account screens, AppKit for menu bar control, app lifecycle, relaunch control, and macOS-specific behavior. |
| Packaging | `Xcode app target + local SwiftPM packages/targets` | Module split and reuse | Keeps the app native while letting Codex/CodexBar-derived logic live in testable Swift modules. |
| Distribution | `Developer ID signed + notarized direct distribution` | Shipping model | v1 should not be App Store-first because it needs to manage `~/.codex`, launch external processes, and avoid sandbox friction. |

### App Foundation and Module Split

Use one Xcode workspace with one app target and a few local Swift packages/targets:

| Module | Responsibility | Why This Split |
|--------|----------------|----------------|
| `CodeRelayApp` | `@main` app, AppDelegate bridge, status item/menu wiring, settings windows, notification wiring | Keeps macOS lifecycle/UI code out of the Codex integration layer. |
| `CodeRelayCore` | Account models, thresholds, warning policy, persistence contracts, switch audit models | Pure domain code with no direct CLI or AppKit dependency. |
| `CodeRelayCodex` | `CODEX_HOME` scoping, Codex CLI probes, app-server client, PTY fallback, login flow, conversation/session discovery | All Codex-specific logic lives here; this is the main place to port CodexBar concepts. |
| `CodeRelaySwitching` | Live-file swap engine, backup/rollback, active-account activation, restart/resume orchestration | Separates "manage accounts" from "make account live now". |
| `CodeRelayLauncher` | Tiny bundled helper executable for CLI reopen/resume flows | Gives v1 a stable launch surface for `codex` and `codex resume` without pushing terminal automation into the UI target. |

Recommended rule: **the app target depends on modules; modules do not depend on the app target**.

### Persistence

Do **not** start with SwiftData or SQLite in v1. CodeRelay is too narrow to justify a database-first architecture, and cc-switch's SQLite design exists because it manages many providers, presets, MCP, prompts, skills, sync, and backups. CodeRelay does not.

Use **versioned JSON + JSONL + managed directories**:

| Store | Location | Format | Purpose | Why |
|-------|----------|--------|---------|-----|
| Managed account registry | `~/Library/Application Support/CodeRelay/managed-codex-accounts.json` | `Codable` JSON, atomic write, `0600` perms | List of accounts, ids, email, managed-home path, auth timestamps | This directly matches the CodexBar pattern and is enough for v1. |
| Managed homes root | `~/Library/Application Support/CodeRelay/managed-codex-homes/<uuid>/` | Directory tree | Per-account `CODEX_HOME` source of truth | Keeps each Codex account isolated and avoids stuffing auth blobs into a DB. |
| UI prefs | `UserDefaults` / `@AppStorage` | plist | Active account id, warning threshold, polling cadence, launch-at-login toggle | Light, native, low-risk. |
| Usage cache | `~/Library/Application Support/CodeRelay/usage-snapshots.json` | JSON | Last known usage snapshot per account | Enough for warnings, stale-state handling, and fast startup. |
| Switch / resume audit | `~/Library/Application Support/CodeRelay/events/*.jsonl` | Append-only JSONL | Switch history, restart attempts, resume attempts, failures | Simple append-only diagnostics; better than premature DB design. |
| Live Codex files | `~/.codex/auth.json` and `~/.codex/config.toml` | Derived live state | What the active Codex CLI actually uses after a switch | Keep this as a derived output, not the primary account database. |

### Codex Integration Stack

| Layer | Recommended Approach | Confidence | Why |
|------|-----------------------|------------|-----|
| Usage monitoring | Port CodexBar's **Codex CLI app-server / RPC** approach first | HIGH | CodexBar already uses `account/read` and `account/rateLimits/read`, which is the cleanest current path for usage windows and identity. |
| Fallback monitoring | Keep the **PTY `/status` probe** as a fallback only | HIGH | CodexBar already ships this path and it covers CLI/RPC drift or temporary failures. |
| Managed account auth | Use per-account `CODEX_HOME` directories and run `codex login` inside that scoped home | HIGH | CodexBar already proves the pattern with `CodexHomeScope` and `ManagedCodexAccountService`. |
| Conversation discovery | Use current Codex CLI session artifacts plus app-server conversation schema | HIGH | Local `codex` 0.63.0 exposes `resume`, session files, and app-server JSON schema for conversation list/resume shapes. |
| v1 resume path | Resume **Codex CLI** sessions only, via stored `cwd` + session id or `codex resume --last` | MEDIUM-HIGH | The capability is present today; the exact UX wrapper is an app design choice, not a missing platform capability. |
| Codex App lifecycle | Defer to follow-on validation | LOW for now | Do not shape v1 around unvalidated app automation requirements. |

### System APIs to Use

| API / Framework | Use | Why |
|-----------------|-----|-----|
| `SwiftUI` | Settings, account management screens, warning detail views | Native UI with low boilerplate. |
| `Observation` | App state and store observation | This matches modern SwiftUI state flow and aligns with CodexBar's current direction. |
| `AppKit` `NSStatusItem` / `NSMenu` / `NSApplicationDelegateAdaptor` | Menu bar app shell and lifecycle escape hatches | CodexBar already proves this style; it gives more control than forcing a pure SwiftUI menu-bar architecture. |
| `Foundation.Process` + `FileManager` | Run `codex`, perform live-file swaps, create managed homes, backups | Native, dependency-free process and filesystem control. |
| `UNUserNotificationCenter` | Warning notifications and switch prompts | Native local notifications are enough for threshold warnings. |
| `NSWorkspace` + `NSRunningApplication` | Detect and relaunch CLI host apps later, manage app activation | Needed for controlled restart flows; still native and lightweight. |
| `ServiceManagement.SMAppService` | Optional launch-at-login | Standard macOS utility-app behavior. |
| `OSLog.Logger` | Logging and diagnostics | Native logging without adding `swift-log` unless later needed. |

### Dependencies

Default stance: **no third-party runtime dependencies in v1**.

| Dependency | Recommendation | Why |
|------------|----------------|-----|
| Sparkle | Defer until distribution/update workflow exists | Useful later for notarized direct distribution, but not required to validate the core workflow. |
| TOML parser/editor | Do not add in v1 | CodeRelay can treat each account's `config.toml` as opaque text copied from managed home to live home. It does not need cc-switch's TOML editing surface yet. |
| SQLite wrapper / GRDB | Do not add in v1 | Overkill for a Codex-only utility with file-backed account state. |
| WebKit cookie/dashboard stack | Do not add in v1 | Codex-only usage monitoring does not require CodexBar's OpenAI web extras at launch. |

## CodexBar Reuse Policy

### Reuse directly or port with minimal changes

These are the right starting points because they already match CodeRelay's narrow job:

| CodexBar reference | Reuse recommendation | Why |
|--------------------|----------------------|-----|
| `Sources/CodexBarCore/CodexManagedAccounts.swift` | Reuse structure / port directly | The model is already narrow and aligned with CodeRelay. |
| `Sources/CodexBarCore/ManagedCodexAccountStore.swift` | Reuse pattern directly | Atomic JSON store with secure file permissions is exactly right for v1. |
| `Sources/CodexBarCore/CodexHomeScope.swift` | Reuse directly | `CODEX_HOME` scoping is foundational to managed-account isolation. |
| `Sources/CodexBar/ManagedCodexAccountService.swift` | Port and simplify | The service already handles managed-home creation, login, identity reconciliation, and cleanup. |
| `Sources/CodexBar/CodexLoginRunner.swift` | Port | This is the right pattern for running `codex login` in a scoped home. |
| `docs/codex.md` Codex probe design | Recreate selectively in `CodeRelayCodex` | The documented fallback order is already the best starting point for Codex-only monitoring. |

### Do not reuse as-is

Do **not** make CodeRelay a thin wrapper around the whole CodexBar repo or targets.

| CodexBar area | Recommendation | Why not |
|---------------|----------------|---------|
| Full `CodexBarCore` target | Do not depend on it wholesale | It pulls in multi-provider abstractions, macros, and unrelated provider logic. |
| Full `CodexBar` app target | Do not reuse directly | The menu structure, settings model, updater wiring, widgets, and provider toggles are broader than CodeRelay needs. |
| OpenAI web dashboard extras / cookie import | Exclude from v1 | Adds WebKit, browser-cookie, and keychain surface that is unnecessary for core Codex relay behavior. |
| WidgetKit, Sparkle, keyboard shortcuts, provider macros | Exclude from v1 | Nice product features, wrong first scope. |
| Cost-usage local log scanner | Exclude from v1 | Useful later, but not required for account warning/switch/resume. |

**Recommendation:** vendor or port the Codex-specific files you need into CodeRelay-owned modules. Do **not** take a package dependency on the whole CodexBar app/repo as a runtime foundation.

Confidence: **HIGH**

Reasoning:
- CodexBar is the right architectural reference.
- CodexBar is not the right dependency boundary.
- The MIT license permits selective reuse, and selective reuse keeps CodeRelay narrow.

## cc-switch Adoption Boundary

### Adopt from cc-switch

| cc-switch reference | Adopt? | How |
|---------------------|--------|-----|
| `src-tauri/src/codex_config.rs` paired live write | Yes | Copy the concept in Swift: update live `auth.json` and `config.toml` as one operation with rollback/backups. |
| `src-tauri/src/services/config.rs` backup rotation | Yes | Keep small rotating backups before switch operations. |
| Proven live-path knowledge for Codex | Yes | Honor `~/.codex/auth.json` and `~/.codex/config.toml` as the active live files. |

### Do not adopt from cc-switch

| cc-switch area | Recommendation | Why |
|----------------|----------------|-----|
| Tauri 2 + React + Rust app foundation | Reject | CodeRelay is macOS-only and needs tighter native lifecycle/process integration than a webview-first shell justifies. |
| SQLite-centered provider database | Reject | Solves cc-switch's much larger product, not CodeRelay's narrow Codex-only job. |
| Multi-provider architecture, presets, sync, MCP, prompts, skills, deep links | Reject | Product mismatch and unnecessary scope drag. |
| TOML field editing/parsing layer | Reject for v1 | CodeRelay can swap whole config files atomically without building a config editor. |
| Cross-platform tray abstraction | Reject | CodeRelay should embrace macOS-native APIs, not abstract away from them. |

**Recommendation:** use cc-switch as a **switch-engine reference**, not as a platform or app-architecture reference.

Confidence: **HIGH**

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| App shell | Native SwiftUI + AppKit | Tauri 2 + React + Rust | Too much surface area for a macOS-only utility that needs native file/process control. |
| Persistence | JSON/JSONL + managed directories | SQLite / SwiftData | v1 is too narrow to justify DB-first complexity. |
| Usage monitoring | Codex CLI app-server/RPC + PTY fallback | Web dashboard / browser-cookie scraping | Extra auth and WebKit complexity not needed for Codex-only v1. |
| Switching source of truth | Per-account managed `CODEX_HOME` directories | DB-stored auth/config blobs | Files are already the real runtime artifacts; keep them authoritative. |
| Resume strategy | CLI-first resume | Codex App restart/resume first | CLI is available and inspectable now; App behavior is follow-on validation. |
| Distribution | Developer ID direct app | Mac App Store sandboxed app | Sandbox constraints are a bad fit for `~/.codex` mutation and external process management. |

## Prescriptive Recommendation

Build CodeRelay as a **native macOS 15+ Swift app** on **Xcode 26.3+ / Swift 6.3**, with a **SwiftUI UI layer and AppKit lifecycle/status-item shell**, and split it into **CodeRelayApp / CodeRelayCore / CodeRelayCodex / CodeRelaySwitching / CodeRelayLauncher**.

Port **CodexBar's Codex-only Swift pieces** into CodeRelay-owned modules, especially the managed-account model, `CODEX_HOME` scoping, scoped login flow, and Codex CLI monitoring. Recreate **cc-switch's atomic live-file switching idea in Swift**, but do **not** adopt its Tauri foundation, React UI, Rust config-editing layer, or SQLite provider architecture.

Keep v1 narrow:
- Codex CLI is the primary restart/resume path.
- Codex App restart/resume is a later validation topic.
- No WebKit dashboard path.
- No database.
- No cross-platform abstraction.

## Confidence Assessment

| Area | Level | Notes |
|------|-------|-------|
| Native Swift vs Tauri | HIGH | Strongly supported by local reference repos and current official Tauri/Apple positioning. |
| Module split | HIGH | Directly derived from CodexBar's proven separation, but narrowed for CodeRelay. |
| Persistence choice | HIGH | Fits CodeRelay's scope better than cc-switch's DB architecture. |
| CLI restart/resume as v1 path | MEDIUM-HIGH | Codex CLI capabilities are present and locally verified; exact UX wrapper still needs implementation work. |
| Deferring Codex App restart/resume | HIGH | Matches updated user scope and keeps v1 technically disciplined. |

## Sources

### Local reference repos

- `CodeRelay/.planning/PROJECT.md`
- `CodexBar/README.md`
- `CodexBar/docs/codex.md`
- `CodexBar/docs/architecture.md`
- `CodexBar/Sources/CodexBarCore/CodexManagedAccounts.swift`
- `CodexBar/Sources/CodexBarCore/ManagedCodexAccountStore.swift`
- `CodexBar/Sources/CodexBarCore/CodexHomeScope.swift`
- `CodexBar/Sources/CodexBar/ManagedCodexAccountService.swift`
- `CodexBar/Sources/CodexBar/CodexLoginRunner.swift`
- `CodexBar/Package.swift`
- `cc-switch/README_ZH.md`
- `cc-switch/src-tauri/src/codex_config.rs`
- `cc-switch/src-tauri/src/services/config.rs`
- `cc-switch/package.json`
- `cc-switch/src-tauri/Cargo.toml`

### Local tool validation

- `codex --version` → `codex-cli 0.63.0`
- `codex --help` → confirms `resume` and `app-server` commands
- `codex resume --help` → confirms session-id and `--last` resume flow
- `codex app-server generate-json-schema --out <dir>` → confirms versioned conversation schemas including `ListConversationsResponse`, `ResumeConversationParams`, and `ResumeConversationResponse`
- Local session files under `~/.codex/sessions/...` include `session_meta` with `id` and `cwd`

### Official/current sources

- Swift.org install page: <https://www.swift.org/install/macos/>
- Apple Xcode support matrix: <https://developer.apple.com/support/xcode>
- Apple SwiftUI menu bar docs: <https://developer.apple.com/documentation/SwiftUI/Building-and-customizing-the-menu-bar-with-SwiftUI>
- Apple AppKit launch docs: <https://developer.apple.com/documentation/appkit/nsworkspace/open(_:configuration:completionhandler:)>
- Apple ServiceManagement docs: <https://developer.apple.com/documentation/servicemanagement/smappservice>
- Apple UserNotifications docs: <https://developer.apple.com/documentation/usernotifications/unusernotificationcenter>
- Apple filesystem sandbox guidance: <https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html>
- Tauri 2 overview: <https://v2.tauri.app/start/>
