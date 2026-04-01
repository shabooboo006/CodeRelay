# Phase 2: Usage Monitoring & Readiness - Research

**Researched:** 2026-04-02
**Domain:** Codex usage monitoring, freshness labeling, and alternate-account readiness in a native macOS Swift app
**Confidence:** HIGH

<user_constraints>
## User Constraints

No phase-specific `CONTEXT.md` exists for Phase 2.

Locked scope from the upstream planning inputs:
- V1 remains Codex-only, macOS-only, and CLI-first.
- Phase 2 is limited to `MON-01` through `MON-05`: active-account 5-hour and weekly usage, reset timing, refresh state, source labeling, manual refresh, and alternate-account readiness.
- Phase 2 must make switching *trustworthy*, but must not implement warnings, switching, relaunch, resume, or Codex App lifecycle behavior.
- Use CodexBar as the main reference, but port only the Codex-relevant usage pieces and simplify aggressively.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MON-01 | User can view the current 5-hour sliding-window usage for the active Codex account. | Model one primary usage window with used/remaining percent, reset timing, and source metadata. |
| MON-02 | User can view the current weekly usage for the active Codex account. | Model one secondary weekly window alongside the 5-hour window using the same normalized snapshot contract. |
| MON-03 | User can view reset timing, last refresh time, and data-source status for the active Codex account. | Persist per-account refresh metadata: `updatedAt`, `source`, `freshness`, and `error/stale` state. |
| MON-04 | User can manually refresh account usage and see stale or error states instead of silent failure. | Add an explicit refresh coordinator with cached last-known-good snapshots and visible probe failures. |
| MON-05 | User can inspect alternate managed accounts with latest known readiness state and remaining headroom or unknown status. | Project a lightweight readiness summary for every managed account, not just the active one. |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- No new dependencies without explicit request.
- Keep diffs small and package-first.
- Prefer deletion and reuse over new layers.
- Preserve the existing SwiftPM app/core/codex separation from Phase 1.
- Treat CodexBar and cc-switch as reference material, not architecture to import wholesale.

## Summary

Phase 2 should not copy CodexBar's full multi-source provider pipeline. CodeRelay only needs one trustworthy Codex path for v1 managed accounts. The cleanest plan is: define a compact usage domain in `CodeRelayCore`, implement one managed-home scoped Codex usage fetcher in `CodeRelayCodex`, persist last-known snapshots plus refresh metadata, and project those snapshots into the existing account-management surface so the user can compare the active account and alternates before Phase 3 warnings or Phase 4 switching.

CodexBar is still the right reference for two things: the normalized `RateWindow` / `UsageSnapshot` shape and the idea that source/freshness must be visible, not hidden. Its `docs/codex.md` also shows a critical simplification opportunity for CodeRelay: because CodeRelay itself manages per-account `CODEX_HOME`, it can start with the managed-home OAuth usage path and defer web dashboard scraping, CLI PTY probing, and source pickers. That keeps Phase 2 aligned with the user's "trustworthy before switching" goal without importing CodexBar's provider matrix.

cc-switch is useful only as a negative boundary: its usage scripting system proves that flexible multi-provider querying becomes configuration-heavy very quickly. CodeRelay should not introduce usage scripts, provider-defined base URLs, or user-authored probes in Phase 2. Instead, it should expose a fixed Codex-only probe pipeline and surface `unknown`, `stale`, and `error` states honestly when that pipeline cannot verify current usage.

**Primary recommendation:** Plan Phase 2 around a single Codex-only monitoring contract: managed-home scoped usage fetch, cached normalized snapshots, explicit freshness/source/error labeling, and alternate-account readiness projection. Defer secondary sources, browser scraping, and advanced forecasting.

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Xcode | `26.4` | Full macOS app toolchain | Current local baseline after toolchain repair. |
| Swift | `6.3` | Primary language and SwiftPM toolchain | Matches Xcode 26.4 and current repo build. |
| Foundation + URLSession | bundled | Usage fetch requests, JSON decode, refresh metadata, date handling | Covers Phase 2 without adding third-party networking. |
| SwiftUI + Combine / Observation | bundled | Surface active usage, refresh status, and alternate readiness in the app | Extends the existing app shell without architectural drift. |
| Swift Testing | bundled | Unit/integration tests for usage normalization, cache behavior, and feature projection | Already in use and verified locally. |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| Codex CLI managed homes | Phase 1 output | Supplies per-account `auth.json` and managed-home identity | Use as the account boundary for all probes. |
| CodexBar local reference | current repo snapshot | Source patterns for `RateWindow`, source labeling, refresh cadence, and Codex OAuth/web assumptions | Copy only Codex-specific normalization and freshness ideas. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Single managed-home Codex usage fetcher | Full CodexBar multi-source pipeline | Too much provider/source complexity for Phase 2. |
| Fixed built-in Codex probe | cc-switch-style user scripts or configurable usage endpoints | Adds configuration and safety burden before trust is established. |
| Cached snapshots + explicit stale/error states | Live-only UI that clears values on failure | Hides operational truth and makes readiness comparisons less trustworthy. |
| Core snapshot models in `CodeRelayCore` | UI-only ad hoc structs in SwiftUI feature code | Makes later warnings/switching harder to test and reuse. |

## Architecture Patterns

### Pattern 1: Normalized Usage Snapshot + Refresh Metadata

**What:** Represent usage as a small, provider-independent-for-now domain model: primary window, weekly window, source label, refreshed-at timestamp, and probe status.

**When to use:** Every read/write between fetcher, cache, feature state, and UI rows.

**Reference:** `CodexBar/Sources/CodexBarCore/UsageFetcher.swift` shows the right shape for `RateWindow` and `UsageSnapshot`.

**Recommended fields:**
```swift
struct RateWindow: Codable, Equatable, Sendable {
    let usedPercent: Double
    let windowMinutes: Int?
    let resetsAt: Date?
    let resetDescription: String?
}

struct ManagedAccountUsageSnapshot: Codable, Equatable, Sendable {
    let accountID: UUID
    let primary: RateWindow?
    let weekly: RateWindow?
    let updatedAt: Date
    let source: UsageProbeSource
    let status: UsageProbeStatus
}
```

### Pattern 2: Managed-Home Scoped Codex Usage Fetch

**What:** Fetch usage using the managed account's own `CODEX_HOME` artifacts, not ambient `~/.codex`.

**When to use:** Active-account refresh and alternate-account readiness refresh.

**Reference:** `CodexBar/docs/codex.md` documents Codex OAuth usage as the default app source when credentials are available.

**Planning implication:** For CodeRelay Phase 2, prefer one probe path first:
- read tokens from `<managed-home>/auth.json`
- call the Codex/OpenAI usage endpoint using those credentials
- normalize into 5-hour + weekly windows
- if the fetch is unavailable or unverifiable, preserve last snapshot and mark status `stale`, `error`, or `unknown`

Do not bring over:
- source pickers
- WebKit dashboard scraping
- CLI PTY fallback
- dashboard extras / credits history

### Pattern 3: Refresh Coordinator with Honest Failure States

**What:** Centralize refresh rules so manual refresh, startup refresh, and batch alternate refresh all share one state machine.

**When to use:** Any time usage is refreshed or displayed.

**Recommended states:**
```swift
enum UsageProbeStatus: String, Codable, Sendable {
    case fresh
    case stale
    case error
    case unknown
}
```

**Why:** `MON-03` and `MON-04` explicitly require that stale/error states are visible instead of silent failure. The coordinator should preserve last-known-good data and attach failure metadata rather than blanking the UI.

### Pattern 4: Alternate-Account Readiness Projection

**What:** Convert per-account snapshots into a smaller readiness view for comparisons: latest refresh state, remaining headroom, reset timing, and "unknown" when no trustworthy snapshot exists.

**When to use:** Account list rows and any future warning/switch recommendations.

**Recommended summary:**
```swift
struct AlternateAccountReadiness: Equatable, Sendable {
    let accountID: UUID
    let status: UsageProbeStatus
    let fiveHourRemainingPercent: Double?
    let weeklyRemainingPercent: Double?
    let updatedAt: Date?
}
```

### Pattern 5: Split Domain from UI Copy

**What:** Keep source/status enums and normalized values in core; render human copy only in app/UI projection code.

**When to use:** `CodeRelayCore` should own machine-truth; `CodeRelayApp` should own labels like "Last refreshed 2m ago" or "Unknown".

**Why:** Phase 3 warnings and Phase 4 switching need the underlying truth without parsing UI strings back into logic.

## Specific Guidance from References

### Copy / Simplify from CodexBar

- `CodexBar/Sources/CodexBarCore/UsageFetcher.swift`
  - reuse the idea of `RateWindow.usedPercent`, `windowMinutes`, `resetsAt`, and derived remaining percent
- `CodexBar/docs/refresh-loop.md`
  - manual refresh is always available; stale/error state must stay visible
- `CodexBar/docs/codex.md`
  - Codex usage has multiple possible sources, but the app-default happy path is credentials-backed usage fetch
- `CodexBar/Sources/CodexBarCore/Providers/ProviderFetchPlan.swift`
  - useful as a conceptual reference for ordered fetch strategies and explicit attempt metadata, but CodeRelay should implement a much smaller Codex-only version

### Do Not Import from CodexBar

- multi-provider source modes (`auto`, `web`, `cli`, `oauth`, `api`)
- WebKit cookie management and browser cookie import
- credits / cost history / tertiary windows
- provider toggles, provider registries, or generic fetch pipelines

### Negative Boundary from cc-switch

Do not adopt:
- usage script editors
- provider-specific usage URLs
- API key overrides for usage queries
- multi-provider settings panels

Phase 2 should stay built-in and opinionated.

## Recommended Plan Split

### 02-01: Usage domain, cache, and readiness projection
- Add Phase 2 core models for usage windows, probe source/status, cached snapshots, and alternate readiness summaries.
- Persist snapshots in a lightweight file-backed cache owned by CodeRelay.
- Cover snapshot normalization and stale/error semantics with unit tests.

### 02-02: Codex usage probing and refresh coordination
- Implement the managed-home scoped usage fetcher in `CodeRelayCodex`.
- Add a refresh coordinator that updates active + alternate snapshots and records source/failure metadata.
- Cover success, unavailable credentials, stale fallback, and error propagation with tests.

### 02-03: App integration and manual refresh surface
- Extend the Phase 1 account-management feature/view to show active 5-hour + weekly usage, refresh timestamps, source labels, and alternate readiness.
- Add a manual refresh action and visible stale/error states.
- Keep Phase 2 UI inside the existing account-management/settings surface; do not add warning thresholds or switch controls yet.

## Anti-Patterns to Avoid

- **Importing CodexBar's full fetch pipeline:** CodeRelay does not need provider registries or source pickers in Phase 2.
- **Fetching on row render:** network/probe work should happen in a coordinator, not directly inside SwiftUI view rendering.
- **Erasing last-known-good data on failure:** stale snapshots are more useful than empty UI.
- **Making alternate readiness depend on perfect freshness:** if alternates are stale or unknown, show that explicitly rather than pretending they are ready.
- **Binding Phase 2 to Codex App or resume logic:** those belong to later phases.

## Common Pitfalls

### Pitfall 1: Treating every successful fetch as equally trustworthy

**What goes wrong:** Later phases switch based on data that may be stale, partial, or from a weak fallback path.

**How to avoid:** Every snapshot needs both `source` and `status`.

### Pitfall 2: Refreshing only the active account

**What goes wrong:** Alternate-account readiness becomes permanently `unknown`, which blocks the user's later switch decision.

**How to avoid:** The refresh coordinator should support a batched refresh policy across all managed accounts, even if alternates are refreshed sequentially.

### Pitfall 3: Reaching for browser/dashboard scraping too early

**What goes wrong:** Phase 2 balloons into cookies, WKWebView lifecycle, and anti-automation edge cases.

**How to avoid:** Start with the managed-home credentials-backed path and a seam for future secondary sources.

### Pitfall 4: Mixing machine truth with user copy

**What goes wrong:** Phase 3 warnings and Phase 4 switching have to reverse-engineer strings like "Almost full".

**How to avoid:** Keep percentages, reset dates, source, and status as typed values through the domain and projection layers.

## Validation Architecture

Phase 2 can reuse the existing SwiftPM + Swift Testing infrastructure. No Wave 0 tooling work is needed. The important validation shift is that tests must cover both successful usage normalization and degraded states:

- managed-home scoped snapshot decode/normalize
- stale fallback when refresh fails after a last-known-good snapshot exists
- `unknown` readiness when an account has never been refreshed successfully
- app-feature projection of refresh timestamps, source labels, and manual refresh state

The fast loop should stay `swift test --filter Phase2`. The full loop remains `swift test`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Generic provider framework | Provider registries and source pickers | Codex-only services and typed snapshots | The product scope is intentionally narrow. |
| User-scripted usage fetch | Editable JS or shell probe scripts | Fixed managed-home Codex usage fetcher | Better trust and fewer support paths. |
| UI-only refresh logic | Ad hoc `Task {}` probes inside views | Central refresh coordinator | Keeps stale/error semantics consistent. |
| In-memory-only snapshots | Volatile state that disappears on relaunch | File-backed usage snapshot cache | Needed for alternate readiness and last refresh visibility. |

