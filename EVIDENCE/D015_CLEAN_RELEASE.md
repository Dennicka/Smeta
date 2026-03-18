# EVIDENCE — D-015 Clean Release Pass (recursive denylist fix)

Дата: 2026-03-18 (UTC)  
Дефект: `D-015`  
Цель: подтвердить, что clean-release verify ловит noise в любом вложенном пути, а не только в корне.

## 1) Verify command (clean state)

```bash
Scripts/verify_clean_release_d015.sh; echo EXIT_CODE:$?
```

## 2) Raw output (clean state)

```text
D-015 clean-release verification
Repository root: /workspace/Smeta

Allowlist root entries (25):
 - ACCEPTANCE_CHECKLIST.md
 - ACCEPTANCE_RULES.md
 - ADMIN_GUIDE.md
 - AGENT_CONTEXT.md
 - BACKUP_RESTORE.md
 - CURRENT_STATE.md
 - DATA_PORTABILITY.md
 - DEFECT_BACKLOG.md
 - DEMO_RESET.md
 - DEMO_WALKTHROUGH.md
 - EVIDENCE
 - FINAL_VERIFICATION_REPORT.md
 - IMPORT_EXPORT.md
 - INSTALL.md
 - INTERNAL_REPORTS.md
 - KNOWN_LIMITATIONS.md
 - NEXT_TASK.md
 - Package.swift
 - PURCHASES.md
 - README.md
 - RELEASE_NOTES.md
 - Scripts
 - Sources
 - Tests
 - USER_GUIDE.md

Denylist directory segments (recursive, 9):
 - .build
 - build
 - Build
 - DerivedData
 - output
 - tmp
 - temp
 - cache
 - .cache

Denylist file patterns (recursive, 9):
 - *.log
 - *.tmp
 - *.temp
 - *.pid
 - *.sqlite-wal
 - *.sqlite-shm
 - *.db-wal
 - *.db-shm
 - .DS_Store

RESULT: PASS
Violations: 0
EXIT_CODE:0
```

## 3) Probe for nested-noise detection (FAIL expected)

```bash
mkdir -p Scripts/tmp && : > Scripts/tmp/d015_probe.tmp && Scripts/verify_clean_release_d015.sh; echo EXIT_CODE:$?; rm -rf Scripts/tmp
```

## 4) Raw output (nested-noise probe)

```text
D-015 clean-release verification
Repository root: /workspace/Smeta

Allowlist root entries (25):
 - ACCEPTANCE_CHECKLIST.md
 - ACCEPTANCE_RULES.md
 - ADMIN_GUIDE.md
 - AGENT_CONTEXT.md
 - BACKUP_RESTORE.md
 - CURRENT_STATE.md
 - DATA_PORTABILITY.md
 - DEFECT_BACKLOG.md
 - DEMO_RESET.md
 - DEMO_WALKTHROUGH.md
 - EVIDENCE
 - FINAL_VERIFICATION_REPORT.md
 - IMPORT_EXPORT.md
 - INSTALL.md
 - INTERNAL_REPORTS.md
 - KNOWN_LIMITATIONS.md
 - NEXT_TASK.md
 - Package.swift
 - PURCHASES.md
 - README.md
 - RELEASE_NOTES.md
 - Scripts
 - Sources
 - Tests
 - USER_GUIDE.md

Denylist directory segments (recursive, 9):
 - .build
 - build
 - Build
 - DerivedData
 - output
 - tmp
 - temp
 - cache
 - .cache

Denylist file patterns (recursive, 9):
 - *.log
 - *.tmp
 - *.temp
 - *.pid
 - *.sqlite-wal
 - *.sqlite-shm
 - *.db-wal
 - *.db-shm
 - .DS_Store

RESULT: FAIL
Violations (2):
 - DENYLIST_DIR: 'Scripts/tmp' contains forbidden segment 'tmp'
 - DENYLIST_DIR: 'Scripts/tmp/d015_probe.tmp' contains forbidden segment 'tmp'
EXIT_CODE:1
```

## 5) Exit codes

- Clean state: `0`
- Nested-noise probe: `1`

## 6) Verdict

- `PASS`: на чистом дереве verify проходит.
- `PASS`: verify честно обнаруживает вложенный release-noise в разрешённых root-директориях (`Scripts/...`) и переводит результат в `FAIL`.
- D-015 clean-release discipline теперь покрывает noise как в корне, так и на любой глубине репозитория.
