# Phase 1: Managed Account Foundation - Research

**Researched:** 2026-04-01
**Domain:** Codex-managed account enrollment, storage, identity, and active-account control in a native macOS Swift app
**Confidence:** HIGH

<user_constraints>
## User Constraints

No phase-specific `CONTEXT.md` exists for Phase 1.

Locked scope from the upstream planning inputs:
- V1 is Codex-only and CLI-first.
- Codex App close/relaunch/resume is deferred and must not shape Phase 1.
- Phase 1 is limited to `ACCT-01` through `ACCT-06`: add, list, select active, re-authenticate, remove, and show unsupported or unverified switching state for managed Codex accounts.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ACCT-01 | User can add a managed Codex account through a scoped login flow that stores it separately from other managed accounts. | Use a dedicated managed `CODEX_HOME` per account, run `codex login` inside that scope, and force file-backed credential storage during managed enrollment. |
| ACCT-02 | User can view all managed Codex accounts with account email, last authentication time, and active/live status. | Persist a versioned JSON registry, parse file-backed identity from `auth.json`, and reconcile that registry with a separately observed ambient live account projection. |
| ACCT-03 | User can choose which managed Codex account CodeRelay should treat as the active account. | Persist selected managed account separately from the observed live account and resolve drift through a centralized reconciler. |
| ACCT-04 | User can re-authenticate an existing managed Codex account without creating a duplicate account entry. | Match re-auth by stable account id first and by normalized identity envelope second; replace the managed home only after the new login is verified. |
| ACCT-05 | User can remove a managed Codex account that is no longer needed. | Keep account deletion root-scoped and safe, remove only validated managed-home directories, and never allow arbitrary path deletion. |
| ACCT-06 | User can see when a managed Codex account cannot support reliable one-click switching because its credential storage mode is unsupported or unverified. | Model `switchSupport` explicitly from `cli_auth_credentials_store`, file presence, and identity verification. Treat `keyring` as unsupported and `auto` without verified file-backed storage as unverified. |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- Build for macOS desktop first.
- Keep the product Codex-only in v1.
- Do not add new dependencies without explicit request.
- Use CodexBar as a reference, but port only Codex-relevant pieces; do not adopt the full app wholesale.
- Keep account changes explicit and user-confirmed; do not design silent switching.
- Preserve or restore the prior Codex session where possible, but do not let that later continuity work distort Phase 1.
- Deliver the Codex CLI path before any Codex App lifecycle automation.
- Keep implementation inside the GSD workflow; Phase 1 planning should assume normal GSD execution rather than ad hoc repo edits.

## Summary

Phase 1 should establish a file-backed managed-account subsystem, not a generic account abstraction. The stable foundation is: one managed `CODEX_HOME` directory per account under Application Support, one versioned JSON registry that indexes those homes, and one reconciler that merges "managed account selected by CodeRelay" with "live account currently observed in ambient Codex." This matches the narrow Codex-only scope, ports the right CodexBar ideas, and avoids importing its broader provider surface.

The main planning risk is credential storage mode. Current OpenAI docs state that Codex CLI credentials may be stored in `file`, `keyring`, or `auto`, and that the CLI and IDE extension share cached login details. That means file-path isolation cannot be assumed. Phase 1 therefore needs a first-class switch-support classifier and must not mark every managed account as future switch-safe. The simplest way to avoid later rework is to force file-backed storage for accounts that CodeRelay itself enrolls, then classify everything else honestly.

App-server support exists locally and in CodexBar, but it is still documented as experimental. For Phase 1, do not make `app-server` the hard dependency for managed-account identity. Use `codex login`, `codex login status`, scoped `CODEX_HOME`, and file-backed `auth.json` parsing as the primary contract. Use `account/read` only as an enhancement for observing ambient live identity when file-backed metadata is absent. This keeps Phase 1 robust even though the local machine currently has `codex-cli 0.63.0` while npm stable is `0.118.0`.

**Primary recommendation:** Plan Phase 1 around `CODEX_HOME`-scoped, file-backed managed enrollment via `codex login -c cli_auth_credentials_store="file"`, a versioned JSON registry plus managed-home directories, and an explicit `switchSupport` classifier that treats `keyring` as unsupported and `auto` without verified file-backed storage as unverified.

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Xcode | `26.4` | Full macOS app toolchain for SwiftUI/AppKit targets | Current Apple support matrix pairs `Xcode 26.4` with `Swift 6.3`; this is the current stable baseline for a new macOS app. |
| Swift | `6.3` | Primary language and SwiftPM package toolchain | Current compiler paired with `Xcode 26.4`; matches the strict-concurrency direction already proven in CodexBar. |
| SwiftUI + AppKit | bundled with Xcode 26.4 | Minimal Phase 1 account-management surface plus native app shell | Fits macOS-first scope and future menu-bar/status-item direction without introducing web or cross-platform layers. |
| Foundation + Observation | bundled with Xcode 26.4 | Filesystem access, `Process`, JSON persistence, app/domain state | Covers the Phase 1 needs with no third-party runtime dependency. |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| Codex CLI | `0.118.0` current stable on npm; local machine currently `0.63.0` | Managed login, login status checks, future live identity probing, and later resume/switch integration | Required for real account enrollment and runtime validation. Implement feature detection because local installs may lag the latest stable. |
| Swift Testing | bundled with Xcode 16+ / Swift toolchain | Unit and package-level tests for stores, reconcilers, and classifiers | Use for new Phase 1 domain tests. It integrates with SwiftPM and supports concurrency-aware tests. |
| XCTest | bundled with Xcode | UI tests and any future app/performance tests | Keep only for app/UI test cases that Swift Testing does not replace. |
| OSLog | bundled with Apple platforms | Redacted diagnostics and failure reporting | Use instead of ad hoc console logging so auth material stays out of logs. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| File-backed managed `CODEX_HOME` + JSON registry | SwiftData / SQLite | Unnecessary schema and migration complexity for a phase whose true source of truth is already the filesystem. |
| `codex login` wrapper | Custom OAuth or browser automation | Reinvents auth, bypasses official MFA and workspace restrictions, and creates brittle maintenance work. |
| Native SwiftUI + AppKit | Tauri / React / Rust | Overkill for a macOS-only utility whose core work is local file/process orchestration. |
| Swift Testing for new unit tests | XCTest everywhere | Works, but is a less current default for new Swift package tests. Keep XCTest only where it still adds value. |

**Installation:**
```bash
# Required for app-target work
xcode-select --switch /Applications/Xcode.app

# Recommended Codex CLI baseline for parity with current docs
npm install -g @openai/codex@0.118.0
```

**Version verification:**
- Apple support matrix checked on 2026-04-01: `Xcode 26.4` bundles `Swift 6.3`; `Xcode 26.3` bundles `Swift 6.2.3`.
- `npm view @openai/codex version time --json` checked on 2026-04-01: latest stable is `0.118.0`, published `2026-03-31T17:03:18.490Z`.
- Local machine audit on 2026-04-01: `swift 6.2.3`, `codex-cli 0.63.0`, no full Xcode selected via `xcode-select`.

## Architecture Patterns

### Recommended Project Structure

```text
Package.swift                    # Core packages + test targets
App/
└── CodeRelayApp/                # Xcode app target source root
Sources/
├── CodeRelayCore/               # Account models, registry, selection, support classifier
├── CodeRelayCodex/              # CODEX_HOME scoping, login runner, auth inspection
└── CodeRelayAccountsFeature/    # View models / projection logic for Phase 1 account UI
Tests/
├── CodeRelayCoreTests/
├── CodeRelayCodexTests/
└── CodeRelayAccountsFeatureTests/
```

Recommended rule: keep the Phase 1 UI shell thin. Put almost all behavior in package targets so it can be tested with `swift test` before the app target exists.

### Pattern 1: File-Backed Managed Enrollment

**What:** Every managed account gets its own managed-home directory. Enrollment runs `codex login` with `CODEX_HOME=<managedHome>` and a config override that forces file-backed credential storage.

**When to use:** Add-account flow and re-authentication flow.

**Example:**
```swift
var env = ProcessInfo.processInfo.environment
env["CODEX_HOME"] = managedHome.path

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
process.arguments = [
    "codex",
    "-c", #"cli_auth_credentials_store="file""#,
    "login",
]
process.environment = env
```
Source: OpenAI auth docs (`cli_auth_credentials_store`, `CODEX_HOME`) and local `codex login --help`.

Why this matters:
- OpenAI docs say credentials may live in `file`, `keyring`, or `auto`.
- File-backed storage is the only mode that aligns cleanly with managed-home isolation and future live-file switching.
- Local validation confirmed `CODEX_HOME=$(mktemp -d) codex login status` returns `Not logged in`, so `CODEX_HOME` scoping is real, not theoretical.

### Pattern 2: Versioned JSON Registry + Managed Home Directories

**What:** Store account records in one versioned JSON file and keep per-account runtime artifacts in sibling managed-home directories.

**When to use:** Every create, update, remove, and launch-time load of managed accounts.

**Example:**
```swift
struct ManagedAccount: Codable, Identifiable, Sendable {
    let id: UUID
    let email: String
    let managedHomePath: String
    let createdAt: TimeInterval
    let updatedAt: TimeInterval
    let lastAuthenticatedAt: TimeInterval?
    let credentialStore: CredentialStoreMode
    let switchSupport: SwitchSupport
}
```
Source: `../CodexBar/Sources/CodexBarCore/CodexManagedAccounts.swift` and `../CodexBar/Sources/CodexBarCore/ManagedCodexAccountStore.swift`.

Required additions beyond CodexBar:
- Persist `credentialStore`.
- Persist `switchSupport`.
- Leave room for optional workspace or auth-mode metadata.

### Pattern 3: Reconciled Visible-Account Projection

**What:** Keep "selected managed account" and "ambient live account" as separate inputs, then project them into user-visible rows with `isActive`, `isLive`, and `switchSupport`.

**When to use:** App launch, account list refresh, selection changes, and after add/remove/re-auth.

**Example:**
```swift
struct VisibleAccount: Equatable, Sendable, Identifiable {
    let id: String
    let email: String
    let storedAccountID: UUID?
    let isActive: Bool
    let isLive: Bool
    let switchSupport: SwitchSupport
}
```
Source: `../CodexBar/Sources/CodexBar/CodexAccountReconciliation.swift`.

Planning implication:
- `ACCT-03` is not "rewrite ambient Codex immediately." It is "remember which managed account CodeRelay should treat as active."
- Drift must be visible, not hidden.

### Pattern 4: Explicit Switch-Support Classification

**What:** Classify every managed account as `supported`, `unsupported`, or `unverified` for future one-click switching.

**When to use:** Immediately after add/re-auth, when rendering the account list, and during future switch preflight.

**Recommended logic:**
```swift
enum SwitchSupport: String, Codable, Sendable {
    case supported
    case unsupported
    case unverified
}

func classify(store: CredentialStoreMode, authFileExists: Bool, identityVerified: Bool) -> SwitchSupport {
    switch store {
    case .file:
        return authFileExists && identityVerified ? .supported : .unverified
    case .keyring:
        return .unsupported
    case .auto:
        return authFileExists && identityVerified ? .supported : .unverified
    }
}
```
Source: OpenAI auth/config docs plus local CodexBar limitation that only file-backed `auth.json` is readable today.

### Anti-Patterns to Avoid

- **Email-only deduplication:** The local CodexBar model dedupes by normalized email. For CodeRelay Phase 1, email is necessary but not sufficient; keep room for auth mode, store mode, and optional workspace metadata.
- **Delete-old-home-on-successful-reauth:** CodexBar removes the previous managed home immediately. For Phase 1, quarantine the old home until the new identity is verified and the registry write succeeds.
- **Assume `auto` means file-backed:** It does not. On macOS, `auto` may resolve to OS credential storage and break managed-home isolation.
- **Depend on app-server for Phase 1 correctness:** It is useful, but still documented as experimental. Keep it as a capability-probed enhancement.
- **Make Phase 1 depend on Codex App lifecycle or menu-bar polish:** Those are later phases. Phase 1 needs a basic account-management surface, not the final UX shell.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| ChatGPT/API-key auth | Custom OAuth callback flow or browser automation | `codex login`, `codex login --device-auth`, and `codex login --with-api-key` | Official flows already handle auth, MFA, and workspace restrictions. |
| Account persistence | Database-backed provider catalog | Versioned JSON registry plus managed-home directories | The filesystem already holds the true runtime artifacts; Phase 1 does not need a DB. |
| Active/live status logic | Ad hoc UI conditionals | Central `AccountReconciler` projection | Prevents drift between storage, selection, and the UI. |
| Credential storage inference | Guess from file presence alone | Persist effective `cli_auth_credentials_store` and verify `auth.json` existence + identity | `keyring` and `auto` need explicit classification. |
| Secure file writes | Raw `FileManager` overwrite calls | Atomic writes plus secure permissions | Prevents partial writes and reduces auth leak risk. |
| Account deletion | Recursive delete of arbitrary paths | Root-validated managed-home deletion or quarantine | Avoids destructive filesystem mistakes. |

**Key insight:** The filesystem is already the runtime source of truth. The registry should index managed homes and annotate their safety, not replace them with a second account database.

## Common Pitfalls

### Pitfall 1: Treating `keyring` or unresolved `auto` accounts as future switch-safe

**What goes wrong:** The UI marks an account as normal because login succeeded, but the account cannot later be switched by file swap because its credentials are not actually stored under the managed home.

**Why it happens:** Current OpenAI docs allow credentials in `file`, `keyring`, or `auto`. Only `file` is straightforwardly namespaced by `CODEX_HOME`.

**How to avoid:** Force `cli_auth_credentials_store="file"` during managed enrollment. Persist the observed mode. Mark `keyring` as unsupported and `auto` without verified `auth.json` as unverified.

**Warning signs:** `codex login status` succeeds in a managed home but `auth.json` is missing; ambient login survives even after the managed home is moved.

### Pitfall 2: Using email as the only identity key

**What goes wrong:** Re-auth updates the wrong account or merges two distinct account contexts into one visible row.

**Why it happens:** The reference code normalizes mainly by email because that is enough for CodexBar’s simpler presentation.

**How to avoid:** Store a richer identity envelope: normalized email, credential store mode, auth method, managed-home path, and optional workspace restriction metadata.

**Warning signs:** Duplicate or conflicting rows for the same email, or one row changing storage mode unexpectedly after re-authentication.

### Pitfall 3: Deleting the old managed home too early during re-authentication

**What goes wrong:** A bad re-auth destroys the only known-good account copy.

**Why it happens:** The simplest service implementation updates the registry, then deletes the previous directory immediately.

**How to avoid:** Quarantine replaced homes until the new login is verified and the registry write is durable.

**Warning signs:** Re-auth feels irreversible, and a failed re-auth leaves the user with no working copy of the account.

### Pitfall 4: Leaking tokens or cache material through logs and diagnostics

**What goes wrong:** `auth.json` contents or raw CLI output end up in logs, support artifacts, or event files.

**Why it happens:** Phase 1 touches login, file storage, and error reporting before a redaction policy exists.

**How to avoid:** Treat `auth.json` like a password, redact paths and tokens in logs, and never serialize raw credential blobs into audit files.

**Warning signs:** Debug logs contain bearer tokens, copied auth files, or raw JSON dumps from managed homes.

### Pitfall 5: Planning Phase 1 around later switch or app-lifecycle work

**What goes wrong:** Account foundation gets blocked on menu-bar polish, terminal relaunch mechanics, or Codex App automation.

**Why it happens:** Those later phases are user-visible and tempting to front-load.

**How to avoid:** Keep Phase 1 to enrollment, storage, identity, selection, and safety labeling. Anything that closes apps or rewrites ambient live config belongs later.

**Warning signs:** Phase 1 design starts depending on process control, resume logic, or status-item behavior.

## Code Examples

Verified patterns from official sources and local first-party references:

### Scoped Managed Login

```swift
func makeManagedLoginEnvironment(homePath: String) -> [String: String] {
    var env = ProcessInfo.processInfo.environment
    env["CODEX_HOME"] = homePath
    return env
}
```
Source: `../CodexBar/Sources/CodexBarCore/CodexHomeScope.swift` and OpenAI auth docs on file-backed `CODEX_HOME`.

### Atomic JSON Store With Secure Permissions

```swift
func storeAccounts(_ snapshot: ManagedAccountSet, to fileURL: URL) throws {
    let data = try JSONEncoder().encode(snapshot)
    try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true)
    try data.write(to: fileURL, options: [.atomic])
    try FileManager.default.setAttributes(
        [.posixPermissions: NSNumber(value: Int16(0o600))],
        ofItemAtPath: fileURL.path)
}
```
Source: `../CodexBar/Sources/CodexBarCore/ManagedCodexAccountStore.swift`.

### Safe Live-Status Probe Without Reading Secrets

```swift
func isLoggedIn(homePath: String) async throws -> Bool {
    var env = ProcessInfo.processInfo.environment
    env["CODEX_HOME"] = homePath
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["codex", "login", "status"]
    process.environment = env
    try process.run()
    process.waitUntilExit()
    return process.terminationStatus == 0
}
```
Source: OpenAI CLI reference (`codex login status`) and local runtime verification.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Assume Codex auth always lives in `~/.codex/auth.json` | Codex now supports `file`, `keyring`, or `auto` credential storage via `cli_auth_credentials_store` | Documented in current OpenAI auth/config docs as of 2026-04-01 | Phase 1 must classify switch support instead of assuming file access. |
| Browser-only ChatGPT login | Browser OAuth, device-auth, and API-key login are all supported | Documented in current OpenAI auth/CLI docs as of 2026-04-01 | Use the CLI as the auth surface; do not build custom login UX. |
| XCTest as the default for all new tests | Swift Testing is the current recommendation for new unit tests; XCTest remains relevant for UI/performance tests | Xcode 16+ per Apple docs | Use Swift Testing for Phase 1 package tests and keep XCTest reserved for later app/UI coverage. |

**Deprecated/outdated:**
- Treating the local `auth.json` file as the only Codex auth source is outdated.
- Planning against `Xcode 26.3 == Swift 6.3` is outdated; the current Apple matrix shows `Xcode 26.4 == Swift 6.3`, while `Xcode 26.3 == Swift 6.2.3`.

## Open Questions

1. **Should CodeRelay hard-force file storage during managed enrollment, or only warn when it is absent?**
   - What we know: `codex login` accepts `-c` overrides, and official docs support `cli_auth_credentials_store = "file"`.
   - What's unclear: whether any current Codex release or enterprise policy blocks that override during normal local login.
   - Recommendation: treat "force file storage for managed accounts" as the default plan and add a Wave 0 contract test against the local Codex CLI.

2. **How much ambient live identity should Phase 1 derive from experimental app-server versus file-backed auth parsing?**
   - What we know: local app-server schemas and CodexBar use `account/read`, but official CLI docs still mark app-server as experimental.
   - What's unclear: how stable the response shape will remain across Codex CLI releases.
   - Recommendation: plan app-server as an optional enhancement for ambient live identity only. Managed-account correctness should not depend on it.

3. **Is workspace identifier available from current local identity surfaces, or only from enforced config?**
   - What we know: OpenAI docs expose `forced_chatgpt_workspace_id`, but the local quick identity pattern centers on email and JWT claims.
   - What's unclear: whether workspace id is consistently available from `auth.json` claims or `account/read` in the currently installed CLI.
   - Recommendation: make workspace metadata optional in Phase 1 storage and do not block the phase on it.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Full Xcode app toolchain | SwiftUI/AppKit app target, macOS app testing | ✗ | — | Core/package work can begin with the installed Swift CLI, but app-target work is blocked until full Xcode is installed and selected. |
| Swift CLI / SwiftPM | Core packages and unit tests | ✓ | `6.2.3` | Upgrade alongside Xcode when app-target work starts. |
| Codex CLI | Managed login, scoped auth checks, future live identity probing | ✓ | installed `0.63.0`; latest stable `0.118.0` | Implement capability detection; upgrade recommended for parity with current docs. |
| macOS system CLIs (`osascript`, `security`, `defaults`, `plutil`) | Native diagnostics and later lifecycle integration | ✓ | system | — |
| Node / npm | Codex CLI package upgrades and CLI tooling | ✓ | `v22.22.0` / `10.9.4` | — |

**Missing dependencies with no fallback:**
- Full Xcode app toolchain. Without it, the app target cannot be built or tested on this machine.

**Missing dependencies with fallback:**
- Current Codex CLI stable (`0.118.0`) is not installed. Fallback is to code with runtime capability checks against the installed `0.63.0`, but parity with current docs is weaker.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing for new unit/package tests; XCTest only for any later app/UI tests |
| Config file | none yet — see Wave 0 |
| Quick run command | `swift test --filter ManagedAccount` |
| Full suite command | `swift test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ACCT-01 | Scoped add-account flow creates a managed home and distinct registry entry | integration | `swift test --filter ManagedAccountServiceTests.testAddAccountCreatesScopedManagedHome` | ❌ Wave 0 |
| ACCT-02 | Account list shows email, last auth time, active flag, live flag, and switch support | unit | `swift test --filter AccountProjectionTests.testProjectsVisibleAccountState` | ❌ Wave 0 |
| ACCT-03 | Selecting an active managed account persists the selection and repairs drift on reload | unit | `swift test --filter ActiveAccountSelectionTests.testPersistsAndResolvesActiveSelection` | ❌ Wave 0 |
| ACCT-04 | Re-auth updates an existing record instead of creating a duplicate | integration | `swift test --filter ManagedAccountServiceTests.testReauthReusesExistingAccountRecord` | ❌ Wave 0 |
| ACCT-05 | Remove deletes the registry entry and only removes a validated managed-home path | integration | `swift test --filter ManagedAccountServiceTests.testRemoveDeletesValidatedManagedHome` | ❌ Wave 0 |
| ACCT-06 | Switch support is classified correctly for `file`, `keyring`, and unresolved `auto` | unit | `swift test --filter SwitchSupportClassifierTests.testClassifiesCredentialStoreModes` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `swift test --filter ManagedAccount`
- **Per wave merge:** `swift test`
- **Phase gate:** Full Phase 1 package tests green plus one manual smoke of add/select/remove in the minimal app surface before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `Package.swift` — define package products, targets, and test targets
- [ ] `Tests/CodeRelayCoreTests/ManagedAccountServiceTests.swift` — covers ACCT-01, ACCT-04, ACCT-05
- [ ] `Tests/CodeRelayCoreTests/AccountProjectionTests.swift` — covers ACCT-02, ACCT-03
- [ ] `Tests/CodeRelayCodexTests/SwitchSupportClassifierTests.swift` — covers ACCT-06
- [ ] `Tests/Shared/TemporaryManagedHomeFixture.swift` — shared temp-home and fake login runner fixtures
- [ ] App-target smoke harness — minimal account-management screen or window for manual Phase 1 verification once Xcode is installed

## Sources

### Primary (HIGH confidence)

- OpenAI Codex Authentication docs: <https://developers.openai.com/codex/auth>
  - Checked login caching, `cli_auth_credentials_store`, file vs keyring vs auto, device auth, workspace/login restrictions, and shared CLI/IDE credential cache behavior.
- OpenAI Codex Config Reference: <https://developers.openai.com/codex/config-reference>
  - Checked `cli_auth_credentials_store`, `forced_login_method`, and `forced_chatgpt_workspace_id`.
- OpenAI Codex CLI Reference: <https://developers.openai.com/codex/cli/reference>
  - Checked `codex login`, `codex login status`, `codex logout`, `codex resume`, `codex app-server`, and `codex app`.
- Apple Xcode support matrix: <https://developer.apple.com/support/xcode>
  - Verified `Xcode 26.4 -> Swift 6.3` and `Xcode 26.3 -> Swift 6.2.3`.
- Apple Swift Testing docs: <https://developer.apple.com/documentation/testing>
  - Verified Swift Testing as the modern package/unit-test framework.
- Apple XCTest docs: <https://developer.apple.com/documentation/xctest/>
  - Verified that Swift Testing is preferred for new unit tests in Xcode 16+ while XCTest remains relevant for UI/performance tests.
- Local runtime evidence collected on 2026-04-01:
  - `swift --version` -> `Apple Swift version 6.2.3`
  - `codex --version` -> `codex-cli 0.63.0`
  - `codex login status` -> `Logged in using ChatGPT`
  - `CODEX_HOME=$(mktemp -d) codex login status` -> `Not logged in`
  - `codex --help`, `codex login --help`, `codex resume --help`, `codex app-server --help`
  - `codex app-server generate-json-schema --out <tmp>` -> confirms local schemas for `ListConversations`, `ResumeConversation`, `account/read`, and `account/rateLimits/read`
  - `npm view @openai/codex version time --json` -> latest stable `0.118.0`, published `2026-03-31`
- Local reference code and project research:
  - `../CodexBar/Sources/CodexBarCore/CodexManagedAccounts.swift`
  - `../CodexBar/Sources/CodexBarCore/ManagedCodexAccountStore.swift`
  - `../CodexBar/Sources/CodexBarCore/CodexHomeScope.swift`
  - `../CodexBar/Sources/CodexBar/ManagedCodexAccountService.swift`
  - `../CodexBar/Sources/CodexBar/CodexAccountReconciliation.swift`
  - `../CodexBar/Sources/CodexBarCore/UsageFetcher.swift`
  - `../cc-switch/src-tauri/src/codex_config.rs`
  - `../cc-switch/src-tauri/src/services/config.rs`
  - `.planning/research/SUMMARY.md`
  - `.planning/research/STACK.md`
  - `.planning/research/ARCHITECTURE.md`
  - `.planning/research/PITFALLS.md`

### Secondary (MEDIUM confidence)

- Apple Swift Testing product page: <https://developer.apple.com/xcode/swift-testing/>
  - Used only as supporting confirmation that Swift Testing is the intended modern workflow across Xcode and SwiftPM.

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - official Apple support docs, local CodexBar package choices, and a direct machine audit agree.
- Architecture: HIGH - local reference code, official Codex auth/config docs, and local `CODEX_HOME` behavior all support the recommended split.
- Pitfalls: HIGH - the major Phase 1 risks are directly supported by current OpenAI credential-storage docs plus the observed limitations of the current local reference code.

**Research date:** 2026-04-01
**Valid until:** 2026-04-08
