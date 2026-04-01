# Domain Pitfalls

**Domain:** macOS Codex account relay for Codex CLI continuity
**Researched:** 2026-04-01
**Overall confidence:** HIGH for auth, storage, and CLI resume semantics; MEDIUM for resumed transcript fidelity and release-to-release resume stability

V1 assumption: CodeRelay should optimize for Codex CLI switching and best-effort CLI conversation continuity. Codex App close/relaunch/resume automation is a later validation track, not a v1 blocker.

## Critical Pitfalls

### Pitfall 1: Treating Codex usage like a fixed message counter
**What goes wrong:** CodeRelay shows usage as "messages left" or triggers switching as if a percentage maps cleanly to a fixed number of prompts. Official OpenAI guidance says Codex consumption varies with task size, context length, long-running tasks, and where the task executes. A user can still hit a limit earlier than the UI implied, which destroys trust fast.
**Early warning signs:** Users hit rate limits while the app still shows "safe" remaining usage; the web dashboard and CLI disagree; users ask why a warning fired too late or too early.
**Prevention strategy:** Model usage as windows plus confidence, not as exact remaining prompts. Show source, timestamp, and "estimate" language. Warn at thresholds, but never silently auto-switch based only on a percentage. Prefer one authoritative primary source per account state, with other sources clearly labeled as supplemental.
**Phase should address it:** Phase 2 - Usage Monitoring Engine
**Confidence:** HIGH

### Pitfall 2: Switching only `auth.json` and ignoring credential-store mode
**What goes wrong:** CodeRelay assumes each managed account lives entirely under a managed `CODEX_HOME`, but Codex can store credentials in `auth.json`, the OS keychain, or `auto`. In that case the app may "switch" files while the live CLI still resolves credentials from shared cached login state, or a logout in one surface invalidates another.
**Early warning signs:** After a switch, `codex` still reports the previous account; managed accounts work on one machine but not another; switching behavior changes depending on whether the user previously logged in through the CLI or IDE extension.
**Prevention strategy:** Detect `cli_auth_credentials_store` up front. For v1, either require file-backed credentials for managed-account isolation or explicitly mark keychain-backed setups as unsupported for one-click switching. Surface that the CLI and IDE extension share cached login details. Validate the active identity after every switch instead of assuming the file write was enough.
**Phase should address it:** Phase 1 - Account Security and Storage Foundations
**Confidence:** HIGH

### Pitfall 3: Using email alone as the account identity key
**What goes wrong:** The reference reconciliation logic normalizes and matches mostly by email. That is not always sufficient. The same email can correspond to different ChatGPT workspaces, different admin restrictions, or a different auth mode entirely. CodeRelay can show the wrong account as "equivalent" and attach the wrong usage or switching behavior to it.
**Early warning signs:** One email appears multiple times with confusing behavior; a switch succeeds but the user lands in the wrong workspace or loses features; same-email accounts have different limits or policies.
**Prevention strategy:** Store a richer identity envelope per managed account: normalized email, auth mode, credential storage mode, workspace identifier when available, managed home path, and last validated source. Only merge records when the whole identity envelope matches, not just the email.
**Phase should address it:** Phase 1 - Account Security and Storage Foundations
**Confidence:** HIGH

### Pitfall 4: Failing open when browser-derived usage belongs to a different account
**What goes wrong:** Browser cookie import or a manual cookie header can make CodeRelay display usage for the wrong ChatGPT session after an account switch. The CodexBar reference already guards against this because it is one of the easiest ways to lose user trust: the app looks confident while describing somebody else's dashboard state.
**Early warning signs:** The dashboard email does not match the selected managed account; usage suddenly jumps backward or forward after a switch; manual cookie mode "works" for one account and quietly mislabels the next one.
**Prevention strategy:** Keep per-account web stores, require signed-in email verification before applying dashboard data, fail closed on mismatch, and treat manual cookie headers as a global override with a strong warning. Never silently reuse the previous dashboard snapshot for a newly selected account.
**Phase should address it:** Phase 2 - Usage Monitoring Engine
**Confidence:** HIGH

### Pitfall 5: Letting stale refresh tasks overwrite the newly selected account
**What goes wrong:** Usage polling is asynchronous. If account A is active, then the user switches to account B while A's refresh is still in flight, the late A result can overwrite B's state. The user sees the right account selected but the wrong usage, warnings, or dashboard snapshot.
**Early warning signs:** UI flips briefly to the new account and then shows old values; warnings reference a different account than the one marked active; bugs are hard to reproduce and show up mostly during fast manual switching.
**Prevention strategy:** Bind every refresh task to an account-scoped guard and a switch token. Cancel or invalidate all in-flight work at switch time. Apply results only if the account key and switch token still match the active session. Do this for every data source, not just the web dashboard path.
**Phase should address it:** Phase 2 - Usage Monitoring Engine
**Confidence:** HIGH

### Pitfall 6: Restart logic that cannot prove which Codex CLI session it is stopping
**What goes wrong:** A developer may have multiple Codex CLI sessions open across different repos or terminals. If CodeRelay kills processes by name or by a loose heuristic, it can terminate unrelated work and still fail to restart the intended conversation.
**Early warning signs:** "Wrong terminal got closed" reports; the active repo path in the resumed session does not match the repo the user was working in; switch success is inconsistent when several sessions are open.
**Prevention strategy:** Treat process targeting as a first-class switching primitive. Capture PID, repo path, working directory, and session ID before shutdown. Only offer one-click restart when CodeRelay can identify the intended CLI instance with high confidence. Otherwise degrade to a guided handoff instead of guessing.
**Phase should address it:** Phase 3 - CLI Switching Orchestrator
**Confidence:** MEDIUM

### Pitfall 7: Non-transactional CLI switching that leaves the user stranded mid-handoff
**What goes wrong:** Writing the new live auth/config, shutting down the current CLI, and relaunching the target account are a single user-visible operation, but they often fail in separate steps. If CodeRelay treats them as unrelated actions, the user can end up with the old session gone, the new account only partially applied, and no obvious rollback path.
**Early warning signs:** After a failed switch the live config is in a mixed state; the relaunched CLI authenticates as the wrong account; users need manual repair in `~/.codex` to recover.
**Prevention strategy:** Build the switch as a journaled transaction: snapshot current live state, write auth and config atomically, verify the target identity in the target context, then perform shutdown and relaunch. If any stage fails, restore the previous live state and present a clear recovery banner. Prefer the atomic write path proven in `cc-switch`; do not use ad hoc direct file writes for the live switch.
**Phase should address it:** Phase 3 - CLI Switching Orchestrator
**Confidence:** HIGH

### Pitfall 8: Using `codex resume --last` when CodeRelay could have used an explicit session ID
**What goes wrong:** Official CLI docs say `codex resume --last` is scoped to the current working directory unless `--all` is used. That is safer than older global behavior, but it is still not the same as resuming the exact interrupted session. In a worktree-heavy workflow, "most recent in this directory" can still be the wrong conversation.
**Early warning signs:** Resume reopens the wrong thread after a switch; the resumed conversation exists but does not contain the expected recent context; the user has to manually pick from the session list after a supposedly one-click flow.
**Prevention strategy:** Capture and persist the explicit session ID before shutdown, then resume by ID. Use `--last` only as a fallback path and say so in the UI. Persist repo path, branch/worktree label, and session timestamp alongside the session ID so recovery can stay deterministic.
**Phase should address it:** Phase 4 - CLI Continuity and Trust UX
**Confidence:** HIGH

### Pitfall 9: Promising perfect continuity when resume is only best-effort continuity
**What goes wrong:** Resume support is real, but human-visible transcript fidelity has had bugs and regressions in the official `openai/codex` project. If CodeRelay markets the flow as "exactly where you left off," users may discover that context resumed but visible tool history or audit evidence did not.
**Early warning signs:** Resumed sessions lack visible tool-call history; users re-approve work because they cannot see what already ran; behavior changes after a Codex CLI upgrade.
**Prevention strategy:** Message resume as best-effort continuity, not perfect replay. Maintain a CodeRelay-owned handoff record containing account, repo path, session ID, switch timestamp, and last known state so the user still has an audit trail even if Codex's rendered transcript is incomplete. Re-validate resume behavior against current Codex releases as part of compatibility testing.
**Phase should address it:** Phase 4 - CLI Continuity and Trust UX
**Confidence:** MEDIUM

### Pitfall 10: Leaking auth material or browser cookies through logs, backups, or support artifacts
**What goes wrong:** CodeRelay touches `auth.json`, browser cookies, dashboard sessions, and managed account homes. Any unredacted log line, backup export, crash report, or debug bundle can become a credential leak. This is not a generic desktop-app concern here; it is core product risk because the product exists to manage multiple live auth contexts.
**Early warning signs:** Debug logs contain cookie-header fragments, bearer tokens, or raw `auth.json`; support bundles need manual scrubbing; users hesitate to trust the app with account management.
**Prevention strategy:** Treat all auth/cache material as secrets. Redact before logging, never persist raw cookie headers, lock down file permissions for managed homes, and exclude secret-bearing files from diagnostics by default. If backups are necessary, encrypt them or store only reversible metadata, not raw tokens.
**Phase should address it:** Phase 1 - Account Security and Storage Foundations
**Confidence:** HIGH

## Moderate Pitfalls

### Pitfall 1: Deleting the previous managed home too early during reauthentication
**What goes wrong:** The reference service removes an old managed home after successful reauthentication. If CodeRelay expands that behavior without a quarantine period, one bad reauth or misidentified login can erase the last known-good account state before the user confirms the replacement is correct.
**Early warning signs:** Reauthenticate flows feel irreversible; a failed relogin forces the user to add the account from scratch again; "wrong account added over existing one" incidents appear.
**Prevention strategy:** Quarantine replaced homes until the new identity is verified and the switch is accepted. Delay destructive cleanup to a background maintenance pass with explicit safety checks.
**Phase should address it:** Phase 1 - Account Security and Storage Foundations
**Confidence:** HIGH

### Pitfall 2: Warning-threshold flapping near a limit boundary
**What goes wrong:** Sliding-window usage can move enough between refreshes to cross the warning threshold repeatedly. The result is alert spam or repeated prompts to switch accounts, which makes users ignore the warning system.
**Early warning signs:** Multiple warnings fire for the same account within minutes; the threshold toggles around a narrow band; users dismiss warnings as noise.
**Prevention strategy:** Add hysteresis, cooldowns, and per-window acknowledgement state. Warn once per window unless the account materially recovers or the user explicitly resets the warning state.
**Phase should address it:** Phase 2 - Usage Monitoring Engine
**Confidence:** MEDIUM

### Pitfall 3: Giving browser/dashboard data the same trust level as CLI-authenticated state
**What goes wrong:** Dashboard scraping is useful, but it depends on cookies, login state, browser access, and UI parsing. If CodeRelay treats it as equally authoritative with CLI-authenticated account identity, a brittle scrape can drive switching or warnings.
**Early warning signs:** A UI change on `chatgpt.com` suddenly breaks usage parsing; users see "login required" while CLI auth is healthy; the app flips sources without telling the user.
**Prevention strategy:** Rank sources explicitly. Use CLI-authenticated identity and rate-limit reads as the primary switching authority whenever possible, and treat browser-derived data as an augmenting or fallback signal. Always show which source produced the current usage card.
**Phase should address it:** Phase 2 - Usage Monitoring Engine
**Confidence:** HIGH

## Later Validation Track

### Pitfall: Making Codex App lifecycle automation a v1 dependency
**What goes wrong:** The roadmap gets blocked on macOS window/process automation and opaque Codex App behavior before the core CLI relay workflow is solid. That stretches the critical path and mixes two different kinds of risk: Codex account correctness and UI automation reliability.
**Early warning signs:** v1 planning depends on app-window inspection or accessibility automation; switch orchestration is designed around the Codex App instead of the CLI; resume requirements keep expanding without a working CLI baseline.
**Prevention strategy:** Ship v1 around Codex CLI switching, identity validation, warning-first UX, and CLI resume-by-session-ID. Put Codex App close/relaunch/resume into a later spike with explicit success criteria, compatibility testing, and a separate rollback story.
**Phase should address it:** Phase 5 - Codex App Lifecycle Validation
**Confidence:** HIGH

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|----------------|------------|
| Account model and storage | Email-only identity or hidden keychain usage makes accounts look isolated when they are not | Require explicit storage-mode detection and richer account identity metadata |
| Usage monitoring | Sliding-window percentages are presented as deterministic prompt counts | Use estimate language, timestamps, source labels, and threshold warnings instead of deterministic promises |
| Web dashboard integration | Wrong browser session is applied to the selected managed account | Verify signed-in email, isolate per-account web stores, and fail closed on mismatch |
| Switch orchestration | Old CLI session is closed before the new account is proven live | Use journaled switching with preflight verification and rollback |
| CLI continuity | `resume --last` restores the wrong session or an incomplete visible transcript | Capture explicit session IDs and maintain a CodeRelay-owned handoff record |
| Trust UX | Users cannot tell which account and source produced the current state | Show active account, auth mode, source, timestamp, and last switch outcome everywhere it matters |
| Post-v1 app automation | Roadmap stalls on brittle Codex App control | Keep app lifecycle work behind a later validation phase |

## Sources

- Local project context:
  - `CodeRelay/.planning/PROJECT.md`
  - `CodexBar/docs/codex.md`
  - `CodexBar/Sources/CodexBar/ManagedCodexAccountService.swift`
  - `CodexBar/Sources/CodexBar/CodexAccountReconciliation.swift`
  - `CodexBar/Sources/CodexBar/UsageStore+OpenAIWeb.swift`
  - `cc-switch/src-tauri/src/codex_config.rs`
  - `cc-switch/src-tauri/src/services/config.rs`
  - `cc-switch/src-tauri/src/services/provider/live.rs`
- Official OpenAI docs:
  - https://developers.openai.com/codex/auth
  - https://developers.openai.com/codex/cli/reference
  - https://help.openai.com/en/articles/11369540/
- Official OpenAI Codex repository references:
  - https://github.com/openai/codex/releases
  - https://github.com/openai/codex/issues/4790
