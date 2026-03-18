# D-007e — orphan-file / half-success semantics после PDF write + persistence/logging failure

Дата: 2026-03-18 (UTC)
Среда: Linux container (без macOS AppKit runtime)

## Update note (D-007g2 sync)
- После D-007g2 orchestration перенесён в `PDFFileStateOrchestrator`; актуальный throwing recovery/cleanup и integration path подтверждаются в `EVIDENCE/D007G2_HARD_RECOVERY_SEMANTICS.md`.
- Этот файл сохраняется как исторический evidence для шага D-007e (введение temp+transaction+cleanup), но текущая canonical implementation для recovery semantics — orchestrator-based.

## Цель
Убрать неатомарную семантику в потоках, где PDF мог уже быть записан, а DB/logging шаги падали, оставляя orphan artifact на диске.

Покрытие:
- `saveEstimateAndGenerateDocument()`
- `exportDocumentPDF(_:)`

## 1) Exact commands / raw outputs / exit codes

### Command 1 — code-path proof для Offert flow
```bash
nl -ba Sources/SmetaApp/ViewModels/AppViewModel.swift | sed -n '201,320p'
```
Exit code: `0`
Raw output (ключевое):
```text
236            let tempURL = temporaryPDFURL(prefix: "offert")
239            try pdfService.generateOffertSwedish(..., saveURL: tempURL)
241            try repository.db.execute("BEGIN IMMEDIATE TRANSACTION")
...
259            try repository.insertGeneratedDocument(... path: finalURL.path ...)
260            try replacePDFAtomically(from: tempURL, to: finalURL)
262            try repository.db.execute("COMMIT")
...
244                try? repository.db.execute("ROLLBACK")
247                    try? FileManager.default.removeItem(at: finalURL)
```

### Command 2 — code-path proof для business export PDF flow
```bash
nl -ba Sources/SmetaApp/ViewModels/AppViewModel.swift | sed -n '527,620p'
```
Exit code: `0`
Raw output (ключевое):
```text
554            let tempURL = temporaryPDFURL(prefix: "business-document")
557            try pdfService.generateBusinessDocumentPDF(..., saveURL: tempURL)
559            try repository.db.execute("BEGIN IMMEDIATE TRANSACTION")
569            try repository.logExport(... path: finalURL.path)
570            try replacePDFAtomically(from: tempURL, to: finalURL)
572            try repository.db.execute("COMMIT")
...
563                try? repository.db.execute("ROLLBACK")
565                    try? FileManager.default.removeItem(at: finalURL)
```

### Command 3 — Linux regression check
```bash
swift test
```
Exit code: `0`
Raw output (tail):
```text
Test Suite 'All tests' passed at 2026-03-18 20:23:34.770
    Executed 16 tests, with 0 failures (0 unexpected) in 0.664 (0.664) seconds
```

### Command 4 — graph scope proof (честное ограничение)
```bash
sed -n '1,90p' Package.swift
```
Exit code: `0`
Raw output (ключевое):
```text
var products: [Product] = [
    .library(name: "SmetaCore", targets: ["SmetaCore"])
]
...
#if os(macOS)
products.insert(.executable(name: "SmetaApp", targets: ["SmetaApp"]), at: 0)
...
#endif
```

## 2) Что исправлено

### A) saveEstimateAndGenerateDocument()
- Было: PDF писался в финальный путь до DB persistence; при падении DB пользователь получал ошибку, но файл уже лежал на диске (half-success/orphan).
- Стало:
  1. PDF генерируется во временный файл;
  2. persistence выполняется в `BEGIN IMMEDIATE TRANSACTION`;
  3. затем `replacePDFAtomically(temp -> final)`;
  4. затем `COMMIT`.
- При ошибке до `COMMIT`: `ROLLBACK`, cleanup временного файла, а если final уже успел появиться в рамках этого flow — он удаляется.

### B) exportDocumentPDF(_:) 
- Было: PDF в финальном пути + потом `logExport`; падение `logExport` оставляло файл без согласованного metadata/log состояния.
- Стало:
  1. PDF сначала генерируется во временный файл;
  2. `logExport` + move в финальный путь выполняются внутри DB transaction;
  3. `COMMIT` только после успешного move.
- При ошибке до `COMMIT`: `ROLLBACK` и cleanup final файла (если уже был перемещён).

## 3) Инварианты D-007e

- Для проверенных flow убрана half-success семантика вида «ошибка есть, а orphan PDF уже лежит» при persistence/logging fail.
- Контракт выполнения:
  - либо `COMMIT` + финальный PDF + согласованная DB/log запись;
  - либо `ROLLBACK` + cleanup временных/финальных артефактов, созданных этим flow.

## 4) Честная классификация подтверждений

- **Runtime подтверждено в текущей среде (Linux):**
  - `swift test` (Linux graph) проходит.
- **Подтверждено code-path review:**
  - транзакционный порядок и cleanup-ветки в `AppViewModel` для двух целевых flow.
- **Blocked_env:**
  - реальный AppKit UI runtime (NSSavePanel interactions) и визуальная UX-валидация в macOS.

## 5) Verdict

- D-007e code-level fix: **выполнен**.
- D-007 общий статус остаётся **PARTIAL** до macOS runtime UX verification.
