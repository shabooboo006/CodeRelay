# Requirements: CodeRelay

**Defined:** 2026-04-01
**Core Value:** Keep a macOS developer continuously productive in Codex by making account exhaustion visible early and account switching fast, explicit, and low-friction.

## v1 Requirements

### Accounts

- [ ] **ACCT-01**: User can add a managed Codex account through a scoped login flow that stores it separately from other managed accounts.
- [ ] **ACCT-02**: User can view all managed Codex accounts with account email, last authentication time, and active/live status.
- [ ] **ACCT-03**: User can choose which managed Codex account CodeRelay should treat as the active account.
- [ ] **ACCT-04**: User can re-authenticate an existing managed Codex account without creating a duplicate account entry.
- [ ] **ACCT-05**: User can remove a managed Codex account that is no longer needed.
- [ ] **ACCT-06**: User can see when a managed Codex account cannot support reliable one-click switching because its credential storage mode is unsupported or unverified.

### Monitoring

- [x] **MON-01**: User can view the current 5-hour sliding-window usage for the active Codex account.
- [x] **MON-02**: User can view the current weekly usage for the active Codex account.
- [x] **MON-03**: User can view reset timing, last refresh time, and data-source status for the active Codex account.
- [x] **MON-04**: User can manually refresh account usage and see stale or error states instead of silent failure.
- [x] **MON-05**: User can inspect alternate managed accounts with latest known readiness state and remaining headroom or unknown status.

### Warnings

- [ ] **WARN-01**: User can configure a low-usage warning threshold as a percentage value.
- [ ] **WARN-02**: User receives a local warning when the active account crosses the configured threshold.
- [ ] **WARN-03**: Warning messaging identifies whether risk comes from the 5-hour window, weekly window, both, or stale data.
- [ ] **WARN-04**: Warning messaging suggests alternate managed accounts but does not switch automatically.

### Switching

- [ ] **SWCH-01**: User can confirm switching from the current account to a chosen managed Codex account from the warning flow or account-management UI.
- [ ] **SWCH-02**: CodeRelay performs account switching as a journaled transaction with backup and rollback if any step fails.
- [ ] **SWCH-03**: After a successful switch, CodeRelay refreshes account identity and usage so the target account is shown as active with verified state.
- [ ] **SWCH-04**: When the current Codex CLI session is CodeRelay-managed, CodeRelay can close and relaunch that CLI workflow under the target account.
- [ ] **SWCH-05**: When the current CLI session is not safely controllable, CodeRelay degrades to a guided relaunch path instead of killing arbitrary terminal processes.

### Continuity

- [ ] **CONT-01**: After CLI relaunch, CodeRelay can attempt `codex resume <session-id>` for the most recent tracked Codex CLI session when an explicit session ID is available.
- [ ] **CONT-02**: If automatic resume is unavailable or fails, user sees the working directory, session context, and fallback command needed to continue manually.
- [ ] **CONT-03**: CodeRelay records switch handoff metadata including account, timestamp, working directory, and resume candidate so recovery remains auditable.

### Interface

- [ ] **UI-01**: User can access active-account health, warnings, and switch actions from a lightweight macOS surface such as a menu bar entry.
- [ ] **UI-02**: User can open a detailed settings surface for managed accounts, thresholds, refresh state, and recent switch outcomes.

## v2 Requirements

### Codex App Validation

- **APP-01**: CodeRelay can detect and close a supported Codex App session before switching accounts.
- **APP-02**: CodeRelay can relaunch Codex App under the selected managed account after switching.
- **APP-03**: CodeRelay can restore the prior Codex App conversation after switching when technical validation proves the flow is reliable.

### Advanced Workflow

- **ADV-01**: User can view a cross-account exhaustion planner that recommends which account to use next.
- **ADV-02**: User can see pace forecasting for the active account instead of only raw usage percentages.
- **ADV-03**: User can repair detected config drift between CodeRelay state and the live Codex environment through a guided recovery flow.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Multi-provider switching | CodeRelay is intentionally Codex-only in v1 |
| Proxy, router, or vendor marketplace management | This is a different product category already covered by cc-switch |
| Unified MCP, prompts, skills, or generic config editing | Too broad for the core continuity workflow |
| Silent automatic account switching | Conflicts with the warning-first, user-confirmed product requirement |
| Full session browser or transcript manager | Not required to prove the switch-and-continue loop |
| Windows or Linux desktop support | v1 is a macOS-focused utility with native lifecycle behavior |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| ACCT-01 | Phase 1 | Pending |
| ACCT-02 | Phase 1 | Pending |
| ACCT-03 | Phase 1 | Pending |
| ACCT-04 | Phase 1 | Pending |
| ACCT-05 | Phase 1 | Pending |
| ACCT-06 | Phase 1 | Pending |
| MON-01 | Phase 2 | Complete |
| MON-02 | Phase 2 | Complete |
| MON-03 | Phase 2 | Complete |
| MON-04 | Phase 2 | Complete |
| MON-05 | Phase 2 | Complete |
| WARN-01 | Phase 3 | Pending |
| WARN-02 | Phase 3 | Pending |
| WARN-03 | Phase 3 | Pending |
| WARN-04 | Phase 3 | Pending |
| SWCH-01 | Phase 4 | Pending |
| SWCH-02 | Phase 4 | Pending |
| SWCH-03 | Phase 4 | Pending |
| SWCH-04 | Phase 5 | Pending |
| SWCH-05 | Phase 5 | Pending |
| CONT-01 | Phase 5 | Pending |
| CONT-02 | Phase 5 | Pending |
| CONT-03 | Phase 5 | Pending |
| UI-01 | Phase 5 | Pending |
| UI-02 | Phase 5 | Pending |

**Coverage:**
- v1 requirements: 25 total
- Mapped to phases: 25
- Unmapped: 0

---
*Requirements defined: 2026-04-01*
*Last updated: 2026-04-02 after Phase 02-03 execution*
