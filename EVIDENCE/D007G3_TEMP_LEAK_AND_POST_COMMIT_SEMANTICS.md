# D-007g3 — temp-leak + post-commit warning semantics (honest verifier alignment)

Дата: 2026-03-18 (UTC)
Среда: Linux container (без macOS AppKit runtime)

## 1) Exact commands / raw outputs / exit codes

### Command 1 — scenario-based semantics verifier
```bash
swiftc Sources/SmetaApp/Services/PDFFileStateOrchestrator.swift Scripts/verify_d007g3_semantics.swift -o /tmp/verify_d007g3 && /tmp/verify_d007g3
```
Exit code: `0`
Raw output:
```text
D007G3_RESULTS
C1 PASS
C2 PASS
C3 PASS
C4 PASS
TOTAL=4
```

### Command 2 — regression check
```bash
swift test
```
Exit code: `0`
Raw output (tail):
```text
Test Suite 'All tests' passed at 2026-03-18 21:36:38.155
    Executed 16 tests, with 0 failures (0 unexpected) in 0.046 (0.046) seconds
```

## 2) Covered scenarios (required)

| Case | What is validated | Result |
|---|---|---|
| C1 | Temp artifact **already created** (`tempURL` write done), then pre-BEGIN failure occurs; cleanup removes temp artifact (no g3 temp leak). | PASS |
| C2 | BEGIN transaction fails after temp generation; cleanup still removes temp artifact. | PASS |
| C3 | Commit succeeds but refresh fails; operation remains success and returns warning (no synthetic failure). | PASS |
| C4 | Commit succeeds but backup cleanup path warns; operation remains success + warning (post-commit warning semantics). | PASS |

## 3) What verifier now models (and what it does not)

- `Scripts/verify_d007g3_semantics.swift` deliberately models orchestrator-centered flow:
  - prepare temp;
  - transactional promote + commit;
  - post-commit cleanup/refresh warnings as **non-fatal** path.
- C1 specifically fails **after temp creation** (`tempPreparedFail`) to validate real cleanup semantics instead of a pre-temp synthetic case.
- C4 now checks **warning semantics** (success + warning) instead of old throw/catch fail shape.

Not covered by this Linux runtime verifier:
- реальный AppKit UX path (`NSSavePanel`, визуальное сообщение в macOS UI).

## 4) Runtime vs code-path vs blocked_env

- **Runtime confirmed (Linux):** `verify_d007g3_semantics.swift` (C1..C4) + `swift test`.
- **Code-path alignment target:** `AppViewModel` orchestrator-based post-commit warning branches (`cleanupBackupAfterCommit`, `reloadAll`) without success-path conversion to fatal error.
- **Blocked_env:** macOS AppKit runtime verification.

## Verdict

- D-007g3 verifier semantics aligned with production intent: **да**.
- D-007 общий статус: **PARTIAL** до macOS runtime UX verification.
