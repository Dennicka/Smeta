# D-014 ACCEPTANCE AUDIT EVIDENCE

Дата: 2026-03-18 (UTC)
Среда: Linux container (без macOS runtime)

## 1) Exact commands / raw outputs / exit codes

### Command 1
```bash
swiftc Sources/SmetaCore/Models/Entities.swift Sources/SmetaCore/Services/Stage5Service.swift Sources/SmetaCore/Services/ExportService.swift Scripts/stage6_core_verification.swift -o /tmp/stage6_core_verification && /tmp/stage6_core_verification; echo EXIT_CODE:$?
```
Raw output:
```text
<unknown>:0: error: error opening input file 'Sources/SmetaCore/Services/ExportService.swift' (No such file or directory)
EXIT_CODE:1
```

### Command 2
```bash
swiftc Sources/SmetaCore/Models/Entities.swift Sources/SmetaCore/Services/Stage5Service.swift Sources/SmetaCore/Services/DocumentExportPipeline.swift Scripts/stage6_core_verification.swift -o /tmp/stage6_core_verification && /tmp/stage6_core_verification; echo EXIT_CODE:$?
```
Raw output:
```text
Sources/SmetaCore/Services/DocumentExportPipeline.swift:26:34: error: cannot find type 'DocumentSnapshotBuilder' in scope
 24 |
 25 | final class DocumentExportPipeline {
 26 |     private let snapshotBuilder: DocumentSnapshotBuilder
    |                                  `- error: cannot find type 'DocumentSnapshotBuilder' in scope
 27 |
 28 |     init(snapshotBuilder: DocumentSnapshotBuilder = DocumentSnapshotBuilder()) {

Sources/SmetaCore/Services/DocumentExportPipeline.swift:28:27: error: cannot find type 'DocumentSnapshotBuilder' in scope
 26 |     private let snapshotBuilder: DocumentSnapshotBuilder
 27 |
 28 |     init(snapshotBuilder: DocumentSnapshotBuilder = DocumentSnapshotBuilder()) {
    |                           `- error: cannot find type 'DocumentSnapshotBuilder' in scope
 29 |         self.snapshotBuilder = snapshotBuilder
 30 |     }
EXIT_CODE:1
```

### Command 3
```bash
swiftc Sources/SmetaCore/Models/Entities.swift Sources/SmetaCore/Services/Stage5Service.swift Sources/SmetaCore/Services/DocumentSnapshotBuilder.swift Sources/SmetaCore/Services/DocumentExportPipeline.swift Scripts/stage6_core_verification.swift -o /tmp/stage6_core_verification && /tmp/stage6_core_verification; echo EXIT_CODE:$?
```
Raw output:
```text
PASS: CSV import validation catches missing name
PASS: CSV preview counts create operations
PASS: Receivables bucket 1–7 overdue
PASS: Receivables bucket 31+ overdue total
PASS: Manifest contains schemaVersion
PASS: Manifest contains export files
SUMMARY: PASS
EXIT_CODE:0
```

### Command 4
```bash
python3 - <<'PY'
from pathlib import Path
import re
text=Path('ACCEPTANCE_CHECKLIST.md').read_text()
counts={k:len(re.findall(rf'\|\s*{k}\s*\|',text)) for k in ['independently confirmed','repository-claimed','unconfirmed','blocked_env']}
print(counts)
PY
echo EXIT_CODE:$?
```
Raw output:
```text
{'independently confirmed': 4, 'repository-claimed': 42, 'unconfirmed': 0, 'blocked_env': 12}
EXIT_CODE:0
```

## 2) Correction table (D-014)

| item | previous status | corrected status | reason | evidence/source |
|---|---|---|---|---|
| #1 | PASS | repository-claimed | PASS был основан только на code audit. | ACCEPTANCE_CHECKLIST.md (D-014 version) |
| #2 | PASS | repository-claimed | PASS был основан только на code audit/claim. | ACCEPTANCE_CHECKLIST.md |
| #3 | PASS | repository-claimed | PASS был основан только на code audit/claim. | ACCEPTANCE_CHECKLIST.md |
| #4 | PASS | repository-claimed | PASS был основан только на code audit/claim. | ACCEPTANCE_CHECKLIST.md |
| #5 | PASS | repository-claimed | PASS был основан на code audit (`addRoom/duplicateRoom`). | ACCEPTANCE_CHECKLIST.md |
| #6 | PASS | repository-claimed | Формульный claim без независимого runtime acceptance. | ACCEPTANCE_CHECKLIST.md |
| #7 | PASS | repository-claimed | Поле/прокидка подтверждены кодом, не runtime acceptance. | ACCEPTANCE_CHECKLIST.md |
| #8 | PASS | repository-claimed | Нет отдельного runtime e2e evidence. | ACCEPTANCE_CHECKLIST.md |
| #9 | PASS | repository-claimed | Нет отдельного runtime e2e evidence. | ACCEPTANCE_CHECKLIST.md |
| #10 | PASS | repository-claimed | Нет отдельного runtime e2e evidence. | ACCEPTANCE_CHECKLIST.md |
| #11 | PASS | repository-claimed | Нет отдельного runtime e2e evidence. | ACCEPTANCE_CHECKLIST.md |
| #12 | PASS | repository-claimed | Расчётный claim без acceptance runtime прогона. | ACCEPTANCE_CHECKLIST.md |
| #13 | PASS | repository-claimed | Data-structure claim, не acceptance runtime. | ACCEPTANCE_CHECKLIST.md |
| #14 | PASS | repository-claimed | Нет отдельного runtime evidence user-flow. | ACCEPTANCE_CHECKLIST.md |
| #15 | PASS | repository-claimed | Есть repository-level evidence, но не acceptance runtime/macOS UI. | ACCEPTANCE_CHECKLIST.md + EVIDENCE/D009_REPOSITORY_FINALIZATION.md |
| #18 | PASS | repository-claimed | Draft/repository claim без полного acceptance runtime e2e. | ACCEPTANCE_CHECKLIST.md |
| #19 | PASS | repository-claimed | ROT logic claim без acceptance runtime e2e. | ACCEPTANCE_CHECKLIST.md |
| #20 | PASS | repository-claimed | customerType/taxMode claim без acceptance runtime e2e. | ACCEPTANCE_CHECKLIST.md |
| #21 | PASS | repository-claimed | Guard claim без acceptance runtime e2e. | ACCEPTANCE_CHECKLIST.md |
| #22 | PASS | repository-claimed | Есть generation runtime evidence, но не full acceptance/macOS runtime. | ACCEPTANCE_CHECKLIST.md + EVIDENCE/D008_GENERATION_CONTOUR.md |
| #23 | PASS | repository-claimed | Есть generation/runtime claim, но не full acceptance e2e. | ACCEPTANCE_CHECKLIST.md |
| #24 | PASS | repository-claimed | Path claim без полного acceptance runtime e2e. | ACCEPTANCE_CHECKLIST.md |
| #25 | PASS | repository-claimed | Service claim без acceptance runtime e2e. | ACCEPTANCE_CHECKLIST.md |
| #29 | PASS | repository-claimed | Guard/repository claim без независимого runtime acceptance. | ACCEPTANCE_CHECKLIST.md |
| #30 | PASS | repository-claimed | Balance path claim без независимого runtime acceptance. | ACCEPTANCE_CHECKLIST.md |
| #31 | PASS | independently confirmed | Подтверждено runtime script output (`Receivables bucket ...`). | Command 3 output |
| #32 | PASS | repository-claimed | Linkage claim без acceptance runtime e2e. | ACCEPTANCE_CHECKLIST.md |
| #33 | PASS | repository-claimed | Relation-fields claim без acceptance runtime e2e. | ACCEPTANCE_CHECKLIST.md |
| #34 | PASS | repository-claimed | Aggregations claim без acceptance runtime e2e. | ACCEPTANCE_CHECKLIST.md |
| #35 | PASS | repository-claimed | VAT fields/rules claim без acceptance runtime e2e. | ACCEPTANCE_CHECKLIST.md + EVIDENCE/D012_DEFECT_FIX_8B.md |
| #36 | PASS | repository-claimed | profitability service claim без acceptance runtime e2e. | ACCEPTANCE_CHECKLIST.md |
| #37 | PASS | independently confirmed | Подтверждено runtime script output (`Receivables bucket ...`). | Command 3 output |
| #40 | PASS | independently confirmed | Подтверждено runtime script output (`Manifest contains ...`). | Command 3 output |
| #41 | PASS | independently confirmed | Подтверждено runtime script output (`CSV import ...`). | Command 3 output |
| #42 | PASS | repository-claimed | Materials import pass был audit-only claim. | ACCEPTANCE_CHECKLIST.md |
| #43 | PASS | repository-claimed | Supplier import pass был audit-only claim. | ACCEPTANCE_CHECKLIST.md |
| #44 | PASS | repository-claimed | repricing pass был claim-only (без acceptance runtime e2e). | ACCEPTANCE_CHECKLIST.md |
| #45 | PASS | repository-claimed | purchase list pass был claim-only. | ACCEPTANCE_CHECKLIST.md |
| #46 | PASS | repository-claimed | archive/restore project claim без runtime acceptance e2e. | ACCEPTANCE_CHECKLIST.md |
| #47 | PASS | repository-claimed | search/filter claim основан на static audit. | ACCEPTANCE_CHECKLIST.md |
| #48 | PASS | repository-claimed | bulk export claim без acceptance runtime e2e. | ACCEPTANCE_CHECKLIST.md |
| #49 | PASS | repository-claimed | demo reset claim без runtime acceptance evidence. | ACCEPTANCE_CHECKLIST.md |
| #50 | PASS | repository-claimed | clean reset claim без runtime acceptance evidence. | ACCEPTANCE_CHECKLIST.md |
| #56 | PASS | repository-claimed | no-dead-buttons pass основан на static audit + code fix, не runtime UX e2e. | ACCEPTANCE_CHECKLIST.md |
| #57 | PASS | repository-claimed | no-empty-tabs pass основан на static audit. | ACCEPTANCE_CHECKLIST.md |
| #58 | PASS | repository-claimed | no-broken-links pass основан на repository linkage audit. | ACCEPTANCE_CHECKLIST.md |

## 3) Synced result (после D-014)

- independently confirmed: 4
- repository-claimed: 42
- unconfirmed: 0
- blocked_env: 12

Проверено Command 4 (выше).
