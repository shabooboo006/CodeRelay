# Research Summary

**Project:** CodeRelay  
**Synthesized:** 2026-04-01

## Executive Summary

CodeRelay should be built as a **native macOS Swift app**, not as a Tauri-style cross-platform shell. The strongest combination is:

- **CodexBar** as the product and architectural reference for native macOS UX, managed Codex account modeling, `CODEX_HOME` scoping, and Codex usage probing.
- **cc-switch** as the implementation reference for transactional Codex config switching, backup, and rollback behavior.

The roadmap should be **CLI-first**:

- v1 focuses on managed Codex accounts, account-scoped usage monitoring, low-usage warnings, confirmed one-click switching, CodeRelay-managed Codex CLI restart, and best-effort CLI resume.
- **Codex App close/relaunch/resume is deferred** to a later technical-validation phase and should not block current scope.

## Key Decisions

| Decision | Outcome |
|----------|---------|
| App foundation | Native macOS app with SwiftUI + AppKit shell |
| Product scope | Codex-only; remove multi-provider abstractions |
| Persistence | File-backed JSON/JSONL plus per-account managed `CODEX_HOME` directories |
| Monitoring | Prefer Codex CLI RPC/app-server probing, keep PTY `/status` as fallback |
| Switching | Explicit, journaled, rollback-safe switch flow |
| Continuity | Best-effort CLI resume by captured session ID; do not make resume part of switch correctness |
| Codex App support | Later validation track, not a v1 dependency |

## Recommended V1

### Table Stakes

- Managed Codex account roster with add, inspect, re-authenticate, remove, and choose-active flows
- Trustworthy active-account usage card with 5-hour window, weekly window, reset timing, freshness, and source labeling
- Candidate-account readiness view so users can see which alternate account is actually usable
- Configurable low-usage warning threshold with warning-first behavior
- Confirmed one-click switch with backup/rollback semantics
- CodeRelay-managed Codex CLI restart after switching
- Best-effort CLI conversation continuity using captured session IDs where possible
- Lightweight macOS access surface such as a menu bar entry point

### Explicit Non-Goals For V1

- Multi-provider switching
- Proxy/router/vendor marketplace features
- Unified MCP/prompts/skills/config management
- Full session browser or transcript manager
- Silent auto-switching
- Codex App automation as a release blocker

## Architecture Direction

Recommended module split:

- `CodeRelayApp`: app shell, menu bar, settings, notifications
- `CodeRelayCore`: account models, thresholds, persistence contracts, switch audit models
- `CodeRelayCodex`: scoped `CODEX_HOME`, login, usage probes, session discovery
- `CodeRelaySwitching`: switch orchestration, journal, rollback, restart, verification
- `CodeRelayLauncher`: helper surface for relaunching Codex CLI and resume commands

Recommended build order:

1. Account foundation and managed-home storage
2. Usage monitoring and warning engine
3. CLI session catalog and process registry
4. CLI switch transaction with rollback
5. CLI resume and trust UX
6. Codex App lifecycle validation

## Major Risks

| Risk | Planning Implication |
|------|----------------------|
| Usage is an estimate, not a fixed prompt counter | Warnings should be threshold-based and source-labeled, not deterministic |
| Credential storage mode may not be file-backed | Account isolation and one-click switching need explicit preflight validation |
| Email alone may not uniquely identify an account/workspace | Store richer account identity metadata where available |
| Async refresh tasks can overwrite newly selected account state | All probes need account-scoped guards and switch tokens |
| Killing unmanaged terminal processes is unsafe | V1 should only guarantee restart for CodeRelay-managed CLI sessions |
| `codex resume --last` can restore the wrong thread | Capture explicit session IDs and use `resume <session-id>` whenever possible |
| Resume fidelity can drift between Codex releases | Present continuity as best-effort, keep a CodeRelay-owned handoff record |

## Downstream Guidance

Use these defaults when writing requirements and roadmap:

- Treat **Codex CLI** as the primary runtime target.
- Treat **Codex App automation** as a follow-on phase with explicit validation goals.
- Keep requirements **narrow, user-visible, and testable**.
- Preserve a future seam for `CodexAppAdapter` or live-home projection, but do not build around it yet.
- Prefer **deletion and simplification** over importing whole CodexBar or cc-switch subsystems.

## Source Files

- `.planning/research/STACK.md`
- `.planning/research/FEATURES.md`
- `.planning/research/ARCHITECTURE.md`
- `.planning/research/PITFALLS.md`
