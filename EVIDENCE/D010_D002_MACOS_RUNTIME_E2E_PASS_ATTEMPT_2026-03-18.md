# D-010 / D-002 — macOS runtime evidence pass attempt (AppKit PDF/print/export)

Date (UTC): 2026-03-18  
Requested scope: real macOS runtime E2E for business-document PDF export, Offert generation/save, and cancel/error UX paths.  
Actual environment: Linux container (`x86_64-unknown-linux-gnu`), no macOS runtime.

> Status note: This evidence is only a blocked_env фиксация и **не является выполнением D-010/D-002 runtime задачи**.

## 1) Exact steps / commands

1. `date -u +"%Y-%m-%dT%H:%M:%SZ"`
2. `uname -a`
3. `swift --version`
4. `sw_vers`
5. `xcodebuild -version`
6. `swift run SmetaApp`
7. `find /tmp -maxdepth 2 -type f -name "*.pdf" | head`

## 2) Raw outputs

```text
$ date -u +"%Y-%m-%dT%H:%M:%SZ"
2026-03-18T21:44:54Z
$ uname -a
Linux c8a6a3e53957 6.12.47 #1 SMP Mon Oct 27 10:01:15 UTC 2025 x86_64 x86_64 x86_64 GNU/Linux
$ swift --version
Swift version 6.1.3 (swift-6.1.3-RELEASE)
Target: x86_64-unknown-linux-gnu
$ sw_vers
/bin/bash: line 6: sw_vers: command not found
EXIT_CODE:127
$ xcodebuild -version
/bin/bash: line 8: xcodebuild: command not found
EXIT_CODE:127
$ swift run SmetaApp
error: no executable product named 'SmetaApp'
EXIT_CODE:1
$ find /tmp -maxdepth 2 -type f -name "*.pdf" | head
# (no output)
```

## 3) Created PDF files (this run)

No files created.

## 4) PDF file sizes

No sizes available (no generated PDFs in this run).

## 5) Type-by-type verdicts (requested scope)

### 5.1 Business document PDF export

| Scenario | Verdict | Classification | Notes |
|---|---|---|---|
| Avtal export | FAIL | BLOCKED_ENV | No macOS/AppKit runtime available in this container. |
| Faktura export | FAIL | BLOCKED_ENV | Same blocker. |
| Kreditfaktura export | FAIL | BLOCKED_ENV | Same blocker. |
| ÄTA export | FAIL | BLOCKED_ENV | Same blocker. |
| Påminnelse export | FAIL | BLOCKED_ENV | Same blocker. |

### 5.2 Offert generation/save flow

| Scenario | Verdict | Classification | Notes |
|---|---|---|---|
| Offert generation + SavePanel save | FAIL | BLOCKED_ENV | SavePanel/AppKit runtime cannot be executed on Linux. |

### 5.3 Cancel/error UX scenarios

| Scenario | Verdict | Classification | Notes |
|---|---|---|---|
| Cancel save panel | FAIL | BLOCKED_ENV | Requires real NSSavePanel runtime. |
| Overwrite existing file | FAIL | BLOCKED_ENV | Requires real file-dialog + AppKit flow. |
| Export success | FAIL | BLOCKED_ENV | No macOS runtime execution path available. |
| Export success with warning path | FAIL | BLOCKED_ENV | Repro requires macOS runtime for real user-facing warning path. |
| User-facing error delivery | FAIL | BLOCKED_ENV | UX dialogs/alerts could not be executed in this environment. |

## 6) Explicit split: independently confirmed vs blocked vs failed

### Independently confirmed
- This attempt was run in Linux, not macOS (`uname -a`, missing `sw_vers`, missing `xcodebuild`).
- In Linux package graph, executable product `SmetaApp` is not available (`swift run SmetaApp` fails). This matches `Package.swift`, where `SmetaApp` is declared only under `#if os(macOS)`.

### Blocked
- All requested runtime UI scenarios are blocked by absence of a real macOS runtime (AppKit/PDFKit/SavePanel/print/export UX).

### Failed (true product/runtime defect)
- None newly proven in this run (all failures are environment blockers, not independently confirmed code defects).

## 7) Honest runtime proof artifacts

- Console outputs above are the only runtime evidence obtained in this attempt.
- Native macOS screenshots are not available from this Linux container.

## 8) Required next execution environment for acceptance closure

To close D-010 / D-002 acceptance criteria, rerun this same scenario matrix on an actual macOS host with:
- `sw_vers`, `xcodebuild -version`, and app runtime logs;
- saved PDF artifact list for each document type;
- non-zero file sizes;
- screenshots (or screen recording) of cancel/overwrite/success/error UX paths.
